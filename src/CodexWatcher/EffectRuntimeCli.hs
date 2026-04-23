{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.EffectRuntimeCli
  ( defaultEffectRuntimeConfig
  , defaultEffectRuntimeConfigWithPlannerScope
  , plannerTurnInputForScope
  ) where

import CodexWatcher.EffectInterpreter
import CodexWatcher.IssueText (issueNumbersText)
import CodexWatcher.RuntimeDefaults
import CodexWatcher.TurnOutput
import CodexWatcher.Types
import Data.Text qualified as Text

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig =
  defaultEffectRuntimeConfigWithPlannerScope []

defaultEffectRuntimeConfigWithPlannerScope :: [IssueNumber] -> RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfigWithPlannerScope scopeIssues repo workdir stateDir =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = stateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = 1
    , effectRuntimePlannerThreadInstructions = issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues
    , effectRuntimePlannerTurn =
        (turnConfig (plannerTurnInputForScope scopeIssues) (Just plannerTurnOutputSchema))
          { turnRuntimeCollaborationMode =
              Just
                (defaultPlanCollaborationMode (issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues))
          }
    , effectRuntimeWorkerTurn = turnConfig prReviewWorkerTurnInput (Just prReviewWorkerTurnOutputSchema)
    , effectRuntimeIssuePlanTurn = turnConfig issuePlanTurnInput (Just issuePlanTurnOutputSchema)
    , effectRuntimeIssueImplementationTurn = turnConfig issueImplementationTurnInput (Just issueImplementationTurnOutputSchema)
    , effectRuntimeReviewerTurn = turnConfig "Reviewer prompt is generated per PR target commit." (Just reviewerTurnOutputSchema)
    }
 where
  turnConfig input outputSchema =
    TurnRuntimeConfig
      { turnRuntimeCwd = workdir
      , turnRuntimeModel = defaultModel
      , turnRuntimeEffort = defaultEffort
      , turnRuntimeApprovalPolicy = defaultApprovalPolicy
      , turnRuntimeSandboxPolicy = defaultSandboxPolicy
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = outputSchema
      , turnRuntimeCollaborationMode = Nothing
      }

plannerTurnInputForScope :: [IssueNumber] -> Text.Text
plannerTurnInputForScope [] =
  plannerTurnInput
plannerTurnInputForScope scopeIssues =
  plannerTurnInput
    <> " Target scope: only these root issues and their existing or newly created GitHub sub-issues are in scope: "
    <> issueNumbersText scopeIssues
    <> ". Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees. If a scoped root issue needs decomposition, propose concrete GitHub sub-issues under that root, then let the watcher re-enter planning. When returning ready_issues, blocked_issues, and dependencies, include only scoped root issues and descendants that belong to these issue trees."
