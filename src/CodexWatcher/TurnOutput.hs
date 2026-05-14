{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.TurnOutput
  ( issueImplementerThreadDeveloperInstructions
  , issueImplementationTurnOutputSchema
  , issueImplementationTurnInput
  , issueFinalReviewTurnInput
  , issueFinalReviewTurnOutputSchema
  , issuePlanTurnOutputSchema
  , issuePlanModeDeveloperInstructions
  , issuePlanTurnInput
  , issuePlanningThreadDeveloperInstructions
  , plannerTurnOutputSchema
  , prReviewWorkerTurnInput
  , prReviewWorkerTurnOutputSchema
  , prReviewThreadDeveloperInstructions
  , plannerTurnInputForScope
  , prReviewWorkerTurnInputWithEvidence
  , reviewerPromptVersion
  , reviewerTurnInput
  , reviewerTurnOutputSchema
  , reviewerVerificationTurnInput
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  , TurnOutputContract (..)
  , issueFinalReviewTurnOutputContract
  , issueImplementationTurnOutputContract
  , issuePlanTurnOutputContract
  , plannerTurnOutputContract
  , prReviewWorkerTurnOutputContract
  , reviewerTurnOutputContract
  ) where

import CodexWatcher.PromptTemplates
  ( issueImplementationTemplate
  , issueImplementThreadDeveloperTemplate
  , issuePlanModeDeveloperTemplate
  , issuePlanTemplate
  , issuePlanningThreadDeveloperTemplate
  , plannerTemplate
  , prReviewReviewerThreadDeveloperTemplate
  , prReviewWorkerThreadDeveloperTemplate
  , prReviewWorkerTemplate
  , publishProtocolTemplate
  , renderTemplate
  , reviewerTemplate
  , validationProtocolTemplate
  )
import CodexWatcher.IssueText (issueNumbersText)
import CodexWatcher.TurnOutput.Contract
import CodexWatcher.TurnOutput.Version (reviewerPromptVersion)
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.PrReview.Types
  ( PrConfig (..)
  , ReviewEvidence (..)
  , reviewEvidenceSummaries
  , reviewEvidenceThreadComments
  , reviewEvidenceThreadIds
  )
import CodexWatcher.Runtime.Defaults (defaultEffort, defaultModel)
import CodexWatcher.TurnOutput.Schema
  ( issueFinalReviewTurnOutputSchema
  , issueImplementationTurnOutputSchema
  , issuePlanTurnOutputSchema
  , plannerTurnOutputSchema
  , prReviewWorkerTurnOutputSchema
  , reviewerTurnOutputSchema
  , structuredTurnOutputSchema
  )
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))

plannerTurnInputForScope :: [IssueNumber] -> Text
plannerTurnInputForScope scopeIssues =
  renderTemplate
    plannerTemplate
    [ ("structuredInstructions", turnOutputContractInstructions plannerTurnOutputContract)
    , ("scopeInstructions", plannerTurnScopeInstructions scopeIssues)
    ]

issuePlanTurnInput :: Text
issuePlanTurnInput =
  renderTemplate issuePlanTemplate [("structuredInstructions", turnOutputContractInstructions issuePlanTurnOutputContract)]

issueImplementationTurnInput :: Text
issueImplementationTurnInput =
  renderTemplate issueImplementationTemplate [("structuredInstructions", turnOutputContractInstructions (issueImplementationTurnOutputContract Nothing Nothing))]

prReviewWorkerTurnInput :: Text
prReviewWorkerTurnInput =
  renderTemplate prReviewWorkerTemplate [("structuredInstructions", turnOutputContractInstructions prReviewWorkerTurnOutputContract)]

prReviewWorkerTurnInputWithEvidence :: Text -> ReviewEvidence -> Text
prReviewWorkerTurnInputWithEvidence baseInput evidence =
  Text.unlines
    [ baseInput
    , ""
    , "Watcher-provided review feedback to address in this turn:"
    , reviewFeedbackBullets evidence
    , "Read the full GitHub thread/review context if needed, then fix these items, validate, commit, and push."
    ]

prReviewThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text -> Text
prReviewThreadDeveloperInstructions workdir stateDir config role
  | role == "reviewer" =
      renderPrReviewReviewerThreadDeveloperInstructions workdir config
  | otherwise =
      renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config

renderPrReviewWorkerThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text
renderPrReviewWorkerThreadDeveloperInstructions workdir _stateDir config =
  renderTemplate
    prReviewWorkerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("validationProtocol", validationProtocol)
    , ("publishProtocol", publishProtocol config.prBranch)
    ]

renderPrReviewReviewerThreadDeveloperInstructions :: FilePath -> PrConfig -> Text
renderPrReviewReviewerThreadDeveloperInstructions workdir config =
  renderTemplate
    prReviewReviewerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("reviewerModel", defaultModel)
    , ("reviewerEffort", defaultEffort)
    ]

