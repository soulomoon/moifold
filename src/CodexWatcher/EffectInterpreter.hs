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
  ) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.Effects
import CodexWatcher.Runtime
import CodexWatcher.RuntimeDefaults (defaultPlanCollaborationMode)
import CodexWatcher.TurnOutput (issuePlanModeDeveloperInstructions, reviewerTurnInput, reviewerTurnOutputSchema)
import CodexWatcher.Types
import Data.Aeson
  ( Value
  , object
  , toJSON
  , (.=)
  )
import Data.Text (Text)
import System.FilePath ((</>))
import GHC.Generics (Generic)

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
  , effectRuntimeNextRequestId :: Int
  , effectRuntimePlannerTurn :: TurnRuntimeConfig
  , effectRuntimeWorkerTurn :: TurnRuntimeConfig
  , effectRuntimeIssueTriageTurn :: TurnRuntimeConfig
  , effectRuntimeIssuePlanTurn :: TurnRuntimeConfig
  , effectRuntimeIssueImplementationTurn :: TurnRuntimeConfig
  , effectRuntimeReviewerTurn :: TurnRuntimeConfig
  }
  deriving stock (Eq, Show, Generic)

data PlannedAction
  = PlannedCommand RuntimeCommand
  | PlannedAppServerRequest AppServerRequest
  | PlannedWriteJson FilePath Value
  | PlannedSleepUntilNextPoll
  | PlannedStopDaemon
  deriving stock (Eq, Show, Generic)

data CompiledEffectPlan = CompiledEffectPlan
  { compiledActions :: [PlannedAction]
  , compiledNextRequestId :: Int
  }
  deriving stock (Eq, Show, Generic)

compileEffectPlan :: EffectRuntimeConfig -> EffectPlan -> CompiledEffectPlan
compileEffectPlan config =
  foldl appendCompiledEffect (CompiledEffectPlan [] config.effectRuntimeNextRequestId)
 where
  appendCompiledEffect plan effect =
    let (actions, nextRequestId) = compileEffect config plan.compiledNextRequestId effect
     in CompiledEffectPlan
          { compiledActions = plan.compiledActions <> actions
          , compiledNextRequestId = nextRequestId
          }

compileEffect :: EffectRuntimeConfig -> Int -> SomeEffect -> ([PlannedAction], Int)
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
    StartIssueTriageWorkerTurn threadId ->
      oneAppServerRequest config.effectRuntimeIssueTriageTurn threadId
    StartIssuePlanWorkerTurn issueConfig threadId ->
      oneAppServerRequest (issuePlanTurnRuntimeConfig config issueConfig) threadId
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
    ResolveReviewThread reviewThreadId ->
      unchanged [PlannedCommand (GhResolveReviewThread reviewThreadId)]
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
    , requestId + 1
    )

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
    , turnRuntimeOutputSchema = Just reviewerTurnOutputSchema
    }

issuePlanTurnRuntimeConfig :: EffectRuntimeConfig -> IssueConfig -> TurnRuntimeConfig
issuePlanTurnRuntimeConfig config issueConfig =
  config.effectRuntimeIssuePlanTurn
    { turnRuntimeCollaborationMode =
        Just
          (defaultPlanCollaborationMode (issuePlanModeDeveloperInstructions config.effectRuntimeWorkdir config.effectRuntimeStateDir issueConfig))
    }

blockedStateJson :: BlockedReason -> Value
blockedStateJson reason =
  object
    [ "blocked" .= True
    , "reason" .= unBlockedReason reason
    ]
