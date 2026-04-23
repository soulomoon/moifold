{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.TurnOutput
  ( issueImplementerThreadDeveloperInstructions
  , issueImplementationTurnInput
  , issuePlanModeDeveloperInstructions
  , issuePlanTurnInput
  , issuePlanningThreadDeveloperInstructions
  , prReviewWorkerTurnInput
  , prReviewThreadDeveloperInstructions
  , plannerTurnInput
  , reviewerPromptVersion
  , reviewerTurnInput
  , reviewerTurnOutputSchema
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  ) where

import CodexWatcher.PromptTemplates
  ( completionContractTemplate
  , issueImplementationTemplate
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
  , reviewerPromptVersion
  , reviewerTemplate
  , validationProtocolTemplate
  )
import CodexWatcher.IssueText (issueNumbersText)
import CodexWatcher.Types
import CodexWatcher.RuntimeDefaults (defaultEffort, defaultModel)
import Data.Aeson (Value, object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))

structuredTurnOutputSchema :: Value
structuredTurnOutputSchema =
  object
    [ "type" .= ("object" :: Text)
    , "additionalProperties" .= False
    , "required" .= (["outcome"] :: [Text])
    , "properties"
        .= object
          [ "outcome"
              .= object
                [ "type" .= ("string" :: Text)
                , "enum"
                    .= ( [ "complete"
                         , "incomplete"
                         , "blocked"
                         ] ::
                          [Text]
                       )
                ]
          , "reason" .= stringField
          , "summary" .= stringField
          , "comment" .= stringField
          , "evidence" .= stringField
          , "issues_to_create" .= issueArrayField ["title"]
          , "subissues_to_create" .= issueArrayField ["title", "body", "parentIssueNumber"]
          , "ready_issues" .= issueNumberArrayField
          , "blocked_issues" .= blockedIssueArrayField
          , "dependencies" .= dependencyArrayField
          ]
    ]

reviewerTurnOutputSchema :: Value
reviewerTurnOutputSchema =
  object
    [ "type" .= ("object" :: Text)
    , "additionalProperties" .= False
    , "required"
        .= ( [ "review_status"
             , "reviewed_commit_sha"
             , "reviewer_prompt_version"
             , "added_review_comment_count"
             , "lgtm_comment"
             , "findings_summary"
             , "blocked_reason"
             ] ::
              [Text]
           )
    , "properties"
        .= object
          [ "review_status"
              .= object
                [ "type" .= ("string" :: Text)
                , "enum" .= (["clean", "comments_added", "incomplete", "blocked"] :: [Text])
                ]
          , "reviewed_commit_sha" .= stringField
          , "reviewer_prompt_version" .= stringField
          , "added_review_comment_count" .= object ["type" .= ("integer" :: Text), "minimum" .= (0 :: Int)]
          , "lgtm_comment" .= nullableStringField
          , "findings_summary" .= object ["type" .= ("array" :: Text), "items" .= stringField]
          , "blocked_reason" .= nullableStringField
          ]
    ]

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON with an outcome field. Plain prose completion is not accepted."
    , "Use outcome=blocked with a reason when you cannot proceed safely."
    , "Use outcome=incomplete with a reason when follow-up is required."
    , "Use outcome=complete with a summary when the turn is done."
    ]

plannerTurnInput :: Text
plannerTurnInput =
  renderTemplate
    plannerTemplate
    [ ("structuredInstructions", structuredTurnOutcomeInstructions)
    , ("scopeInstructions", "")
    ]

issuePlanTurnInput :: Text
issuePlanTurnInput =
  renderTemplate issuePlanTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

issueImplementationTurnInput :: Text
issueImplementationTurnInput =
  renderTemplate issueImplementationTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewWorkerTurnInput :: Text
prReviewWorkerTurnInput =
  renderTemplate prReviewWorkerTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text -> Text
prReviewThreadDeveloperInstructions workdir stateDir config role
  | role == "reviewer" =
      renderPrReviewReviewerThreadDeveloperInstructions workdir config
  | otherwise =
      renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config

renderPrReviewWorkerThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text
renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config =
  renderTemplate
    prReviewWorkerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("validationProtocol", validationProtocol (stateDir </> "agent-state.json"))
    , ("publishProtocol", publishProtocol (stateDir </> "agent-state.json") config.prBranch)
    , ("completionContract", completionContract (stateDir </> "agent-state.json"))
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
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.issueBranch)
    , ("workerModel", defaultModel)
    , ("planEffort", defaultEffort)
    , ("issueStatePath", Text.pack (stateDir </> "issue-state.json"))
    , ("issuePlanPath", Text.pack (stateDir </> "issue-plan.md"))
    ]

reviewerTurnInput :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text
reviewerTurnInput workdir reviewerStatePath config reviewTargetSha =
  renderTemplate
    reviewerTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("reviewTargetSha", unCommitSha reviewTargetSha)
    , ("reviewerPromptVersion", reviewerPromptVersion)
    , ("reviewerStatePath", Text.pack reviewerStatePath)
    ]

validationProtocol :: FilePath -> Text
validationProtocol agentStatePath =
  renderTemplate
    validationProtocolTemplate
    [("agentStatePath", Text.pack agentStatePath)]

publishProtocol :: FilePath -> BranchName -> Text
publishProtocol agentStatePath branch =
  renderTemplate
    publishProtocolTemplate
    [ ("agentStatePath", Text.pack agentStatePath)
    , ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    , ("prHeadBranch", unBranchName branch)
    ]

completionContract :: FilePath -> Text
completionContract agentStatePath =
  renderTemplate
    completionContractTemplate
    [("agentStatePath", Text.pack agentStatePath)]

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

stringField :: Value
stringField =
  object ["type" .= ("string" :: Text)]

nullableStringField :: Value
nullableStringField =
  object ["type" .= (["string", "null"] :: [Text])]

issueArrayField :: [Text] -> Value
issueArrayField requiredFields =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= requiredFields
          , "properties"
              .= object
                [ "title" .= stringField
                , "body" .= stringField
                , "parentIssueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                ]
          ]
    ]

issueNumberArrayField :: Value
issueNumberArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
    ]

blockedIssueArrayField :: Value
blockedIssueArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= (["issueNumber", "blockedBy"] :: [Text])
          , "properties"
              .= object
                [ "issueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                , "blockedBy" .= issueNumberArrayField
                , "reason" .= stringField
                ]
          ]
    ]

dependencyArrayField :: Value
dependencyArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= (["issueNumber", "dependsOn"] :: [Text])
          , "properties"
              .= object
                [ "issueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                , "dependsOn" .= issueNumberArrayField
                ]
          ]
    ]
