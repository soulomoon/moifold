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
  , compileEffect
  , compileEffectPlan
  , issuePlanFileText
  ) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName
  , RequestId
  , ThreadId
  , nextRequestId
  )
import CodexWatcher.Core.Reason (BlockedReason (..))
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
  , reviewerTurnInput
  , reviewerVerificationTurnInput
  )
import Data.Aeson
  ( Value
  , object
  , toJSON
  , (.=)
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
    StartPlannerTurn threadId ->
      oneAppServerRequest config.effectRuntimePlannerTurn threadId
    StartWorkerTurn threadId ->
      oneAppServerRequest config.effectRuntimeWorkerTurn threadId
    StartIssuePlanWorkerTurn issueConfig prNumber threadId ->
      oneAppServerRequest (issuePlanTurnRuntimeConfig config issueConfig prNumber) threadId
    StartIssueImplementationWorkerTurn threadId ->
      oneAppServerRequest config.effectRuntimeIssueImplementationTurn threadId
    StartReviewerTurn prConfig reviewTargetSha threadId ->
      oneAppServerRequest (reviewerTurnRuntimeConfig config prConfig reviewTargetSha) threadId
    StartReviewerVerificationTurn prConfig evidence reviewTargetSha threadId ->
      oneAppServerRequest (reviewerVerificationTurnRuntimeConfig config prConfig evidence reviewTargetSha) threadId
    StartIssueFinalReviewTurn issueConfig prNumber reviewTargetSha threadId ->
      oneAppServerRequest (issueFinalReviewTurnRuntimeConfig config issueConfig prNumber reviewTargetSha) threadId
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
    RequestChangesReview prConfig evidence ->
      unchanged [PlannedCommand (GhPrRequestChanges prConfig evidence)]
    DismissRequestChangesReview prConfig evidence ->
      unchanged [PlannedCommand (GhPrDismissRequestChanges prConfig evidence)]
    RecordIssuePlan issueConfig prNumber planMarkdown ->
      unchanged [PlannedWriteText (runtimeStateDirFile config.effectRuntimeStateDir "issue-plan.md") (issuePlanFileText issueConfig prNumber planMarkdown)]
    RecordPlanningGraph graph ->
      unchanged [PlannedWriteJson (runtimeStateDirFile config.effectRuntimeStateDir "planning-state.json") (toJSON graph)]
    RecordBlocked reason ->
      unchanged [PlannedWriteJson (runtimeStateDirFile config.effectRuntimeStateDir "block-state.json") (blockedStateJson reason)]
    MergePullRequest prNumber evidence ->
      unchanged [PlannedCommand (GhPrCleanReviewAndMerge config.effectRuntimeRepo prNumber evidence config.effectRuntimeMergeMethod)]
    StopDaemon ->
      unchanged [PlannedStopDaemon]
    SleepUntilNextPoll ->
      unchanged [PlannedSleepUntilNextPoll]
 where
  unchanged actions = (actions, requestId)
  oneAppServerRequest turnConfig threadId =
    ( [PlannedAppServerRequest (turnStartRequest requestId (turnStartOptions turnConfig threadId))]
    , nextRequestId requestId
    )

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

turnStartOptions :: TurnRuntimeConfig -> ThreadId -> TurnStartOptions
turnStartOptions config threadId =
  TurnStartOptions
    { turnThreadId = threadId
    , turnCwd = runtimeCwdPath config.turnRuntimeCwd
    , turnEffort = config.turnRuntimeEffort
    , turnModel = config.turnRuntimeModel
    , turnApprovalPolicy = config.turnRuntimeApprovalPolicy
    , turnSandboxPolicy = config.turnRuntimeSandboxPolicy
    , turnInput = config.turnRuntimeInput
    , turnOutputSchema = config.turnRuntimeOutputSchema
    , turnCollaborationMode = config.turnRuntimeCollaborationMode
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

blockedStateJson :: BlockedReason -> Value
blockedStateJson reason =
  object
    [ "blocked" .= True
    , "reason" .= unBlockedReason reason
    ]
