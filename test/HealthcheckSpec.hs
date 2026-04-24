{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module HealthcheckSpec
  ( prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
  , prop_healthcheckDaemonRequiredStatuses
  , prop_healthcheckSingletonDomains
  , prop_healthcheckSummaryJsonKeepsKindField
  , prop_healthcheckTypedAnalyzerDispatch
  ) where

import CodexWatcher.Healthcheck
import CodexWatcher.Healthcheck.Analysis (analyzeItem)
import CodexWatcher.Healthcheck.Types
import CodexWatcher.Runtime.Process (skippedCommand)
import CodexWatcher.Core.Kinds (Domain (..))
import Data.Aeson (Value (..), toJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)

prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork :: Bool
prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork =
  warnIssueImplementDirtyWorkdir True False
    && not (warnIssueImplementDirtyWorkdir True True)
    && not (warnIssueImplementDirtyWorkdir False False)
    && warnPrReviewDirtyWorkdir True False False
    && not (warnPrReviewDirtyWorkdir True True False)
    && not (warnPrReviewDirtyWorkdir True False True)

prop_healthcheckDaemonRequiredStatuses :: Bool
prop_healthcheckDaemonRequiredStatuses =
  planningStatusRequiresDaemon (Just "Initialized") (Just "ready")
    && planningStatusRequiresDaemon (Just "Initialized") (Just "waiting_ready_issues")
    && not (planningStatusRequiresDaemon (Just "Complete") (Just "ready"))
    && not (planningStatusRequiresDaemon (Just "Initialized") (Just "complete"))
    && issueStatusRequiresDaemon "waiting_pr_merge"
    && issueStatusRequiresDaemon "ready_to_plan"
    && issueStatusRequiresDaemon "planning"
    && issueStatusRequiresDaemon "plan_ready"
    && issueStatusRequiresDaemon "in_progress"
    && not (issueStatusRequiresDaemon "complete")
    && prReviewRequiresDaemon False (Just "Reviewing")
    && not (prReviewRequiresDaemon True (Just "Reviewing"))
    && not (prReviewRequiresDaemon False (Just "Complete"))

prop_healthcheckSingletonDomains :: Bool
prop_healthcheckSingletonDomains =
  watcherDomainValue SIssuePlanning == IssuePlanning
    && watcherDomainValue SIssueImplement == IssueImplement
    && watcherDomainValue SPrReview == PrReview

prop_healthcheckSummaryJsonKeepsKindField :: Bool
prop_healthcheckSummaryJsonKeepsKindField =
  kindField (SomeWatcherSummary SIssuePlanning sampleSummary) == Just (String "issue-planning")
    && kindField (SomeWatcherSummary SIssueImplement sampleSummary) == Just (String "issue-implement")
    && kindField (SomeWatcherSummary SPrReview sampleSummary) == Just (String "pr-review")

prop_healthcheckTypedAnalyzerDispatch :: Bool
prop_healthcheckTypedAnalyzerDispatch =
  containsMessage "maxParallel is less than 1" planningProblems
    && not (containsMessage "missing worker threadId" planningProblems)
    && containsMessage "missing worker threadId" implementProblems
    && not (containsMessage "reviewWhenClean is enabled but reviewerThreadId is missing" implementProblems)
    && containsMessage "missing PR worker threadId" reviewProblems
    && containsMessage "reviewWhenClean is enabled but reviewerThreadId is missing" reviewProblems
 where
  planningProblems =
    analyzeItem (SomeWatcherSummary SIssuePlanning planningSummary)
  implementProblems =
    analyzeItem (SomeWatcherSummary SIssueImplement implementSummary)
  reviewProblems =
    analyzeItem (SomeWatcherSummary SPrReview reviewSummary)
  planningSummary :: WatcherSummary 'IssuePlanning
  planningSummary = sampleSummaryWith Nothing (Just "reviewer-thread") (Just False) (Just 0)
  implementSummary :: WatcherSummary 'IssueImplement
  implementSummary = sampleSummaryWith Nothing Nothing (Just False) (Just 8)
  reviewSummary :: WatcherSummary 'PrReview
  reviewSummary = sampleSummaryWith Nothing Nothing (Just True) (Just 8)

kindField :: SomeWatcherSummary -> Maybe Value
kindField summary =
  case toJSON summary of
    Object object' -> KeyMap.lookup (Key.fromString "kind") object'
    _ -> Nothing

containsMessage :: Text -> [Problem] -> Bool
containsMessage message' =
  any ((== message') . (.message))

sampleSummary :: WatcherSummary kind
sampleSummary =
  sampleSummaryWith (Just "worker-thread") (Just "reviewer-thread") (Just False) (Just 8)

sampleSummaryWith :: Maybe Text -> Maybe Text -> Maybe Bool -> Maybe Int -> WatcherSummary kind
sampleSummaryWith threadId' reviewerThreadId' reviewWhenClean' maxParallel' =
  WatcherSummary
    { label = "owner/repo#1"
    , configPath = "config.json"
    , configLoadError = Nothing
    , repoFullName = Just "owner/repo"
    , issueNumber = Just 1
    , prNumber = Just 2
    , branch = Just "main"
    , workdirPath = Just "/tmp/workdir"
    , threadId = threadId'
    , reviewerThreadId = reviewerThreadId'
    , reviewWhenClean = reviewWhenClean'
    , maxParallel = maxParallel'
    , runtimeOwner = Nothing
    , pid = PidReport "watcher.pid" Nothing False
    , issueStatus = Nothing
    , blocked = False
    , blockedReason = Nothing
    , workdir =
        WorkdirReport
          { skipped = True
          , reason = Just "test"
          , path = Nothing
          , exists = False
          , isGitCheckout = False
          , currentBranch = Nothing
          , headSha = Nothing
          , remoteHeadSha = Nothing
          , localDiffersFromRemote = False
          , dirty = False
          , dirtyStatus = Nothing
          }
    , gitPushDryRun = skippedCommand "test"
    , remotePr = RemotePrReport {skipped = True, ok = False, errorMessage = Just "test", raw = Null, merged = False}
    , eventReplay =
        EventReplayReport
          { skipped = True
          , ok = False
          , reason = Just "test"
          , eventsPath = Nothing
          , domain = Nothing
          , phase = Just "Complete"
          , eventCount = Nothing
          , effectBatchCount = Nothing
          }
    , workerThreadInspection = sampleThreadReport
    , reviewerThreadInspection = sampleThreadReport
    , states = Null
    }

sampleThreadReport :: AppServerThreadReport
sampleThreadReport =
  AppServerThreadReport
    { skipped = True
    , ok = True
    , threadId = Nothing
    , reason = Just "test"
    , turnCount = Nothing
    , latestTurnId = Nothing
    , latestTurnStatus = Nothing
    }
