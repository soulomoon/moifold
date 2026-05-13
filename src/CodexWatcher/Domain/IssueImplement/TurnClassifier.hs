{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssueImplement.TurnClassifier
  ( classifyIssueFinalReviewTurn
  , classifyIssueImplementationTurn
  , classifyIssuePlanTurn
  ) where

import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput (reviewerPromptVersion)
import CodexWatcher.Workflow.Agent.Ids (ThreadId)
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), reviewEvidenceFromSummaries)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data IssuePlanTurnReport = IssuePlanTurnReport
  { issuePlanReportOutcome :: Text
  , issuePlanReportReason :: Text
  , issuePlanReportSummary :: Text
  , issuePlanReportMarkdown :: Text
  }
  deriving stock (Eq, Show)

data IssueFinalReviewReport = IssueFinalReviewReport
  { finalReviewReportStatus :: Maybe Text
  , finalReviewReportCommit :: Maybe CommitSha
  , finalReviewReportPromptVersion :: Maybe Text
  , finalReviewReportIssueSolved :: Maybe Bool
  , finalReviewReportPlanImplemented :: Maybe Bool
  , finalReviewReportTestsSufficient :: Maybe Bool
  , finalReviewReportReworkRequired :: Maybe Bool
  , finalReviewReportVerificationSummary :: Maybe [Text]
  , finalReviewReportFindingsSummary :: Maybe [Text]
  , finalReviewReportBlockedReasonPresent :: Bool
  , finalReviewReportBlockedReason :: Maybe Text
  , finalReviewReportLgtmCommentPresent :: Bool
  , finalReviewReportLgtmComment :: Maybe Text
  }
  deriving stock (Eq, Show)

instance FromJSON IssuePlanTurnReport where
  parseJSON = withObject "IssuePlanTurnReport" \objectValue ->
    IssuePlanTurnReport
      <$> objectValue .: "outcome"
      <*> objectValue .: "reason"
      <*> objectValue .: "summary"
      <*> objectValue .: "plan_markdown"

instance FromJSON IssueFinalReviewReport where
  parseJSON = withObject "IssueFinalReviewReport" \objectValue -> do
    let has key = KeyMap.member (Key.fromString key) objectValue
    IssueFinalReviewReport
      <$> objectValue .:? "completion_status"
      <*> (fmap CommitSha <$> objectValue .:? "reviewed_commit_sha")
      <*> objectValue .:? "reviewer_prompt_version"
      <*> objectValue .:? "issue_solved"
      <*> objectValue .:? "plan_implemented"
      <*> objectValue .:? "tests_sufficient"
      <*> objectValue .:? "rework_required"
      <*> objectValue .:? "verification_summary"
      <*> objectValue .:? "findings_summary"
      <*> pure (has "blocked_reason")
      <*> objectValue .:? "blocked_reason"
      <*> pure (has "lgtm_comment")
      <*> objectValue .:? "lgtm_comment"

classifyIssuePlanTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssuePlanTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "plan turn completed without output" ObservedIssueImplementBlocked output ->
          Just observation
      | Just report <- output >>= parseIssuePlanTurnReport ->
          classifyIssuePlanReport report
      | otherwise ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))

classifyIssueImplementationTurn :: Maybe PrNumber -> Maybe ThreadId -> AppServerTurn -> Maybe IssueImplementObservation
classifyIssueImplementationTurn maybePr maybeReviewerThreadId turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedImplementationBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "implementation turn completed without output" ObservedImplementationBlocked output ->
          Just observation
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssueImplementation maybePr maybeReviewerThreadId structured
      | otherwise ->
          Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")

classifyIssueFinalReviewTurn :: CommitSha -> AppServerTurn -> Maybe IssueFinalReviewOutcome
classifyIssueFinalReviewTurn expectedCommit turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (IssueFinalReviewBlocked (BlockedReason reason))
    TurnCompleted output
      | Just outcome <- missingOutputBlocked "final reviewer turn completed without output" IssueFinalReviewBlocked output ->
          Just outcome
      | Just report <- output >>= parseIssueFinalReviewReport ->
          Just (validateIssueFinalReviewReport expectedCommit report)
      | otherwise ->
          Just (IssueFinalReviewIncomplete "final reviewer turn completed without final-review JSON")

