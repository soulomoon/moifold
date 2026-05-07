{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Workflow.Execution
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , ActionOutcome (..)
  , AppServerInterpreter (..)
  , CompiledEffectPlan (..)
  , EffectCommitOrder (..)
  , EffectIdempotency (..)
  , EffectRuntimeConfig (..)
  , PlannedAction (..)
  , TurnRuntimeConfig (..)
  , WorkflowActionFailure (..)
  , WorkflowCapability (..)
  , WorkflowCompiledEffectPlan (..)
  , WorkflowCompiledEffectPlanOf (..)
  , WorkflowEffectMetadata (..)
  , WorkflowPlannedAction (..)
  , WorkflowPlannedActionOf (..)
  , actionRunsBeforeEventCommit
  , compileWorkflowEffect
  , compileWorkflowEffectWithMetadata
  , compileWorkflowEffectPlan
  , compileWorkflowEffectPlanWithMetadata
  , compileWorkflowGenericEffectPlan
  , dryRunWorkflowGenericCompiledEffectPlan
  , dryRunWorkflowEffectPlan
  , dryRunWorkflowCompiledEffectPlan
  , effectRunsBeforeEventCommit
  , executeWorkflowCheckedActions
  , executeWorkflowCompiledEffectPlan
  , executeWorkflowEffectPlan
  , executeWorkflowGenericActions
  , executeWorkflowGenericCompiledEffectPlan
  , partitionWorkflowEffectPlan
  , partitionWorkflowActionReports
  , partitionWorkflowActions
  , partitionWorkflowGenericActionReports
  , partitionWorkflowGenericActions
  , workflowActionFailureReports
  , workflowCompiledEffectPlanLegacy
  , workflowEffectMetadata
  ) where

import CodexWatcher.ActionExecutor
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , ActionOutcome (..)
  , AppServerInterpreter (..)
  , HardFailure (..)
  , dryRunCompiledEffectPlan
  , executeCompiledEffectPlan
  , executePlannedAction
  )
import CodexWatcher.EffectInterpreter
  ( CompiledEffectPlan (..)
  , EffectRuntimeConfig (..)
  , PlannedAction (..)
  , TurnRuntimeConfig (..)
  , compileEffect
  , compileEffectPlan
  )
import CodexWatcher.Core.Ids (RequestId)
import CodexWatcher.Effects (Effect (..), EffectPlan, SomeEffect (..))
import CodexWatcher.Failure (FailureClassification, classifyExternalFailureText)
import CodexWatcher.Runtime.Command.Types (CommandReport)
import CodexWatcher.Workflow.Execution.Core
  ( EffectCommitOrder (..)
  , EffectIdempotency (..)
  , WorkflowCapability (..)
  , WorkflowCheckedActionFailureOf (..)
  , WorkflowCompiledEffectPlanOf (..)
  , WorkflowEffectMetadata (..)
  , WorkflowPlannedActionOf (..)
  , compileWorkflowGenericEffectPlan
  , dryRunWorkflowGenericCompiledEffectPlan
  , executeWorkflowCheckedActionsOf
  , executeWorkflowGenericActions
  , executeWorkflowGenericCompiledEffectPlan
  , partitionWorkflowGenericActionReports
  , partitionWorkflowGenericActions
  , workflowCheckedActionFailureReports
  )
import Data.List (mapAccumL, partition)

data WorkflowPlannedAction = WorkflowPlannedAction
  { workflowPlannedEffect :: SomeEffect
  , workflowPlannedAction :: PlannedAction
  , workflowPlannedMetadata :: WorkflowEffectMetadata
  }
  deriving stock (Eq, Show)

data WorkflowCompiledEffectPlan = WorkflowCompiledEffectPlan
  { workflowCompiledActions :: [WorkflowPlannedAction]
  , workflowCompiledNextRequestId :: RequestId
  }
  deriving stock (Eq, Show)

data WorkflowActionFailure = WorkflowActionFailure
  { workflowFailedAction :: WorkflowPlannedAction
  , workflowFailedReport :: ActionExecutionReport
  , workflowFailurePriorReports :: [ActionExecutionReport]
  , workflowFailureClassification :: FailureClassification
  , workflowFailureCommandReport :: Maybe CommandReport
  }
  deriving stock (Eq, Show)

data WorkflowActionFailureReason = WorkflowActionFailureReason
  { workflowActionFailureReasonClassification :: FailureClassification
  , workflowActionFailureReasonCommandReport :: Maybe CommandReport
  }
  deriving stock (Eq, Show)

