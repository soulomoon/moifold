{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module GhGitSpec
  ( prop_ghGitParsesGitOutputs
  , prop_ghGitParsesIssueAndPrLists
  , prop_ghGitParsesPrCreateAndChecks
  , prop_ghGitParsesRemoteIssueView
  , prop_ghGitParsesRemotePrView
  , prop_ghGitParsesReviewThreadsGraphql
  ) where

import CodexWatcher.GhGit
import CodexWatcher.Types
import Data.Aeson (Value (..), encode, object, toJSON, (.=))
import Data.ByteString.Lazy qualified as LazyByteString
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
                  ]
              ]
          )
   in parseGhIssueList issuesJson == Right [GhIssue (IssueNumber 42) "Fix bug"]
        && parseGhPrList prsJson == Right [GhPullRequest (PrNumber 7) "Implement fix" (BranchName "codex/issue-42") (Just (CommitSha "abc123"))]

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
   in parseGhIssueView closedIssueJson
        == Right (RemoteIssue "CLOSED" True (Just "https://github.com/owner/name/issues/42"))
        && parseGhIssueView legacyIssueJson == Right (RemoteIssue "CLOSED" True Nothing)

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
              ]
          )
   in parseGhPrView prJson
        == Right
          RemotePullRequest
            { remotePullRequestState = "MERGED"
            , remotePullRequestUrl = Just "https://github.com/owner/name/pull/7"
            , remotePullRequestHeadRefOid = Just (CommitSha "head-sha")
            , remotePullRequestMergeCommit = Just (CommitSha "merge-sha")
            , remotePullRequestMergedAt = Just "2026-04-21T00:00:00Z"
            , remotePullRequestMergeStateStatus = Just "CLEAN"
            }

prop_ghGitParsesPrCreateAndChecks :: Bool
prop_ghGitParsesPrCreateAndChecks =
  let createdJson = jsonText (object ["status" .= ("created" :: Text), "prNumber" .= (7 :: Int)])
      reusedJson = jsonText (object ["status" .= ("reused" :: Text), "prNumber" .= (8 :: Int)])
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
   in parseGhPrCreateResult createdJson == Right (GhPullRequestCreated (PrNumber 7))
        && parseGhPrCreateResult reusedJson == Right (GhPullRequestReused (PrNumber 8))
        && parseGhPrChecks checksJson == Right [GhPullRequestCheck "ci/test" "SUCCESS" (Just "pass")]

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
                                                                , "body" .= ("please fix" :: Text)
                                                                , "author" .= object ["login" .= ("reviewer" :: Text)]
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
        Left _ -> False

prop_ghGitParsesGitOutputs :: Bool
prop_ghGitParsesGitOutputs =
  parseGitBranch "codex/example\n" == Just (BranchName "codex/example")
    && parseGitSha "abc123\n" == Just (CommitSha "abc123")
    && parseLsRemoteBranch "abc123\trefs/heads/codex/example\n" == Just (CommitSha "abc123")
    && parseGitBranch "\n" == Nothing