issueImplementerThreadDeveloperInstructions :: FilePath -> FilePath -> IssueConfig -> Text
issueImplementerThreadDeveloperInstructions workdir stateDir config =
  renderTemplate
    issueImplementThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.issueRepo)
    , ("issueNumber", Text.pack (show (unIssueNumber config.issueNumber)))
    , ("issueUrl", issueUrl config.issueRepo config.issueNumber)
    , ("workdir", Text.pack workdir)
    , ("baseBranch", "origin/HEAD")
    , ("branch", unBranchName config.issueBranch)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.issueBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("issueStatePath", Text.pack (stateDir </> "issue-state.json"))
    , ("issuePlanPath", Text.pack (stateDir </> "issue-plan.md"))
    , ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    ]

issuePlanningThreadDeveloperInstructions :: FilePath -> RepoName -> [IssueNumber] -> Text
issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues =
  renderTemplate
    issuePlanningThreadDeveloperTemplate
    [ ("repoFullName", unRepoName repo)
    , ("plannerModel", defaultModel)
    , ("plannerEffort", defaultEffort)
    , ("issueSnapshotPath", Text.pack (stateDir </> "issue-snapshot.json"))
    , ("scopeInstructions", issuePlanningScopeInstructions scopeIssues)
    ]

issuePlanModeDeveloperInstructions :: FilePath -> FilePath -> IssueConfig -> PrNumber -> Text
issuePlanModeDeveloperInstructions workdir stateDir config prNumber =
  renderTemplate
    issuePlanModeDeveloperTemplate
    [ ("repoFullName", unRepoName config.issueRepo)
    , ("issueNumber", Text.pack (show (unIssueNumber config.issueNumber)))
    , ("issueUrl", issueUrl config.issueRepo config.issueNumber)
    , ("prNumber", Text.pack (show (unPrNumber prNumber)))
    , ("prUrl", prUrl config.issueRepo prNumber)
    , ("workdir", Text.pack workdir)
    , ("baseBranch", "origin/HEAD")
    , ("branch", unBranchName config.issueBranch)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.issueBranch)
    , ("workerModel", defaultModel)
    , ("planEffort", defaultEffort)
    , ("issueStatePath", Text.pack (stateDir </> "issue-state.json"))
    , ("issuePlanPath", Text.pack (stateDir </> "issue-plan.md"))
    ]

reviewerTurnInput :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text
reviewerTurnInput workdir reviewerStatePath config reviewTargetSha =
  reviewerTurnInputWithVerification workdir reviewerStatePath config reviewTargetSha noVerificationInstructions

issueFinalReviewTurnInput :: FilePath -> FilePath -> IssueConfig -> PrNumber -> CommitSha -> Text
issueFinalReviewTurnInput workdir reviewerStatePath config prNumber reviewTargetSha =
  Text.unlines
    [ "Final-review the merged implementation for issue #" <> Text.pack (show (unIssueNumber config.issueNumber)) <> " and PR #" <> Text.pack (show (unPrNumber prNumber)) <> "."
    , ""
    , "Repository: " <> unRepoName config.issueRepo
    , "Issue: " <> issueUrl config.issueRepo config.issueNumber
    , "PR: " <> prUrl config.issueRepo prNumber
    , "Workdir: " <> Text.pack workdir
    , "Branch used for the implementation: " <> unBranchName config.issueBranch
    , "Review target commit: " <> unCommitSha reviewTargetSha
    , "Reviewer prompt version: " <> reviewerPromptVersion
    , "Reviewer state path: " <> Text.pack reviewerStatePath
    , ""
    , "Task:"
    , "- Inspect the issue body/comments, PR body, PR plan, merged implementation, tests, and relevant local code."
    , "- Decide whether the implementation truly solved the issue and whether the PR plan was actually implemented."
    , "- Do not treat an empty PR diff against the base branch as clean by itself; post-merge review must validate behavior against the issue and PR plan."
    , "- If the issue is not solved, the plan is not implemented, tests are insufficient, or follow-up work is needed, use completion_status=rework_required."
    , "- Put only actionable rework items in findings_summary. Do not put successful validation evidence there."
    , "- Put successful validation evidence, inspected files, and test results in verification_summary."
    , "- If everything is solved and no follow-up is needed, use completion_status=clean."
    , "- If you cannot complete the check, use completion_status=incomplete or blocked with a concrete blocked_reason."
    , ""
    , "Restrictions:"
    , "- Do not edit files, commit, push, approve, close the issue, create PRs, or resolve GitHub review threads."
    , "- Return only a value matching the provided output schema."
    ]

reviewerVerificationTurnInput :: FilePath -> FilePath -> PrConfig -> ReviewEvidence -> CommitSha -> Text
reviewerVerificationTurnInput workdir reviewerStatePath config evidence reviewTargetSha =
  reviewerTurnInputWithVerification
    workdir
    reviewerStatePath
    config
    reviewTargetSha
    (verificationInstructions evidence)

reviewerTurnInputWithVerification :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text -> Text
reviewerTurnInputWithVerification workdir _reviewerStatePath config reviewTargetSha verificationInstructionsText =
  renderTemplate
    reviewerTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("reviewTargetSha", unCommitSha reviewTargetSha)
    , ("reviewerPromptVersion", reviewerPromptVersion)
    , ("verificationInstructions", verificationInstructionsText)
    ]

