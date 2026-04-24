{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module CodexWatcher.Healthcheck.Analysis
  ( analyzeCrossItemRules
  , analyzeItem
  , commandProblems
  , itemLabel
  , logicReview
  , lookupStateBool
  , lookupStateText
  , problem
  , statusSeverity
  , summaryObject
  , warnIssueImplementDirtyWorkdir
  , warnPrReviewDirtyWorkdir
  ) where

import CodexWatcher.Healthcheck.Types
import CodexWatcher.JsonPath (boolAtPath, textAtPath)
import CodexWatcher.Runtime (CommandReport (..), commandText)
import CodexWatcher.WatcherLiveness
import Data.Aeson (Value (..), object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text

analyzeItem :: SomeWatcherSummary -> [Problem]
analyzeItem (SomeWatcherSummary kind summary) =
  commonItemProblems kind summary
    <> case kind of
      SIssuePlanningKind -> analyzePlanning summary
      SIssueImplementKind -> analyzeImplement summary
      SPrReviewKind -> analyzePrReview summary

commonItemProblems :: SWatcherKind kind -> WatcherSummary kind -> [Problem]
commonItemProblems kind summary =
  [problem (blockedSeverity kind summary) summary.label ("blocked: " <> fromMaybe "no reason recorded" summary.blockedReason) Nothing | summary.blocked]
    <> [problem "error" summary.label "config failed to load" summary.configLoadError | isJust summary.configLoadError]
    <> eventReplayProblems summary

analyzePlanning :: WatcherSummary 'IssuePlanningKind -> [Problem]
analyzePlanning summary =
  [problem "error" summary.label "maxParallel is less than 1" Nothing | maybe False (< 1) summary.maxParallel]
    <> [ problem "warn" summary.label ("planner status is " <> planningStatusLabel plannerStatus <> " but daemon is not running") Nothing
       | isNothing summary.configLoadError
       , not summary.blocked
       , planningStatusRequiresDaemon summary.eventReplay.phase plannerStatus
       , not summary.pid.running
       ]
 where
  plannerStatus = lookupStateText ["plannerState", "status"] summary.states

analyzeImplement :: WatcherSummary 'IssueImplementKind -> [Problem]
analyzeImplement summary =
  [problem "error" summary.label "missing worker threadId" (Just "create a Codex worker thread before run-issue-implement --execute") | summary.threadId == Nothing]
    <> workdirProblems summary
    <> [problem "warn" summary.label "workdir has uncommitted changes while daemon is stopped" Nothing | warnIssueImplementDirtyWorkdir summary.workdir.dirty summary.pid.running]
    <> [problem "warn" summary.label ("git push dry-run failed: " <> commandText summary.gitPushDryRun) Nothing | shouldWarnGitPush summary.gitPushDryRun]
    <> [problem "warn" summary.label ("issue status is " <> status <> " but daemon is not running") Nothing | Just status <- [summary.issueStatus], issueStatusRequiresDaemon status, not summary.pid.running]
    <> appServerThreadProblems summary.label "worker" summary.workerThreadInspection

analyzePrReview :: WatcherSummary 'PrReviewKind -> [Problem]
analyzePrReview summary =
  [problem "error" summary.label "missing PR worker threadId" (Just "create a Codex worker thread before run-pr-review --execute") | summary.threadId == Nothing]
    <> [problem "error" summary.label "reviewWhenClean is enabled but reviewerThreadId is missing" Nothing | summary.reviewWhenClean /= Just False && summary.reviewerThreadId == Nothing]
    <> workdirProblems summary
    <> [problem "warn" summary.label "workdir has uncommitted changes while daemon is stopped" Nothing | warnPrReviewDirtyWorkdir summary.workdir.dirty summary.pid.running summary.remotePr.merged]
    <> [problem "warn" summary.label "local HEAD differs from remote branch head" Nothing | summary.workdir.localDiffersFromRemote]
    <> [problem "warn" summary.label ("git push dry-run failed: " <> commandText summary.gitPushDryRun) Nothing | shouldWarnGitPush summary.gitPushDryRun]
    <> [problem "warn" summary.label ("cannot read remote PR state: " <> fromMaybe "unknown" summary.remotePr.errorMessage) Nothing | not summary.remotePr.skipped && not summary.remotePr.ok]
    <> [problem "warn" summary.label "PR review watcher is not terminal but daemon is not running" Nothing | prReviewRequiresDaemon summary.remotePr.merged summary.eventReplay.phase, not summary.pid.running]
    <> [problem' | not (prReviewTerminal summary), problem' <- appServerThreadProblems summary.label "worker" summary.workerThreadInspection]
    <> [problem' | not (prReviewTerminal summary), problem' <- appServerThreadProblems summary.label "reviewer" summary.reviewerThreadInspection]

eventReplayProblems :: WatcherSummary kind -> [Problem]
eventReplayProblems summary =
  [problem "error" summary.label ("events.jsonl failed Haskell replay: " <> fromMaybe "unknown" summary.eventReplay.reason) Nothing | not summary.eventReplay.skipped && not summary.eventReplay.ok]

appServerThreadProblems :: Text -> Text -> AppServerThreadReport -> [Problem]
appServerThreadProblems label role report =
  [ problem "warn" label ("app-server " <> role <> " thread inspection failed: " <> fromMaybe "unknown" report.reason) Nothing
  | not report.skipped
  , not report.ok
  ]

prReviewTerminal :: WatcherSummary 'PrReviewKind -> Bool
prReviewTerminal summary =
  not (prReviewRequiresDaemon summary.remotePr.merged summary.eventReplay.phase)

planningStatusLabel :: Maybe Text -> Text
planningStatusLabel = fromMaybe "unknown"

workdirProblems :: WatcherSummary kind -> [Problem]
workdirProblems summary =
  [problem "error" summary.label ("workdir missing: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], not summary.workdir.exists]
    <> [problem "error" summary.label ("workdir is not a git checkout: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], summary.workdir.exists, not summary.workdir.isGitCheckout]

analyzeCrossItemRules :: [SomeWatcherSummary] -> [Problem]
analyzeCrossItemRules summaries =
  duplicateActiveImplementerProblems summaries
    <> duplicateRunningPrWatcherProblems summaries
    <> duplicateWorkdirProblems summaries
    <> maxParallelProblems summaries

duplicateActiveImplementerProblems :: [SomeWatcherSummary] -> [Problem]
duplicateActiveImplementerProblems summaries =
  [ problem "error" key ("multiple active implementers own the same issue: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy activeIssueKey summaries
  ]
 where
  activeIssueKey :: SomeWatcherSummary -> Maybe Text
  activeIssueKey summary
    | isActiveImplementer summary = (\repo issue -> repo <> "#" <> Text.pack (show issue)) <$> someSummaryRepo summary <*> someSummaryIssue summary
    | otherwise = Nothing

duplicateRunningPrWatcherProblems :: [SomeWatcherSummary] -> [Problem]
duplicateRunningPrWatcherProblems summaries =
  [ problem "error" key ("multiple running review watchers own the same PR: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy runningPrKey summaries
  ]
 where
  runningPrKey :: SomeWatcherSummary -> Maybe Text
  runningPrKey (SomeWatcherSummary SPrReviewKind summary)
    | summary.pid.running = (\repo pr -> repo <> "#" <> Text.pack (show pr)) <$> summary.repoFullName <*> summary.prNumber
  runningPrKey _ = Nothing

duplicateWorkdirProblems :: [SomeWatcherSummary] -> [Problem]
duplicateWorkdirProblems summaries =
  [ problem "warn" workdir' ("workdir is shared by multiple configs: " <> Text.intercalate ", " labels) Nothing
  | (workdir', labels) <- duplicateLabelsBy liveWorkdirKey summaries
  ]

liveWorkdirKey :: SomeWatcherSummary -> Maybe Text
liveWorkdirKey summary
  | isTerminalWorkdirOwner summary = Nothing
  | otherwise = Text.pack <$> someSummaryWorkdirPath summary

isTerminalWorkdirOwner :: SomeWatcherSummary -> Bool
isTerminalWorkdirOwner = \case
  SomeWatcherSummary SIssuePlanningKind summary -> summary.eventReplay.phase == Just "Complete"
  SomeWatcherSummary SIssueImplementKind summary -> maybe False (`elem` terminalIssueStatuses) summary.issueStatus
  SomeWatcherSummary SPrReviewKind summary -> summary.remotePr.merged

someSummaryLabel :: SomeWatcherSummary -> Text
someSummaryLabel =
  someSummary \summary -> summary.label

someSummaryRepo :: SomeWatcherSummary -> Maybe Text
someSummaryRepo =
  someSummary \summary -> summary.repoFullName

someSummaryIssue :: SomeWatcherSummary -> Maybe Int
someSummaryIssue =
  someSummary \summary -> summary.issueNumber

someSummaryWorkdirPath :: SomeWatcherSummary -> Maybe FilePath
someSummaryWorkdirPath =
  someSummary \summary -> summary.workdirPath

someSummaryPidRunning :: SomeWatcherSummary -> Bool
someSummaryPidRunning =
  someSummary \summary -> summary.pid.running

someSummaryBlocked :: SomeWatcherSummary -> Bool
someSummaryBlocked =
  someSummary \summary -> summary.blocked

someSummary :: (forall kind. WatcherSummary kind -> result) -> SomeWatcherSummary -> result
someSummary project summary =
  withSomeWatcher summary \_ summary' -> project summary'

warnIssueImplementDirtyWorkdir :: Bool -> Bool -> Bool
warnIssueImplementDirtyWorkdir dirty daemonRunning =
  dirty && not daemonRunning

warnPrReviewDirtyWorkdir :: Bool -> Bool -> Bool -> Bool
warnPrReviewDirtyWorkdir dirty daemonRunning prMerged =
  dirty && not daemonRunning && not prMerged

maxParallelProblems :: [SomeWatcherSummary] -> [Problem]
maxParallelProblems summaries =
  [ problem "warn" planner.label ("active implementers (" <> Text.pack (show activeCount) <> ") exceed maxParallel (" <> Text.pack (show maxParallel') <> ")") Nothing
  | SomeWatcherSummary SIssuePlanningKind planner <- summaries
  , Just repo <- [planner.repoFullName]
  , let maxParallel' = fromMaybe 8 planner.maxParallel
  , let activeCount = length [() | summary <- summaries, someSummaryRepo summary == Just repo, isActiveImplementer summary]
  , activeCount > maxParallel'
  ]

duplicateLabelsBy :: Ord key => (SomeWatcherSummary -> Maybe key) -> [SomeWatcherSummary] -> [(key, [Text])]
duplicateLabelsBy keyOf summaries =
  [ (key, labels)
  | (key, labels) <- Map.toList grouped
  , length labels > 1
  ]
 where
  grouped =
    Map.fromListWith
      (<>)
      [(key, [someSummaryLabel summary]) | summary <- summaries, Just key <- [keyOf summary]]

isActiveImplementer :: SomeWatcherSummary -> Bool
isActiveImplementer (SomeWatcherSummary SIssueImplementKind summary) =
  summary.pid.running || maybe False (`elem` activeIssueStatuses) summary.issueStatus
isActiveImplementer _ =
  False

terminalIssueStatuses :: [Text]
terminalIssueStatuses = ["complete"]

blockedSeverity :: SWatcherKind kind -> WatcherSummary kind -> Text
blockedSeverity SPrReviewKind summary
  | summary.remotePr.merged = "warn"
blockedSeverity _ _ =
  "error"

shouldWarnGitPush :: CommandReport -> Bool
shouldWarnGitPush report =
  not report.ok && report.errorMessage /= Just "missing branch or git checkout" && report.errorMessage /= Just "not a git checkout"

commandProblems :: Value -> CommandReport -> [Problem]
commandProblems commands ghAuth =
  [problem "error" "environment" "git is not installed" Nothing | not (commandOk "git")]
    <> [problem "error" "environment" "GitHub CLI gh is not installed" Nothing | not (commandOk "gh")]
    <> [problem "error" "environment" ("gh auth status failed: " <> commandText ghAuth) Nothing | not ghAuth.ok]
 where
  commandOk key =
    case commands of
      Object object' ->
        case KeyMap.lookup (Key.fromString key) object' of
          Just (Object commandObject) ->
            KeyMap.lookup "ok" commandObject == Just (Bool True)
          _ -> False
      _ -> False

statusSeverity :: [Problem] -> Text
statusSeverity problems
  | any ((== "error") . (.severity)) problems = "fail"
  | any ((== "warn") . (.severity)) problems = "warn"
  | otherwise = "ok"

summaryObject :: [SomeWatcherSummary] -> Value
summaryObject summaries =
  object
    [ "totalConfigs" .= length summaries
    , "planners" .= countKind IssuePlanningKind
    , "implementers" .= countKind IssueImplementKind
    , "reviewWatchers" .= countKind PrReviewKind
    , "runningDaemons" .= length [() | summary <- summaries, someSummaryPidRunning summary]
    , "blockedConfigs" .= length [() | summary <- summaries, someSummaryBlocked summary]
    , "activeImplementers" .= length [() | summary <- summaries, isActiveImplementer summary]
    ]
 where
  countKind kind' = length [() | summary <- summaries, someSummaryKind summary == kind']

logicReview :: Value
logicReview =
  object
    [ "checkedRules"
        .= [ "one active implementer per issue" :: Text
           , "one running review watcher per PR"
           , "planner maxParallel not exceeded"
           , "review/implement workdirs exist, are git checkouts, and are not unexpectedly dirty while stopped"
           , "gh-authenticated git push dry-run works for workdirs with branches"
           , "watcher events.jsonl can replay through the Haskell lifecycle model when present"
           , "non-terminal planning, implement, and PR review watchers have a running daemon pid"
           , "configured app-server threads can be read when an app-server endpoint is provided"
           , "runtime-owner lease is surfaced for execute ownership visibility when present"
           , "blocked states are surfaced instead of retried forever"
           ]
    , "notes"
        .= [ "This Haskell healthcheck is read-only." :: Text
           , "It does not mutate GitHub, app-server threads, or local checkouts."
           , "App-server thread inspection is skipped unless --app-server-host and --app-server-port are provided."
           ]
    ]

problem :: Text -> Text -> Text -> Maybe Text -> Problem
problem severity component message recommendation =
  Problem {severity, component, message, recommendation}

itemLabel :: SWatcherKind kind -> Maybe Text -> Maybe Int -> Maybe Int -> Text
itemLabel kind repo issue pr =
  case kind of
    SIssuePlanningKind -> fromMaybe "unknown repo" repo <> " planner"
    SIssueImplementKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) issue <> " implementer"
    SPrReviewKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) pr <> " reviewer"

lookupStateText :: [Text] -> Value -> Maybe Text
lookupStateText = textAtPath

lookupStateBool :: [Text] -> Value -> Maybe Bool
lookupStateBool = boolAtPath
