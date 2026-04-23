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
          { turnRuntimeCwd = stateDir
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
  plannerTaskInstructions <> "\n\n" <> plannerStructuredInstructions
plannerTurnInputForScope scopeIssues =
  plannerTaskInstructions <> "\n\n" <> plannerStructuredInstructions <> plannerScopeInstructions scopeIssues

plannerTaskInstructions :: Text.Text
plannerTaskInstructions =
  Text.unlines
    [ "Read the current issue snapshot and return the issue-planning decision JSON for the current scope."
    , "Inspect existing GitHub issues and sub-issues when needed before deciding."
    ]

plannerStructuredInstructions :: Text.Text
plannerStructuredInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Include every schema field, using empty arrays, empty strings, or null parentIssueNumber when a field is not applicable."
    , "Use outcome=blocked with a reason when you cannot proceed safely."
    , "Use outcome=incomplete with a reason when follow-up is required."
    , "Use outcome=complete with a summary when the turn is done."
    , ""
    , "For issue planning, inspect existing GitHub issues and existing sub-issues before splitting work."
    , "Use issues_to_create only for independent top-level issues."
    , "Use subissues_to_create for GitHub sub-issues, and every subissues_to_create item must include title, a concrete body, and parentIssueNumber."
    , "A sub-issue body must describe scope, acceptance criteria, dependencies/blockers, and how it stays compatible with sibling sub-issues."
    , "When a parent issue already has sub-issues, new sub-issues must be compatible with the existing set: do not duplicate titles/scopes, do not create overlapping work, and preserve dependency boundaries between siblings."
    , "After issue creation the watcher will re-enter planning."
    , "When no more issues need to be created, return ready_issues for issues safe to implement now, blocked_issues for issues that must wait, and dependencies for issue ordering."
    , "ready_issues must be an array of issue numbers, not objects."
    , "blocked_issues must use objects shaped as {\"issueNumber\": 27, \"blockedBy\": [26], \"reason\": \"...\"}."
    , "dependencies must use objects shaped as {\"issueNumber\": 27, \"dependsOn\": [26]}."
    , "Only issues listed in ready_issues can be started by fanout; do not list an issue as ready if another open issue must be completed first."
    , "Use outcome=complete only when the issue graph is stable and ready for dependency-aware implementer fanout."
    ]

plannerScopeInstructions :: [IssueNumber] -> Text.Text
plannerScopeInstructions scopeIssues =
  " Target scope: only these root issues and their existing or newly created GitHub sub-issues are in scope: "
    <> issueNumbersText scopeIssues
    <> ". Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees. If a scoped root issue needs decomposition, create concrete GitHub sub-issues under that root, then let the watcher re-enter planning. When returning ready_issues, blocked_issues, and dependencies, include only scoped root issues and descendants that belong to these issue trees."
