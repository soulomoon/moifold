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
import Data.List (mapAccumL, partition)

data EffectCommitOrder
  = PreCommit
  | PostCommit
  deriving stock (Eq, Show)

data EffectIdempotency
  = Idempotent
  | CheckThenAct
  | AtMostOnce
  | DerivedWrite
  deriving stock (Eq, Show)

data WorkflowEffectMetadata = WorkflowEffectMetadata
  { workflowEffectCommitOrder :: EffectCommitOrder
  , workflowEffectIdempotency :: EffectIdempotency
  }
  deriving stock (Eq, Show)

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

data WorkflowPlannedActionOf effect action = WorkflowPlannedActionOf
  { workflowGenericPlannedEffect :: effect
  , workflowGenericPlannedAction :: action
  , workflowGenericPlannedMetadata :: WorkflowEffectMetadata
  }
  deriving stock (Eq, Show)

data WorkflowCompiledEffectPlanOf effect action = WorkflowCompiledEffectPlanOf
  { workflowGenericCompiledActions :: [WorkflowPlannedActionOf effect action]
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

workflowEffectMetadata :: SomeEffect -> WorkflowEffectMetadata
workflowEffectMetadata (SomeEffect effect) =
  case effect of
    ReadOpenIssues {} -> preCommit Idempotent
    ReadOpenPullRequests {} -> preCommit Idempotent
    ReadReviewThreads {} -> preCommit Idempotent
    StartPlannerTurn {} -> preCommit AtMostOnce
    StartWorkerTurn {} -> preCommit AtMostOnce
    StartIssuePlanWorkerTurn {} -> preCommit AtMostOnce
    StartIssueImplementationWorkerTurn {} -> preCommit AtMostOnce
    StartReviewerTurn {} -> preCommit AtMostOnce
    StartReviewerVerificationTurn {} -> preCommit AtMostOnce
    StartIssueFinalReviewTurn {} -> preCommit AtMostOnce
    PushBranch {} -> preCommit CheckThenAct
    CreateIssue {} -> preCommit AtMostOnce
    CreatePullRequest {} -> preCommit AtMostOnce
    UpdatePullRequestBody {} -> preCommit CheckThenAct
    UpdateIssueFollowUp {} -> preCommit AtMostOnce
    CloseIssue {} -> preCommit CheckThenAct
    ResolveReviewThread {} -> preCommit CheckThenAct
    ReplyReviewThread {} -> preCommit AtMostOnce
    PublishReviewFindings {} -> preCommit AtMostOnce
    RecordIssuePlan {} -> preCommit DerivedWrite
    RecordPlanningGraph {} -> postCommit DerivedWrite
    RecordBlocked {} -> postCommit DerivedWrite
    MergePullRequest {} -> preCommit CheckThenAct
    StopDaemon -> postCommit Idempotent
    SleepUntilNextPoll -> postCommit Idempotent
 where
  preCommit idempotency =
    WorkflowEffectMetadata
      { workflowEffectCommitOrder = PreCommit
      , workflowEffectIdempotency = idempotency
      }
  postCommit idempotency =
    WorkflowEffectMetadata
      { workflowEffectCommitOrder = PostCommit
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

compileWorkflowGenericEffectPlan
  :: (effect -> WorkflowEffectMetadata)
  -> (effect -> [action])
  -> [effect]
  -> WorkflowCompiledEffectPlanOf effect action
compileWorkflowGenericEffectPlan metadataFor compileEffectActions effects =
  WorkflowCompiledEffectPlanOf
    { workflowGenericCompiledActions =
        concatMap
          ( \effect ->
              let metadata = metadataFor effect
               in fmap
                    ( \action ->
                        WorkflowPlannedActionOf
                          { workflowGenericPlannedEffect = effect
                          , workflowGenericPlannedAction = action
                          , workflowGenericPlannedMetadata = metadata
                          }
                    )
                    (compileEffectActions effect)
          )
          effects
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

dryRunWorkflowGenericCompiledEffectPlan
  :: (action -> report)
  -> WorkflowCompiledEffectPlanOf effect action
  -> [report]
dryRunWorkflowGenericCompiledEffectPlan dryRunAction =
  fmap (dryRunAction . workflowGenericPlannedAction) . workflowGenericCompiledActions

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

executeWorkflowGenericCompiledEffectPlan
  :: Monad m
  => (ActionExecutionMode -> action -> m report)
  -> ActionExecutionMode
  -> WorkflowCompiledEffectPlanOf effect action
  -> m [report]
executeWorkflowGenericCompiledEffectPlan executeAction mode =
  executeWorkflowGenericActions executeAction mode . workflowGenericCompiledActions

executeWorkflowGenericActions
  :: Monad m
  => (ActionExecutionMode -> action -> m report)
  -> ActionExecutionMode
  -> [WorkflowPlannedActionOf effect action]
  -> m [report]
executeWorkflowGenericActions executeAction mode =
  traverse (executeAction mode . workflowGenericPlannedAction)

partitionWorkflowActions :: WorkflowCompiledEffectPlan -> ([WorkflowPlannedAction], [WorkflowPlannedAction])
partitionWorkflowActions =
  partition actionRunsBeforeEventCommit . workflowCompiledActions

partitionWorkflowGenericActions
  :: WorkflowCompiledEffectPlanOf effect action
  -> ([WorkflowPlannedActionOf effect action], [WorkflowPlannedActionOf effect action])
partitionWorkflowGenericActions =
  partition genericActionRunsBeforeEventCommit . workflowGenericCompiledActions

partitionWorkflowActionReports :: WorkflowCompiledEffectPlan -> [ActionExecutionReport] -> ([ActionExecutionReport], [ActionExecutionReport])
partitionWorkflowActionReports plan reports =
  let actionReports = zip plan.workflowCompiledActions reports
      (preCommitReports, postCommitReports) = partition (actionRunsBeforeEventCommit . fst) actionReports
   in (fmap snd preCommitReports, fmap snd postCommitReports)

partitionWorkflowGenericActionReports
  :: WorkflowCompiledEffectPlanOf effect action
  -> [report]
  -> ([report], [report])
partitionWorkflowGenericActionReports plan reports =
  let actionReports = zip plan.workflowGenericCompiledActions reports
      (preCommitReports, postCommitReports) = partition (genericActionRunsBeforeEventCommit . fst) actionReports
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

genericActionRunsBeforeEventCommit :: WorkflowPlannedActionOf effect action -> Bool
genericActionRunsBeforeEventCommit action =
  action.workflowGenericPlannedMetadata.workflowEffectCommitOrder == PreCommit

executeWorkflowCheckedActions :: Monad m => ActionExecutor m -> [WorkflowPlannedAction] -> m (Either WorkflowActionFailure [ActionExecutionReport])
executeWorkflowCheckedActions executor =
  go []
 where
  go reports [] = pure (Right (reverse reports))
  go reports (action : rest) = do
    report <- executePlannedAction executor ExecuteActions action.workflowPlannedAction
    case workflowActionFailure action report of
      Just failure -> pure (Left (failure {workflowFailurePriorReports = reverse reports}))
      Nothing -> go (report : reports) rest

workflowActionFailure :: WorkflowPlannedAction -> ActionExecutionReport -> Maybe WorkflowActionFailure
workflowActionFailure action report =
  case report.actionExecutionOutcome of
    ActionHardFailed hardFailure ->
      Just
        WorkflowActionFailure
          { workflowFailedAction = action
          , workflowFailedReport = report
          , workflowFailurePriorReports = []
          , workflowFailureClassification = hardFailureClassification hardFailure
          , workflowFailureCommandReport = commandReportFromExecution report
          }
    _ ->
      Nothing

hardFailureClassification :: HardFailure -> FailureClassification
hardFailureClassification = \case
  CommandHardFailed reason -> classifyExternalFailureText reason

workflowActionFailureReports :: WorkflowActionFailure -> [ActionExecutionReport]
workflowActionFailureReports failure =
  failure.workflowFailurePriorReports <> [failure.workflowFailedReport]

commandReportFromExecution :: ActionExecutionReport -> Maybe CommandReport
commandReportFromExecution report =
  case report.actionExecutionResult of
    CommandActionResult commandReport -> Just commandReport
    _ -> Nothing