parseIssuePlanTurnReport :: Text -> Maybe IssuePlanTurnReport
parseIssuePlanTurnReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

parseIssueFinalReviewReport :: Text -> Maybe IssueFinalReviewReport
parseIssueFinalReviewReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

classifyIssuePlanReport :: IssuePlanTurnReport -> Maybe IssueImplementObservation
classifyIssuePlanReport report =
  case normalize report.issuePlanReportOutcome of
    "complete"
      | Text.null planMarkdown ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed with empty plan_markdown"))
      | otherwise ->
          Just (ObservedPlanCompleted planMarkdown Nothing)
    "blocked" ->
      Just (ObservedIssueImplementBlocked (BlockedReason (nonEmptyDetail "plan turn blocked without reason" report.issuePlanReportReason)))
    _ ->
      Just (ObservedIssueImplementBlocked (BlockedReason ("unsupported issue plan outcome: " <> report.issuePlanReportOutcome)))
 where
  planMarkdown = Text.strip report.issuePlanReportMarkdown
  nonEmptyDetail fallback detail =
    case Text.strip detail of
      "" -> fallback
      stripped -> stripped

classifyStructuredIssueImplementation :: Maybe PrNumber -> Maybe ThreadId -> StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssueImplementation maybePr maybeReviewerThreadId = \case
  StructuredBlocked reason -> Just (ObservedImplementationBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedImplementationIncomplete reason)
  StructuredComplete _reason ->
    Just (completedImplementationObservation maybePr maybeReviewerThreadId)

completedImplementationObservation :: Maybe PrNumber -> Maybe ThreadId -> IssueImplementObservation
completedImplementationObservation maybePr maybeReviewerThreadId =
  case maybePr of
    Just prNumber -> ObservedImplementationCompleted prNumber maybeReviewerThreadId
    Nothing -> ObservedImplementationIncomplete "implementation completed before a pull request was known"

validateIssueFinalReviewReport :: CommitSha -> IssueFinalReviewReport -> IssueFinalReviewOutcome
validateIssueFinalReviewReport expectedCommit report =
  case missingIssueFinalReviewFields report of
    firstMissing : restMissing ->
      IssueFinalReviewIncomplete ("final review state missing required fields: " <> Text.intercalate ", " (firstMissing : restMissing))
    [] ->
      validateCompleteIssueFinalReviewReport expectedCommit report

