{-# LANGUAGE OverloadedStrings #-}

module HealthcheckSpec
  ( prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
  , prop_healthcheckDaemonRequiredStatuses
  ) where

import CodexWatcher.Healthcheck

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