workflowEffectMetadata :: SomeEffect -> WorkflowEffectMetadata
workflowEffectMetadata (SomeEffect effect) =
  case effect of
    ReadOpenIssues {} -> preCommit ReadWorld Idempotent
    ReadOpenPullRequests {} -> preCommit ReadWorld Idempotent
    ReadReviewThreads {} -> preCommit ReadWorld Idempotent
    StartPlannerTurn {} -> preCommit StartAgent AtMostOnce
    StartWorkerTurn {} -> preCommit StartAgent AtMostOnce
    StartIssuePlanWorkerTurn {} -> preCommit StartAgent AtMostOnce
    StartIssueImplementationWorkerTurn {} -> preCommit StartAgent AtMostOnce
    StartReviewerTurn {} -> preCommit StartAgent AtMostOnce
    StartReviewerVerificationTurn {} -> preCommit StartAgent AtMostOnce
    StartIssueFinalReviewTurn {} -> preCommit StartAgent AtMostOnce
    PushBranch {} -> preCommit MutateRemote CheckThenAct
    CreateIssue {} -> preCommit MutateRemote AtMostOnce
    CreatePullRequest {} -> preCommit MutateRemote AtMostOnce
    UpdatePullRequestBody {} -> preCommit MutateRemote CheckThenAct
    UpdateIssueFollowUp {} -> preCommit MutateRemote AtMostOnce
    CloseIssue {} -> preCommit MutateRemote CheckThenAct
    ResolveReviewThread {} -> preCommit MutateRemote CheckThenAct
    ReplyReviewThread {} -> preCommit MutateRemote AtMostOnce
    PublishReviewFindings {} -> preCommit MutateRemote AtMostOnce
    RecordIssuePlan {} -> preCommit WriteLocal DerivedWrite
    RecordPlanningGraph {} -> postCommit WriteLocal DerivedWrite
    RecordBlocked {} -> postCommit WriteLocal DerivedWrite
    MergePullRequest {} -> preCommit Merge CheckThenAct
    StopDaemon -> postCommit Stop Idempotent
    SleepUntilNextPoll -> postCommit Sleep Idempotent
 where
  preCommit capability idempotency =
    WorkflowEffectMetadata
      { workflowEffectCapability = capability
      , workflowEffectCommitOrder = PreCommit
      , workflowEffectIdempotency = idempotency
      }
  postCommit capability idempotency =
    WorkflowEffectMetadata
      { workflowEffectCapability = capability
      , workflowEffectCommitOrder = PostCommit
      , workflowEffectIdempotency = idempotency
      }

compileWorkflowEffectPlan :: EffectRuntimeConfig -> EffectPlan -> CompiledEffectPlan
compileWorkflowEffectPlan =
  compileEffectPlan