noVerificationInstructions :: Text
noVerificationInstructions =
  Text.unlines
    [ "Review-thread resolution fields:"
    , "- This is a normal review pass with no watcher-owned prior thread verification."
    , "- Use prior_findings_status=not_applicable."
    , "- Return empty arrays for solved_threads and remaining_review_threads."
    , "- If you find any new actionable finding, use new_findings_status=found and put a concrete summary in new_findings_summary; the watcher will publish it to the PR as a non-approval findings comment and route it to the worker."
    , "- If you find no actionable finding, use new_findings_status=none and leave new_findings_summary empty."
    ]

verificationInstructions :: ReviewEvidence -> Text
verificationInstructions evidence =
  Text.unlines
    [ "Review-feedback verification:"
    , "- The previous worker turn claimed to fix this review feedback from commit " <> unCommitSha evidence.reviewedCommit <> ":"
    , reviewFeedbackBullets evidence
    , "- Re-read those GitHub review threads and watcher review-findings comments as applicable, then inspect the current local PR code."
    , "- Put fixed prior review threads in solved_threads as structured objects with thread_id and resolution_summary; the watcher will resolve only those solved threads."
    , "- Put prior review threads that still apply in remaining_review_threads as structured objects with thread_id and comment; the watcher will add those comments as replies under the remaining GitHub review threads."
    , "- Set prior_findings_status=resolved only when all prior feedback is fixed. Leave remaining_review_threads empty. You may use prior_findings_summary for short resolved-summary notes when the prior feedback was not tied to a GitHub review thread."
    , "- Set prior_findings_status=unresolved when prior thread or summary feedback still applies; include remaining prior threads in remaining_review_threads and still-applicable prior summary feedback in prior_findings_summary."
    , "- Set new_findings_status=found only when you find actionable problems beyond the prior feedback; put those items in new_findings_summary."
    , "- Set new_findings_status=none when you find no new actionable findings."
    , "- If all prior feedback is fixed and there are no new actionable findings, use prior_findings_status=resolved and new_findings_status=none."
    , "- Do not resolve GitHub review threads yourself; the watcher resolves only the threads you list in solved_threads."
    ]

reviewFeedbackBullets :: ReviewEvidence -> Text
reviewFeedbackBullets evidence =
  Text.unlines (threadCommentBullets <> threadBullets <> summaryBullets)
 where
  threadCommentPairs =
    reviewEvidenceThreadComments evidence
  threadCommentIds =
    fmap fst threadCommentPairs
  threadCommentBullets =
    [ "- review thread " <> unReviewThreadId threadId <> ": " <> Text.strip comment
    | (threadId, comment) <- threadCommentPairs
    ]
  threadBullets =
    [ "- review thread " <> unReviewThreadId threadId
    | threadId <- reviewEvidenceThreadIds evidence
    , threadId `notElem` threadCommentIds
    ]
  summaryBullets =
    ["- " <> summary | summary <- reviewEvidenceSummaries evidence]

validationProtocol :: Text
validationProtocol =
  renderTemplate
    validationProtocolTemplate
    []

publishProtocol :: BranchName -> Text
publishProtocol branch =
  renderTemplate
    publishProtocolTemplate
    [ ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    , ("prHeadBranch", unBranchName branch)
    ]

prUrl :: RepoName -> PrNumber -> Text
prUrl repo number =
  "https://github.com/" <> unRepoName repo <> "/pull/" <> Text.pack (show (unPrNumber number))

issueUrl :: RepoName -> IssueNumber -> Text
issueUrl repo number =
  "https://github.com/" <> unRepoName repo <> "/issues/" <> Text.pack (show (unIssueNumber number))

branchOrUnknownUseTools :: BranchName -> Text
branchOrUnknownUseTools branch =
  let value = Text.strip (unBranchName branch)
   in if Text.null value then "unknown; inspect repository remotes" else value

issuePlanningScopeInstructions :: [IssueNumber] -> Text
issuePlanningScopeInstructions [] =
  ""
issuePlanningScopeInstructions scopeIssues =
  Text.unlines
    [ ""
    , "Target scope:"
    , "- Only these root issues and their existing or newly created GitHub sub-issues are in scope: " <> issueNumbersText scopeIssues <> "."
    , "- Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees."
    , "- If a scoped root issue needs decomposition, propose concrete GitHub sub-issues under that root, then let the watcher re-enter planning."
    ]

plannerTurnScopeInstructions :: [IssueNumber] -> Text
plannerTurnScopeInstructions [] =
  ""
plannerTurnScopeInstructions scopeIssues =
  Text.unlines
    [ ""
    , "Target scope:"
    , "- Only these root issues and their existing or newly created GitHub sub-issues are in scope: " <> issueNumbersText scopeIssues <> "."
    , "- Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees."
    , "- If a scoped root issue needs decomposition, propose concrete GitHub sub-issues under that root, then let the watcher re-enter planning."
    , "- When returning dependencies, include only scoped root issues and descendants that belong to these issue trees."
    ]
