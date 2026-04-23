{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.WatcherLiveness
  ( activeIssueStatuses
  , activePlannerStatuses
  , issueStatusRequiresDaemon
  , planningStatusRequiresDaemon
  , prReviewRequiresDaemon
  ) where

import Data.Text (Text)

planningStatusRequiresDaemon :: Maybe Text -> Maybe Text -> Bool
planningStatusRequiresDaemon replayPhase maybePlannerStatus =
  replayPhase /= Just "Complete" && maybe True (`elem` activePlannerStatuses) maybePlannerStatus

activePlannerStatuses :: [Text]
activePlannerStatuses = ["ready", "active", "waiting_ready_issues"]

issueStatusRequiresDaemon :: Text -> Bool
issueStatusRequiresDaemon status =
  status `elem` activeIssueStatuses

activeIssueStatuses :: [Text]
activeIssueStatuses = ["preparing_pr", "ready_to_plan", "planning", "plan_ready", "in_progress", "incomplete", "waiting_pr_merge", "waiting_issue_close"]

prReviewRequiresDaemon :: Bool -> Maybe Text -> Bool
prReviewRequiresDaemon remoteMerged replayPhase =
  not remoteMerged && replayPhase /= Just "Complete"
