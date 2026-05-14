{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.TurnOutput.Contract
  ( TurnOutputContract (..)
  , issueFinalReviewTurnOutputContract
  , issueImplementationTurnOutputContract
  , issuePlanStructuredTurnOutcomeInstructions
  , issuePlanTurnOutputContract
  , plannerStructuredTurnOutcomeInstructions
  , plannerTurnOutputContract
  , prReviewWorkerTurnOutputContract
  , reviewerTurnOutputContract
  , structuredTurnOutcomeInstructions
  ) where

import CodexWatcher.Domain.IssueImplement.TurnClassifier
  ( classifyIssueFinalReviewTurn
  , classifyIssueImplementationTurn
  , classifyIssuePlanTurn
  )
import CodexWatcher.Domain.IssueImplement.Watcher (IssueFinalReviewOutcome, IssueImplementObservation)
import CodexWatcher.Domain.IssuePlanning.TurnClassifier (classifyIssuePlanningTurn)
import CodexWatcher.Domain.IssuePlanning.Watcher (IssuePlanningObservation)
import CodexWatcher.Domain.PrReview.TurnClassifier
  ( classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  )
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation)
import CodexWatcher.TurnOutput.Schema
  ( issueFinalReviewTurnOutputSchema
  , issueImplementationTurnOutputSchema
  , issuePlanTurnOutputSchema
  , plannerTurnOutputSchema
  , prReviewWorkerTurnOutputSchema
  , reviewerTurnOutputSchema
  )
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
import CodexWatcher.Workflow.Agent.Ids (ThreadId)
import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)
import Data.Aeson (Value)
import Data.Text (Text)
import Data.Text qualified as Text

data TurnOutputContract observation = TurnOutputContract
  { turnOutputContractName :: Text
  , turnOutputContractInstructions :: Text
  , turnOutputContractSchema :: Value
  , turnOutputContractClassify :: AppServerTurn -> Maybe observation
  }

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Every schema includes outcome, reason, and summary; include every schema field, using empty strings or arrays when a field is not applicable."
    , "Use outcome=blocked with a non-empty reason when you cannot proceed safely."
    , "Use outcome=incomplete with a non-empty reason when follow-up is required."
    , "Use outcome=complete with a non-empty summary when the turn is done; reason may be an empty string."
    ]

issuePlanStructuredTurnOutcomeInstructions :: Text
issuePlanStructuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Include every schema field, using an empty string when a string field is not applicable."
    , "Use outcome=blocked with a non-empty reason when planning cannot proceed safely."
    , "Use outcome=complete with a non-empty summary, empty reason, and non-empty plan_markdown when the plan is ready."
    , "Do not use outcome=incomplete; this planning schema only accepts complete or blocked."
    ]

plannerStructuredTurnOutcomeInstructions :: Text
plannerStructuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Include every schema field, using empty arrays, empty strings, or null parentIssueNumber when a field is not applicable."
    , "Use outcome=blocked with a reason when you cannot proceed safely."
    , "Use outcome=incomplete with a reason when follow-up investigation or issue creation re-entry is required."
    , "Use outcome=complete with a summary when the issue graph is stable enough for the watcher to continue."
    , "issues_to_create and subissues_to_create are watcher-applied requests; do not create issues directly."
    , "dependencies is the authoritative planning graph input. The watcher recomputes canonical ready_issues and blocked_issues from dependencies and current GitHub issue facts."
    , "ready_issues and blocked_issues must still be present for schema compatibility, but treat them as non-authoritative hints."
    ]

plannerTurnOutputContract :: TurnOutputContract IssuePlanningObservation
plannerTurnOutputContract =
  TurnOutputContract
    { turnOutputContractName = "issue-planner"
    , turnOutputContractInstructions = plannerStructuredTurnOutcomeInstructions
    , turnOutputContractSchema = plannerTurnOutputSchema
    , turnOutputContractClassify = classifyIssuePlanningTurn
    }

issuePlanTurnOutputContract :: TurnOutputContract IssueImplementObservation
issuePlanTurnOutputContract =
  TurnOutputContract
    { turnOutputContractName = "issue-plan"
    , turnOutputContractInstructions = issuePlanStructuredTurnOutcomeInstructions
    , turnOutputContractSchema = issuePlanTurnOutputSchema
    , turnOutputContractClassify = classifyIssuePlanTurn
    }

issueImplementationTurnOutputContract :: Maybe PrNumber -> Maybe ThreadId -> TurnOutputContract IssueImplementObservation
issueImplementationTurnOutputContract maybePr maybeReviewerThreadId =
  TurnOutputContract
    { turnOutputContractName = "issue-implementation"
    , turnOutputContractInstructions = structuredTurnOutcomeInstructions
    , turnOutputContractSchema = issueImplementationTurnOutputSchema
    , turnOutputContractClassify = classifyIssueImplementationTurn maybePr maybeReviewerThreadId
    }

prReviewWorkerTurnOutputContract :: TurnOutputContract PrReviewObservation
prReviewWorkerTurnOutputContract =
  TurnOutputContract
    { turnOutputContractName = "pr-review-worker"
    , turnOutputContractInstructions = structuredTurnOutcomeInstructions
    , turnOutputContractSchema = prReviewWorkerTurnOutputSchema
    , turnOutputContractClassify = classifyPrReviewWorkerTurn
    }

reviewerTurnOutputContract :: CommitSha -> TurnOutputContract PrReviewObservation
reviewerTurnOutputContract commit =
  TurnOutputContract
    { turnOutputContractName = "pr-reviewer"
    , turnOutputContractInstructions = structuredTurnOutcomeInstructions
    , turnOutputContractSchema = reviewerTurnOutputSchema
    , turnOutputContractClassify = classifyPrReviewReviewerTurn commit
    }

issueFinalReviewTurnOutputContract :: CommitSha -> TurnOutputContract IssueFinalReviewOutcome
issueFinalReviewTurnOutputContract commit =
  TurnOutputContract
    { turnOutputContractName = "issue-final-review"
    , turnOutputContractInstructions = structuredTurnOutcomeInstructions
    , turnOutputContractSchema = issueFinalReviewTurnOutputSchema
    , turnOutputContractClassify = classifyIssueFinalReviewTurn commit
    }