compileWorkflowEffectPlanWithMetadata :: EffectRuntimeConfig -> EffectPlan -> WorkflowCompiledEffectPlan
compileWorkflowEffectPlanWithMetadata config effects =
  let (finalRequestId, actionBatches) =
        mapAccumL
          ( \requestId effect ->
              let (actions, requestId') = compileWorkflowEffectWithMetadata config requestId effect
               in (requestId', actions)
          )
          config.effectRuntimeNextRequestId
          effects
   in WorkflowCompiledEffectPlan
        { workflowCompiledActions = concat actionBatches
        , workflowCompiledNextRequestId = finalRequestId
        }

compileWorkflowEffect :: EffectRuntimeConfig -> RequestId -> SomeEffect -> ([PlannedAction], RequestId)
compileWorkflowEffect =
  compileEffect

compileWorkflowEffectWithMetadata :: EffectRuntimeConfig -> RequestId -> SomeEffect -> ([WorkflowPlannedAction], RequestId)
compileWorkflowEffectWithMetadata config requestId effect =
  let (actions, requestId') = compileWorkflowEffect config requestId effect
      metadata = workflowEffectMetadata effect
   in ( fmap
          ( \action ->
              WorkflowPlannedAction
                { workflowPlannedEffect = effect
                , workflowPlannedAction = action
                , workflowPlannedMetadata = metadata
                }
          )
          actions
      , requestId'
      )

workflowCompiledEffectPlanLegacy :: WorkflowCompiledEffectPlan -> CompiledEffectPlan
workflowCompiledEffectPlanLegacy plan =
  CompiledEffectPlan
    { compiledActions = fmap workflowPlannedAction plan.workflowCompiledActions
    , compiledNextRequestId = plan.workflowCompiledNextRequestId
    }

dryRunWorkflowEffectPlan :: EffectRuntimeConfig -> EffectPlan -> [ActionExecutionReport]
dryRunWorkflowEffectPlan config =
  dryRunWorkflowCompiledEffectPlan . compileWorkflowEffectPlanWithMetadata config

dryRunWorkflowCompiledEffectPlan :: WorkflowCompiledEffectPlan -> [ActionExecutionReport]
dryRunWorkflowCompiledEffectPlan =
  dryRunCompiledEffectPlan . workflowCompiledEffectPlanLegacy

executeWorkflowCompiledEffectPlan
  :: Monad m
  => ActionExecutor m
  -> ActionExecutionMode
  -> WorkflowCompiledEffectPlan
  -> m [ActionExecutionReport]
executeWorkflowCompiledEffectPlan executor mode =
  executeCompiledEffectPlan executor mode . workflowCompiledEffectPlanLegacy

executeWorkflowEffectPlan
  :: Monad m
  => ActionExecutor m
  -> ActionExecutionMode
  -> EffectRuntimeConfig
  -> EffectPlan
  -> m [ActionExecutionReport]
executeWorkflowEffectPlan executor mode config =
  executeWorkflowCompiledEffectPlan executor mode . compileWorkflowEffectPlanWithMetadata config

partitionWorkflowActions :: WorkflowCompiledEffectPlan -> ([WorkflowPlannedAction], [WorkflowPlannedAction])
partitionWorkflowActions =
  partition actionRunsBeforeEventCommit . workflowCompiledActions

partitionWorkflowActionReports :: WorkflowCompiledEffectPlan -> [ActionExecutionReport] -> ([ActionExecutionReport], [ActionExecutionReport])
partitionWorkflowActionReports plan reports =
  let actionReports = zip plan.workflowCompiledActions reports
      (preCommitReports, postCommitReports) = partition (actionRunsBeforeEventCommit . fst) actionReports
   in (fmap snd preCommitReports, fmap snd postCommitReports)

partitionWorkflowEffectPlan :: EffectPlan -> (EffectPlan, EffectPlan)
partitionWorkflowEffectPlan =
  partition effectRunsBeforeEventCommit

effectRunsBeforeEventCommit :: SomeEffect -> Bool
effectRunsBeforeEventCommit effect =
  (workflowEffectMetadata effect).workflowEffectCommitOrder == PreCommit

actionRunsBeforeEventCommit :: WorkflowPlannedAction -> Bool
actionRunsBeforeEventCommit action =
  action.workflowPlannedMetadata.workflowEffectCommitOrder == PreCommit

executeWorkflowCheckedActions :: Monad m => ActionExecutor m -> [WorkflowPlannedAction] -> m (Either WorkflowActionFailure [ActionExecutionReport])
executeWorkflowCheckedActions executor =
  fmap (either (Left . workflowActionFailureFromCheckedFailure) Right)
    . executeWorkflowCheckedActionsOf
      (executePlannedAction executor ExecuteActions . workflowPlannedAction)
      workflowActionFailureReason
 where
  workflowActionFailureFromCheckedFailure
    :: WorkflowCheckedActionFailureOf WorkflowPlannedAction ActionExecutionReport WorkflowActionFailureReason
    -> WorkflowActionFailure
  workflowActionFailureFromCheckedFailure failure =
    let reason = failure.workflowCheckedActionFailureReason
     in WorkflowActionFailure
          { workflowFailedAction = failure.workflowCheckedActionFailedAction
          , workflowFailedReport = failure.workflowCheckedActionFailedReport
          , workflowFailurePriorReports = failure.workflowCheckedActionFailurePriorReports
          , workflowFailureClassification = reason.workflowActionFailureReasonClassification
          , workflowFailureCommandReport = reason.workflowActionFailureReasonCommandReport
          }

workflowActionFailureReason :: WorkflowPlannedAction -> ActionExecutionReport -> Maybe WorkflowActionFailureReason
workflowActionFailureReason _action report =
  case report.actionExecutionOutcome of
    ActionHardFailed hardFailure ->
      Just
        WorkflowActionFailureReason
          { workflowActionFailureReasonClassification = hardFailureClassification hardFailure
          , workflowActionFailureReasonCommandReport = commandReportFromExecution report
          }
    _ ->
      Nothing

hardFailureClassification :: HardFailure -> FailureClassification
hardFailureClassification = \case
  CommandHardFailed reason -> classifyExternalFailureText reason

workflowActionFailureReports :: WorkflowActionFailure -> [ActionExecutionReport]
workflowActionFailureReports failure =
  workflowCheckedActionFailureReports
    WorkflowCheckedActionFailureOf
      { workflowCheckedActionFailedAction = failure.workflowFailedAction
      , workflowCheckedActionFailedReport = failure.workflowFailedReport
      , workflowCheckedActionFailurePriorReports = failure.workflowFailurePriorReports
      , workflowCheckedActionFailureReason = ()
      }

commandReportFromExecution :: ActionExecutionReport -> Maybe CommandReport
commandReportFromExecution report =
  case report.actionExecutionResult of
    CommandActionResult commandReport -> Just commandReport
    _ -> Nothing
