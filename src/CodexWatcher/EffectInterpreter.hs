{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.EffectInterpreter
  ( CompiledEffectPlan (..)
  , EffectRuntimeConfig (..)
  , PlannedAction (..)
  , TurnRuntimeConfig (..)
  , agentTurnPlanForEffect
  , compileEffect
  , compileEffectPlan
  , issuePlanFileText
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest)
import CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, nextRequestId)
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.PrReview.Types (PrConfig, ReviewEvidence)
import CodexWatcher.Effects
import CodexWatcher.Runtime.Paths
  ( RuntimeCwd
  , RuntimeStateDir
  , RuntimeWorkdir
  , runtimeCwdPath
  , runtimeStateDirFile
  , runtimeStateDirPath
  , runtimeWorkdirPath
  )
import CodexWatcher.Runtime.Command.Types (RuntimeCommand (..))
import CodexWatcher.TurnOutput
  ( issueFinalReviewTurnInput
  , issueFinalReviewTurnOutputSchema
  , issuePlanModeDeveloperInstructions
  , prReviewWorkerTurnInputWithEvidence
  , reviewerTurnInput
  , reviewerVerificationTurnInput
  )
import CodexWatcher.Workflow.Agent.Codex.Protocol qualified as AgentCodexProtocol
import CodexWatcher.Workflow.Agent.Types
  ( AgentRoleId
  , AgentTurnPlan (..)
  , finalReviewerAgentRoleId
  , issueImplementationWorkerAgentRoleId
  , issuePlanWorkerAgentRoleId
  , plannerAgentRoleId
  , prReviewVerificationReviewerAgentRoleId
  , prReviewWorkerAgentRoleId
  , reviewerAgentRoleId
  )
import Data.Aeson
  ( Value
  )
import Data.List (mapAccumL)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data TurnRuntimeConfig = TurnRuntimeConfig
  { turnRuntimeCwd :: RuntimeCwd
  , turnRuntimeModel :: Text
  , turnRuntimeEffort :: Text
  , turnRuntimeApprovalPolicy :: Text
  , turnRuntimeSandboxPolicy :: Text
  , turnRuntimeInput :: Text
  , turnRuntimeOutputSchema :: Maybe Value
  , turnRuntimeCollaborationMode :: Maybe Value
  }
  deriving stock (Eq, Show, Generic)

data EffectRuntimeConfig = EffectRuntimeConfig
  { effectRuntimeRepo :: RepoName
  , effectRuntimeWorkdir :: RuntimeWorkdir
  , effectRuntimeStateDir :: RuntimeStateDir
  , effectRuntimeMergeMethod :: Text
  , effectRuntimeNextRequestId :: RequestId
  , effectRuntimePlannerThreadInstructions :: Text
  , effectRuntimePlannerTurn :: TurnRuntimeConfig
  , effectRuntimeWorkerTurn :: TurnRuntimeConfig
  , effectRuntimeIssuePlanTurn :: TurnRuntimeConfig
  , effectRuntimeIssueImplementationTurn :: TurnRuntimeConfig
  , effectRuntimeReviewerTurn :: TurnRuntimeConfig
  }
  deriving stock (Eq, Show, Generic)

data PlannedAction
  = PlannedCommand RuntimeCommand
  | PlannedAppServerRequest AppServerRequest
  | PlannedWriteJson FilePath Value
  | PlannedWriteText FilePath Text
  | PlannedSleepUntilNextPoll
  | PlannedStopDaemon
  deriving stock (Eq, Show, Generic)

data CompiledEffectPlan = CompiledEffectPlan
  { compiledActions :: [PlannedAction]
  , compiledNextRequestId :: RequestId
  }
  deriving stock (Eq, Show, Generic)

