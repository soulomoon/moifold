{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module GhGitSpec
  ( prop_ghGitParsesGitOutputs
  , prop_ghGitParsesIssueAndPrLists
  , prop_ghGitParsesPrCreateAndChecks
  , prop_ghGitParsesRemotePrMetadataVariants
  , prop_ghGitParsesRemoteIssueView
  , prop_ghGitParsesRemotePrView
  , prop_ghGitParsesReviewThreadsGraphql
  ) where

import CodexWatcher.GhGit
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), ReviewThreadId (..))
import Data.Aeson (Value (..), encode, object, toJSON, (.=))
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Either (isLeft)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Data.Text.Encoding qualified as Text.Encoding

jsonText :: Value -> Text
jsonText =
  Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode

prop_ghGitParsesIssueAndPrLists :: Bool
prop_ghGitParsesIssueAndPrLists =
  let issuesJson =
        jsonText
          (toJSON [object ["number" .= (42 :: Int), "title" .= ("Fix bug" :: Text)]])
      prsJson =
        jsonText
          ( toJSON
              [ object
                  [ "number" .= (7 :: Int)
                  , "title" .= ("Implement fix" :: Text)
                  , "headRefName" .= ("codex/issue-42" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  , "closingIssuesReferences" .= [object ["number" .= (42 :: Int)]]
                  , "body" .= ("Closes #42" :: Text)
                  , "state" .= ("MERGED" :: Text)
                  ]
              ]
          )
   in parseGhIssueList issuesJson == Right [GhIssue (IssueNumber 42) "Fix bug"]
        && parseGhPrList prsJson == Right [GhPullRequest (PrNumber 7) "Implement fix" (BranchName "codex/issue-42") (Just (CommitSha "abc123")) [IssueNumber 42] (Just "Closes #42") (Just RemotePullRequestMerged)]

prop_ghGitParsesRemoteIssueView :: Bool
prop_ghGitParsesRemoteIssueView =
  let closedIssueJson =
        jsonText
          ( object
              [ "state" .= ("CLOSED" :: Text)
              , "closed" .= True
              , "url" .= ("https://github.com/owner/name/issues/42" :: Text)
              ]
          )
      legacyIssueJson =
        jsonText
          ( object
              [ "state" .= ("CLOSED" :: Text)
              ]
          )
      unknownIssueJson =
        jsonText
          ( object
              [ "state" .= ("TRIAGED" :: Text)
              , "closed" .= False
              ]
          )
   in parseGhIssueView closedIssueJson
        == Right (RemoteIssue RemoteIssueClosed True (Just "https://github.com/owner/name/issues/42"))
        && parseGhIssueView legacyIssueJson == Right (RemoteIssue RemoteIssueClosed True Nothing)
        && parseGhIssueView unknownIssueJson == Right (RemoteIssue (RemoteIssueOther "TRIAGED") False Nothing)
        && renderRemoteIssueState (RemoteIssueOther "triaged") == "triaged"

prop_ghGitParsesRemotePrView :: Bool
prop_ghGitParsesRemotePrView =
  let prJson =
        jsonText
          ( object
              [ "state" .= ("MERGED" :: Text)
              , "url" .= ("https://github.com/owner/name/pull/7" :: Text)
              , "headRefOid" .= ("head-sha" :: Text)
              , "mergeCommit" .= object ["oid" .= ("merge-sha" :: Text)]
              , "mergedAt" .= ("2026-04-21T00:00:00Z" :: Text)
              , "mergeStateStatus" .= ("CLEAN" :: Text)
              , "reviewDecision" .= ("APPROVED" :: Text)
              ]
          )
   in parseGhPrView prJson
        == Right
          RemotePullRequest
            { remotePullRequestState = RemotePullRequestMerged
            , remotePullRequestUrl = Just "https://github.com/owner/name/pull/7"
            , remotePullRequestHeadRefOid = Just (CommitSha "head-sha")
            , remotePullRequestMergeCommit = Just (CommitSha "merge-sha")
            , remotePullRequestMergedAt = Just "2026-04-21T00:00:00Z"
            , remotePullRequestMergeStateStatus = Just "CLEAN"
            , remotePullRequestReviewDecision = Just "APPROVED"
            }

prop_ghGitParsesRemotePrMetadataVariants :: Bool
prop_ghGitParsesRemotePrMetadataVariants =
  let stringMergeJson =
        jsonText
          ( object
              [ "state" .= ("CLOSED" :: Text)
              , "url" .= ("https://github.com/owner/name/pull/7" :: Text)
              , "headRefOid" .= ("head-sha" :: Text)
              , "mergeCommit" .= ("merge-sha" :: Text)
              , "mergedAt" .= ("2026-04-21T00:00:00Z" :: Text)
              , "mergeStateStatus" .= ("BEHIND" :: Text)
              , "reviewDecision" .= Null
              ]
          )
      nullMergeJson =
        jsonText
          ( object
              [ "state" .= ("ARCHIVED" :: Text)
              , "url" .= ("https://github.com/owner/name/pull/8" :: Text)
              , "headRefOid" .= Null
              , "mergeCommit" .= Null
              , "mergedAt" .= Null
              , "mergeStateStatus" .= ("mystery" :: Text)
              , "reviewDecision" .= ("REVIEW_REQUIRED" :: Text)
              ]
          )
      parsedStringMerge = parseGhPrView stringMergeJson
      parsedNullMerge = parseGhPrView nullMergeJson
   in parsedStringMerge
        == Right
          RemotePullRequest
            { remotePullRequestState = RemotePullRequestClosed
            , remotePullRequestUrl = Just "https://github.com/owner/name/pull/7"
            , remotePullRequestHeadRefOid = Just (CommitSha "head-sha")
            , remotePullRequestMergeCommit = Just (CommitSha "merge-sha")
            , remotePullRequestMergedAt = Just "2026-04-21T00:00:00Z"
            , remotePullRequestMergeStateStatus = Just "BEHIND"
            , remotePullRequestReviewDecision = Nothing
            }
        && maybe False remotePullRequestIsMerged (either (const Nothing) Just parsedStringMerge)
        && parsedNullMerge
          == Right
            RemotePullRequest
              { remotePullRequestState = RemotePullRequestOther "ARCHIVED"
              , remotePullRequestUrl = Just "https://github.com/owner/name/pull/8"
              , remotePullRequestHeadRefOid = Nothing
              , remotePullRequestMergeCommit = Nothing
              , remotePullRequestMergedAt = Nothing
              , remotePullRequestMergeStateStatus = Just "mystery"
              , remotePullRequestReviewDecision = Just "REVIEW_REQUIRED"
              }
        && maybe False (not . remotePullRequestIsMerged) (either (const Nothing) Just parsedNullMerge)
        && renderRemotePullRequestState (RemotePullRequestOther "ARCHIVED") == "ARCHIVED"
        && classifyRemotePullRequestMergeState Nothing == RemotePullRequestMergeStateUnavailable
        && classifyRemotePullRequestMergeState (Just "CLEAN") == RemotePullRequestMergeStateClean "CLEAN"
        && classifyRemotePullRequestMergeState (Just "unknown") == RemotePullRequestMergeStateTransient "unknown"
        && classifyRemotePullRequestMergeState (Just "BEHIND") == RemotePullRequestMergeStateFixRequired "BEHIND"
        && classifyRemotePullRequestMergeState (Just "BLOCKED") == RemotePullRequestMergeStateBlocked "BLOCKED"

prop_ghGitParsesPrCreateAndChecks :: Bool
prop_ghGitParsesPrCreateAndChecks =
  let createdJson = jsonText (object ["status" .= ("created" :: Text), "prNumber" .= (7 :: Int)])
      reusedJson = jsonText (object ["status" .= (" ReUsed " :: Text), "prNumber" .= (8 :: Int)])
      rejectedJson = jsonText (object ["status" .= ("queued" :: Text), "prNumber" .= (9 :: Int)])
      checksJson =
        jsonText
          ( toJSON
              [ object
                  [ "name" .= ("ci/test" :: Text)
                  , "state" .= ("SUCCESS" :: Text)
                  , "bucket" .= ("pass" :: Text)
                  ]
              ]
          )
      checksText = "X ci/test\tSUCCESS\t1m\thttps://example.invalid\n"
   in parseGhPrCreateResult createdJson == Right (GhPullRequestCreated (PrNumber 7))
        && parseGhPrCreateResult reusedJson == Right (GhPullRequestReused (PrNumber 8))
        && isLeft (parseGhPrCreateResult rejectedJson)
        && parseGhPrChecks checksJson == Right [GhPullRequestCheck "ci/test" "SUCCESS" (Just "pass")]
        && parseGhPrChecks checksText == Right [GhPullRequestCheck "ci/test" "SUCCESS" Nothing]
        && parseGhPrChecks "no checks reported on the 'codex/example' branch\n" == Right []

prop_ghGitParsesReviewThreadsGraphql :: Bool
prop_ghGitParsesReviewThreadsGraphql =
  let payload =
        jsonText
          ( object
              [ "data"
                  .= object
                    [ "repository"
                        .= object
                          [ "pullRequest"
                              .= object
                                [ "reviewThreads"
                                    .= object
                                      [ "nodes"
                                          .= [ object
                                                [ "id" .= ("thread-unresolved" :: Text)
                                                , "isResolved" .= False
                                                , "isOutdated" .= False
                                                , "path" .= ("src/File.hs" :: Text)
                                                , "line" .= (12 :: Int)
                                                , "startLine" .= (10 :: Int)
                                                , "comments"
                                                    .= object
                                                      [ "nodes"
                                                          .= [ object
                                                                [ "id" .= ("comment-1" :: Text)
                                                                , "url" .= ("https://github.com/soulomoon/mlf2/pull/1#discussion_r1" :: Text)
                                                                , "body" .= ("please fix" :: Text)
                                                                , "author" .= object ["login" .= ("reviewer" :: Text)]
                                                                ]
                                                             , object
                                                                [ "id" .= ("comment-2" :: Text)
                                                                , "author" .= Null
                                                                ]
                                                              ]
                                                         ]
                                                ]
                                             , object
                                                [ "id" .= ("thread-resolved" :: Text)
                                                , "isResolved" .= True
                                                , "isOutdated" .= False
                                                , "comments" .= object ["nodes" .= ([] :: [Value])]
                                                ]
                                             ]
                                      ]
                                ]
                          ]
                    ]
              ]
          )
   in case parseGhReviewThreads payload of
        Right report ->
          fmap reviewThreadId report.unresolvedReviewThreads == [ReviewThreadId "thread-unresolved"]
            && length report.reviewThreads == 2
            && maybe False ((== Just "reviewer") . reviewCommentAuthorLogin) (listToMaybe report.reviewThreads >>= listToMaybe . reviewThreadComments)
            && maybe False ((== Just "https://github.com/soulomoon/mlf2/pull/1#discussion_r1") . reviewCommentUrl) (listToMaybe report.reviewThreads >>= listToMaybe . reviewThreadComments)
            && maybe False ((== Just "https://github.com/soulomoon/mlf2/pull/1#discussion_r1") . reviewThreadUrl) (listToMaybe report.reviewThreads)
        Left _ -> False

prop_ghGitParsesGitOutputs :: Bool
prop_ghGitParsesGitOutputs =
  parseGitBranch "  codex/example\n" == Just (BranchName "codex/example")
    && parseGitSha " abc123\n" == Just (CommitSha "abc123")
    && parseLsRemoteBranch "abc123\trefs/heads/codex/example\n" == Just (CommitSha "abc123")
    && parseGitBranch "\n" == Nothing
    && parseLsRemoteBranch "\n" == Nothing
