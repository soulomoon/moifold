{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.RuntimeConfig
  ( defaultEffectRuntimeConfig
  , defaultEffectRuntimeConfigWithPlannerScope
  , plannerTurnInputForScope
  ) where

import CodexWatcher.EffectInterpreter
import CodexWatcher.Runtime.Defaults
import CodexWatcher.Runtime.Paths (RuntimeCwd (..), RuntimeStateDir (..), RuntimeWorkdir (..))
import CodexWatcher.TurnOutput
import CodexWatcher.Workflow.Agent.Ids (RequestId (..))
import CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig =
  defaultEffectRuntimeConfigWithPlannerScope []

defaultEffectRuntimeConfigWithPlannerScope :: [IssueNumber] -> RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfigWithPlannerScope scopeIssues repo workdir stateDir =
  let runtimeWorkdir = RuntimeWorkdir workdir
      runtimeStateDir = RuntimeStateDir stateDir
      turnConfig input outputSchema =
        TurnRuntimeConfig
          { turnRuntimeCwd = RuntimeWorkdirCwd runtimeWorkdir
          , turnRuntimeModel = defaultModel
          , turnRuntimeEffort = defaultEffort
          , turnRuntimeApprovalPolicy = defaultApprovalPolicy
          , turnRuntimeSandboxPolicy = defaultSandboxPolicy
          , turnRuntimeInput = input
          , turnRuntimeOutputSchema = outputSchema
          , turnRuntimeCollaborationMode = Nothing
          }
   in EffectRuntimeConfig
        { effectRuntimeRepo = repo
        , effectRuntimeWorkdir = runtimeWorkdir
        , effectRuntimeStateDir = runtimeStateDir
        , effectRuntimeMergeMethod = "merge"
        , effectRuntimeNextRequestId = RequestId 1
        , effectRuntimePlannerThreadInstructions = issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues
        , effectRuntimePlannerTurn =
            (turnConfig (plannerTurnInputForScope scopeIssues) (Just plannerTurnOutputSchema))
              { turnRuntimeCwd = RuntimeStateDirCwd runtimeStateDir
              }
        , effectRuntimeWorkerTurn = turnConfig prReviewWorkerTurnInput (Just prReviewWorkerTurnOutputSchema)
        , effectRuntimeIssuePlanTurn = turnConfig issuePlanTurnInput (Just issuePlanTurnOutputSchema)
        , effectRuntimeIssueImplementationTurn = turnConfig issueImplementationTurnInput (Just issueImplementationTurnOutputSchema)
        , effectRuntimeReviewerTurn = turnConfig "Reviewer prompt is generated per PR target commit." (Just reviewerTurnOutputSchema)
        }