compileEffectPlan :: EffectRuntimeConfig -> EffectPlan -> CompiledEffectPlan
compileEffectPlan config effects =
  let (finalRequestId, actionBatches) =
        mapAccumL
          ( \requestId effect ->
              let (actions, requestId') = compileEffect config requestId effect
               in (requestId', actions)
          )
          config.effectRuntimeNextRequestId
          effects
   in CompiledEffectPlan
        { compiledActions = concat actionBatches
        , compiledNextRequestId = finalRequestId
        }

compileEffect :: EffectRuntimeConfig -> RequestId -> SomeEffect -> ([PlannedAction], RequestId)
compileEffect config requestId (SomeEffect effect) =
  case effect of
    ReadOpenIssues repo ->
      unchanged [PlannedCommand (GhIssueListOpen repo)]
    ReadOpenPullRequests repo ->
      unchanged [PlannedCommand (GhPrListOpen repo)]
    ReadReviewThreads prConfig ->
      unchanged [PlannedCommand (GhReviewThreads prConfig)]
    StartPlannerTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartWorkerTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartIssuePlanWorkerTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartIssueImplementationWorkerTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartReviewerTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartReviewerVerificationTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    StartIssueFinalReviewTurn {} ->
      oneAppServerRequest (SomeEffect effect)
    PushBranch branch ->
      unchanged [PlannedCommand (GitPush (runtimeWorkdirPath config.effectRuntimeWorkdir) branch)]
    CreateIssue repo request ->
      unchanged [PlannedCommand (GhIssueCreate repo request)]
    CreatePullRequest issueConfig ->
      unchanged [PlannedCommand (GhCreatePullRequest (runtimeWorkdirPath config.effectRuntimeWorkdir) issueConfig)]
    UpdatePullRequestBody issueConfig prNumber ->
      unchanged [PlannedCommand (GhUpdatePullRequestBody (runtimeWorkdirPath config.effectRuntimeWorkdir) issueConfig prNumber (runtimeStateDirFile config.effectRuntimeStateDir "issue-plan.md"))]
    UpdateIssueFollowUp issueConfig evidence ->
      unchanged [PlannedCommand (GhIssueFollowUp issueConfig evidence)]
    CloseIssue issueConfig prNumber ->
      unchanged [PlannedCommand (GhIssueClose issueConfig prNumber)]
    ResolveReviewThread reviewThreadId ->
      unchanged [PlannedCommand (GhResolveReviewThread reviewThreadId)]
    ReplyReviewThread reviewThreadId comment ->
      unchanged [PlannedCommand (GhReplyReviewThread reviewThreadId comment)]
    PublishReviewFindings prConfig evidence ->
      unchanged [PlannedCommand (GhPrCommentReviewFindings prConfig evidence)]
    RecordIssuePlan issueConfig prNumber planMarkdown ->
      unchanged [PlannedWriteText (runtimeStateDirFile config.effectRuntimeStateDir "issue-plan.md") (issuePlanFileText issueConfig prNumber planMarkdown)]
    RecordPlanningGraph _graph ->
      unchanged []
    RecordBlocked _reason ->
      unchanged []
    MergePullRequest prNumber evidence ->
      unchanged [PlannedCommand (GhPrCleanReviewAndMerge config.effectRuntimeRepo prNumber evidence config.effectRuntimeMergeMethod)]
    StopDaemon ->
      unchanged [PlannedStopDaemon]
    SleepUntilNextPoll ->
      unchanged [PlannedSleepUntilNextPoll]
 where
  unchanged actions = (actions, requestId)
  oneAppServerRequest startTurnEffectValue =
    case agentTurnPlanForEffect config startTurnEffectValue of
      Just plan ->
        ( [PlannedAppServerRequest (AgentCodexProtocol.agentTurnStartRequest requestId plan)]
        , nextRequestId requestId
        )
      Nothing ->
        unchanged []

agentTurnPlanForEffect :: EffectRuntimeConfig -> SomeEffect -> Maybe AgentTurnPlan
agentTurnPlanForEffect config (SomeEffect effect) =
  case effect of
    StartPlannerTurn threadId ->
      Just (agentTurnPlanFromRuntimeConfig plannerAgentRoleId threadId config.effectRuntimePlannerTurn)
    StartWorkerTurn evidence threadId ->
      Just (agentTurnPlanFromRuntimeConfig prReviewWorkerAgentRoleId threadId (prReviewWorkerTurnRuntimeConfig config evidence))
    StartIssuePlanWorkerTurn issueConfig prNumber threadId ->
      Just (agentTurnPlanFromRuntimeConfig issuePlanWorkerAgentRoleId threadId (issuePlanTurnRuntimeConfig config issueConfig prNumber))
    StartIssueImplementationWorkerTurn threadId ->
      Just (agentTurnPlanFromRuntimeConfig issueImplementationWorkerAgentRoleId threadId config.effectRuntimeIssueImplementationTurn)
    StartReviewerTurn prConfig reviewTargetSha threadId ->
      Just (agentTurnPlanFromRuntimeConfig reviewerAgentRoleId threadId (reviewerTurnRuntimeConfig config prConfig reviewTargetSha))
    StartReviewerVerificationTurn prConfig evidence reviewTargetSha threadId ->
      Just (agentTurnPlanFromRuntimeConfig prReviewVerificationReviewerAgentRoleId threadId (reviewerVerificationTurnRuntimeConfig config prConfig evidence reviewTargetSha))
    StartIssueFinalReviewTurn issueConfig prNumber reviewTargetSha threadId ->
      Just (agentTurnPlanFromRuntimeConfig finalReviewerAgentRoleId threadId (issueFinalReviewTurnRuntimeConfig config issueConfig prNumber reviewTargetSha))
    _ ->
      Nothing

agentTurnPlanFromRuntimeConfig :: AgentRoleId -> ThreadId -> TurnRuntimeConfig -> AgentTurnPlan
agentTurnPlanFromRuntimeConfig roleId threadId config =
  AgentTurnPlan
    { agentTurnPlanRoleId = roleId
    , agentTurnPlanThreadId = threadId
    , agentTurnPlanCwd = runtimeCwdPath config.turnRuntimeCwd
    , agentTurnPlanEffort = config.turnRuntimeEffort
    , agentTurnPlanModel = config.turnRuntimeModel
    , agentTurnPlanApprovalPolicy = config.turnRuntimeApprovalPolicy
    , agentTurnPlanSandboxPolicy = config.turnRuntimeSandboxPolicy
    , agentTurnPlanInput = config.turnRuntimeInput
    , agentTurnPlanOutputSchema = config.turnRuntimeOutputSchema
    , agentTurnPlanCollaborationMode = config.turnRuntimeCollaborationMode
    }

issuePlanFileText :: IssueConfig -> PrNumber -> Text -> Text
issuePlanFileText issueConfig prNumber planMarkdown =
  Text.unlines
    [ "---"
    , "issue_number: " <> Text.pack (show (unIssueNumber (issueNumber issueConfig)))
    , "pr_number: " <> Text.pack (show (unPrNumber prNumber))
    , "branch: " <> unBranchName (issueBranch issueConfig)
    , "---"
    , ""
    , Text.strip planMarkdown
    ]

prReviewWorkerTurnRuntimeConfig :: EffectRuntimeConfig -> ReviewEvidence -> TurnRuntimeConfig
prReviewWorkerTurnRuntimeConfig config evidence =
  let workerTurn = config.effectRuntimeWorkerTurn
   in workerTurn
        { turnRuntimeInput = prReviewWorkerTurnInputWithEvidence workerTurn.turnRuntimeInput evidence
        }

reviewerTurnRuntimeConfig :: EffectRuntimeConfig -> PrConfig -> CommitSha -> TurnRuntimeConfig
reviewerTurnRuntimeConfig config prConfig reviewTargetSha =
  config.effectRuntimeReviewerTurn
    { turnRuntimeInput =
        reviewerTurnInput
          (runtimeWorkdirPath config.effectRuntimeWorkdir)
          (runtimeStateDirFile config.effectRuntimeStateDir "reviewer-state.json")
          prConfig
          reviewTargetSha
    }

reviewerVerificationTurnRuntimeConfig :: EffectRuntimeConfig -> PrConfig -> ReviewEvidence -> CommitSha -> TurnRuntimeConfig
reviewerVerificationTurnRuntimeConfig config prConfig evidence reviewTargetSha =
  config.effectRuntimeReviewerTurn
    { turnRuntimeInput =
        reviewerVerificationTurnInput
          (runtimeWorkdirPath config.effectRuntimeWorkdir)
          (runtimeStateDirFile config.effectRuntimeStateDir "reviewer-state.json")
          prConfig
          evidence
          reviewTargetSha
    }

issueFinalReviewTurnRuntimeConfig :: EffectRuntimeConfig -> IssueConfig -> PrNumber -> CommitSha -> TurnRuntimeConfig
issueFinalReviewTurnRuntimeConfig config issueConfig prNumber reviewTargetSha =
  config.effectRuntimeReviewerTurn
    { turnRuntimeInput =
        issueFinalReviewTurnInput
          (runtimeWorkdirPath config.effectRuntimeWorkdir)
          (runtimeStateDirFile config.effectRuntimeStateDir "final-review-state.json")
          issueConfig
          prNumber
          reviewTargetSha
    , turnRuntimeOutputSchema = Just issueFinalReviewTurnOutputSchema
    }

issuePlanTurnRuntimeConfig :: EffectRuntimeConfig -> IssueConfig -> PrNumber -> TurnRuntimeConfig
issuePlanTurnRuntimeConfig config issueConfig prNumber =
  let instructions =
        issuePlanModeDeveloperInstructions
          (runtimeWorkdirPath config.effectRuntimeWorkdir)
          (runtimeStateDirPath config.effectRuntimeStateDir)
          issueConfig
          prNumber
   in
  config.effectRuntimeIssuePlanTurn
    { turnRuntimeInput = instructions <> "\n\n" <> config.effectRuntimeIssuePlanTurn.turnRuntimeInput
    , turnRuntimeCollaborationMode = Nothing
    }