validateCompleteIssueFinalReviewReport :: CommitSha -> IssueFinalReviewReport -> IssueFinalReviewOutcome
validateCompleteIssueFinalReviewReport expectedCommit report =
  case normalize (requiredText report.finalReviewReportStatus) of
    "blocked" ->
      IssueFinalReviewBlocked (BlockedReason (maybe "final reviewer marked blocked without a reason" nonEmptyOutput report.finalReviewReportBlockedReason))
    "incomplete" ->
      IssueFinalReviewIncomplete (maybe "final reviewer marked review incomplete" nonEmptyOutput report.finalReviewReportBlockedReason)
    "clean"
      | commonIssueFinalReviewIncomplete expectedCommit report /= Nothing ->
          maybe (IssueFinalReviewIncomplete "final review failed common validation") IssueFinalReviewIncomplete (commonIssueFinalReviewIncomplete expectedCommit report)
      | report.finalReviewReportIssueSolved /= Just True ->
          IssueFinalReviewIncomplete "clean final review must set issue_solved=true"
      | report.finalReviewReportPlanImplemented /= Just True ->
          IssueFinalReviewIncomplete "clean final review must set plan_implemented=true"
      | report.finalReviewReportTestsSufficient /= Just True ->
          IssueFinalReviewIncomplete "clean final review must set tests_sufficient=true"
      | report.finalReviewReportReworkRequired /= Just False ->
          IssueFinalReviewIncomplete "clean final review must set rework_required=false"
      | null (requiredFindings report.finalReviewReportVerificationSummary) ->
          IssueFinalReviewIncomplete "clean final review must include at least one verification_summary item"
      | not (null (requiredFindings report.finalReviewReportFindingsSummary)) ->
          IssueFinalReviewIncomplete "clean final review must leave findings_summary empty; use verification_summary for successful validation evidence"
      | otherwise ->
          IssueFinalReviewClean (CleanReviewEvidence expectedCommit (finalReviewCleanComment report))
    "rework_required"
      | commonIssueFinalReviewIncomplete expectedCommit report /= Nothing ->
          maybe (IssueFinalReviewIncomplete "final review failed common validation") IssueFinalReviewIncomplete (commonIssueFinalReviewIncomplete expectedCommit report)
      | report.finalReviewReportReworkRequired /= Just True ->
          IssueFinalReviewIncomplete "rework_required final review must set rework_required=true"
      | null (requiredFindings report.finalReviewReportFindingsSummary) ->
          IssueFinalReviewIncomplete "rework_required final review must include at least one findings_summary item"
      | otherwise ->
          IssueFinalReviewRework (reviewEvidenceFromSummaries (firstFinding (requiredFindings report.finalReviewReportFindingsSummary)) expectedCommit)
    other ->
      IssueFinalReviewIncomplete ("unsupported completion_status: " <> other)

commonIssueFinalReviewIncomplete :: CommitSha -> IssueFinalReviewReport -> Maybe Text
commonIssueFinalReviewIncomplete expectedCommit report
  | report.finalReviewReportCommit /= Just expectedCommit =
      Just ("final reviewer inspected " <> maybe "missing commit" unCommitSha report.finalReviewReportCommit <> ", expected " <> unCommitSha expectedCommit)
  | report.finalReviewReportPromptVersion /= Just reviewerPromptVersion =
      Just ("final reviewer used prompt version " <> maybe "missing" id report.finalReviewReportPromptVersion <> ", expected " <> reviewerPromptVersion)
  | otherwise =
      Nothing

missingIssueFinalReviewFields :: IssueFinalReviewReport -> [Text]
missingIssueFinalReviewFields report =
  concat
    [ missing "completion_status" report.finalReviewReportStatus
    , missing "reviewed_commit_sha" report.finalReviewReportCommit
    , missing "reviewer_prompt_version" report.finalReviewReportPromptVersion
    , missing "issue_solved" report.finalReviewReportIssueSolved
    , missing "plan_implemented" report.finalReviewReportPlanImplemented
    , missing "tests_sufficient" report.finalReviewReportTestsSufficient
    , missing "rework_required" report.finalReviewReportReworkRequired
    , missing "verification_summary" report.finalReviewReportVerificationSummary
    , missing "findings_summary" report.finalReviewReportFindingsSummary
    , missingPresence "blocked_reason" report.finalReviewReportBlockedReasonPresent
    , missingPresence "lgtm_comment" report.finalReviewReportLgtmCommentPresent
    ]
 where
  missing _fieldName (Just _) = []
  missing fieldName Nothing = [fieldName]
  missingPresence fieldName present
    | present = []
    | otherwise = [fieldName]

requiredText :: Maybe Text -> Text
requiredText =
  maybe "" id

requiredFindings :: Maybe [Text] -> [Text]
requiredFindings =
  maybe [] (filter (not . Text.null . Text.strip))

firstFinding :: [Text] -> NonEmpty Text
firstFinding [] = "final reviewer reported rework" :| []
firstFinding (first : rest) = first :| rest

finalReviewCleanComment :: IssueFinalReviewReport -> Text
finalReviewCleanComment report =
  case Text.strip <$> report.finalReviewReportLgtmComment of
    Just comment | not (Text.null comment) -> comment
    _ -> "LGTM"
