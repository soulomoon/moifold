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
import CodexWatcher.Effects
import CodexWatcher.Runtime
import CodexWatcher.TurnOutput (issuePlanModeDeveloperInstructions, reviewerTurnInput)
import CodexWatcher.Types
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
import System.FilePath ((</>))

data TurnRuntimeConfig = TurnRuntimeConfig
  { turnRuntimeCwd :: FilePath
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
  , effectRuntimeWorkdir :: FilePath
  , effectRuntimeStateDir :: FilePath
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
    PushBranch branch ->
      unchanged [PlannedCommand (GitPush config.effectRuntimeWorkdir branch)]
    CreateIssue repo request ->
      unchanged [PlannedCommand (GhIssueCreate repo request)]
    CreatePullRequest issueConfig ->
      unchanged [PlannedCommand (GhCreatePullRequest config.effectRuntimeWorkdir issueConfig)]
    UpdatePullRequestBody issueConfig prNumber ->
      unchanged [PlannedCommand (GhUpdatePullRequestBody config.effectRuntimeWorkdir issueConfig prNumber (config.effectRuntimeStateDir </> "issue-plan.md"))]
    CloseIssue issueConfig prNumber ->
      unchanged [PlannedCommand (GhIssueClose issueConfig prNumber)]
    ResolveReviewThread reviewThreadId ->
      unchanged [PlannedCommand (GhResolveReviewThread reviewThreadId)]
    RecordIssuePlan issueConfig prNumber planMarkdown ->
      unchanged [PlannedWriteText (config.effectRuntimeStateDir </> "issue-plan.md") (issuePlanFileText issueConfig prNumber planMarkdown)]
    RecordPlanningGraph graph ->
      unchanged [PlannedWriteJson (config.effectRuntimeStateDir </> "planning-state.json") (toJSON graph)]
    RecordBlocked reason ->
      unchanged [PlannedWriteJson (config.effectRuntimeStateDir </> "block-state.json") (blockedStateJson reason)]
    MergePullRequest prNumber evidence ->
      unchanged [PlannedCommand (GhPrCommentReviewAndMerge config.effectRuntimeRepo prNumber evidence config.effectRuntimeMergeMethod)]
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
    , turnCwd = config.turnRuntimeCwd
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
          config.effectRuntimeWorkdir
          (config.effectRuntimeStateDir </> "reviewer-state.json")
          prConfig
          reviewTargetSha
    }

issuePlanTurnRuntimeConfig :: EffectRuntimeConfig -> IssueConfig -> PrNumber -> TurnRuntimeConfig
issuePlanTurnRuntimeConfig config issueConfig prNumber =
  let instructions =
        issuePlanModeDeveloperInstructions
          config.effectRuntimeWorkdir
          config.effectRuntimeStateDir
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
