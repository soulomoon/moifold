{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

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

analyzeItem :: WatcherSummary -> [Problem]
analyzeItem summary =
  concat
    [ [problem (blockedSeverity summary) summary.label ("blocked: " <> fromMaybe "no reason recorded" summary.blockedReason) Nothing | summary.blocked]
    , [problem "error" summary.label "config failed to load" summary.configLoadError | isJust summary.configLoadError]
    , eventReplayProblems summary
    , analyzePlanning summary
    , analyzeImplement summary
    , analyzePrReview summary
    ]

analyzePlanning :: WatcherSummary -> [Problem]
analyzePlanning summary
  | summary.kind /= IssuePlanningKind = []
  | otherwise =
      [problem "error" summary.label "missing planner threadId" (Just "create a Codex planner thread, then run run-issue-planning with --planner-thread-id") | summary.threadId == Nothing]
        <> [problem "error" summary.label "maxParallel is less than 1" Nothing | maybe False (< 1) summary.maxParallel]
        <> [ problem "warn" summary.label ("planner status is " <> planningStatusLabel plannerStatus <> " but daemon is not running") Nothing
           | isNothing summary.configLoadError
           , not summary.blocked
           , planningStatusRequiresDaemon summary.eventReplay.phase plannerStatus
           , not summary.pid.running
           ]
 where
  plannerStatus = lookupStateText ["plannerState", "status"] summary.states

analyzeImplement :: WatcherSummary -> [Problem]
analyzeImplement summary
  | summary.kind /= IssueImplementKind = []
  | otherwise =
      [problem "error" summary.label "missing worker threadId" (Just "create a Codex worker thread before run-issue-implement --execute") | summary.threadId == Nothing]
        <> workdirProblems summary
        <> [problem "warn" summary.label "workdir has uncommitted changes while daemon is stopped" Nothing | warnIssueImplementDirtyWorkdir summary.workdir.dirty summary.pid.running]
        <> [problem "warn" summary.label ("git push dry-run failed: " <> commandText summary.gitPushDryRun) Nothing | shouldWarnGitPush summary.gitPushDryRun]
        <> [problem "warn" summary.label ("issue status is " <> status <> " but daemon is not running") Nothing | Just status <- [summary.issueStatus], issueStatusRequiresDaemon status, not summary.pid.running]
        <> appServerThreadProblems summary.label "worker" summary.workerThreadInspection

analyzePrReview :: WatcherSummary -> [Problem]
analyzePrReview summary
  | summary.kind /= PrReviewKind = []
  | otherwise =
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

eventReplayProblems :: WatcherSummary -> [Problem]
eventReplayProblems summary =
  [problem "error" summary.label ("events.jsonl failed Haskell replay: " <> fromMaybe "unknown" summary.eventReplay.reason) Nothing | not summary.eventReplay.skipped && not summary.eventReplay.ok]

appServerThreadProblems :: Text -> Text -> AppServerThreadReport -> [Problem]
appServerThreadProblems label role report =
  [ problem "warn" label ("app-server " <> role <> " thread inspection failed: " <> fromMaybe "unknown" report.reason) Nothing
  | not report.skipped
  , not report.ok
  ]

prReviewTerminal :: WatcherSummary -> Bool
prReviewTerminal summary =
  not (prReviewRequiresDaemon summary.remotePr.merged summary.eventReplay.phase)

planningStatusLabel :: Maybe Text -> Text
planningStatusLabel = fromMaybe "unknown"

workdirProblems :: WatcherSummary -> [Problem]
workdirProblems summary =
  [problem "error" summary.label ("workdir missing: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], not summary.workdir.exists]
    <> [problem "error" summary.label ("workdir is not a git checkout: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], summary.workdir.exists, not summary.workdir.isGitCheckout]

analyzeCrossItemRules :: [WatcherSummary] -> [Problem]
analyzeCrossItemRules summaries =
  duplicateActiveImplementerProblems summaries
    <> duplicateRunningPrWatcherProblems summaries
    <> duplicateWorkdirProblems summaries
    <> maxParallelProblems summaries

duplicateActiveImplementerProblems :: [WatcherSummary] -> [Problem]
duplicateActiveImplementerProblems summaries =
  [ problem "error" key ("multiple active implementers own the same issue: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy activeIssueKey summaries
  ]
 where
  activeIssueKey summary
    | isActiveImplementer summary = (\repo issue -> repo <> "#" <> Text.pack (show issue)) <$> summary.repoFullName <*> summary.issueNumber
    | otherwise = Nothing

duplicateRunningPrWatcherProblems :: [WatcherSummary] -> [Problem]
duplicateRunningPrWatcherProblems summaries =
  [ problem "error" key ("multiple running review watchers own the same PR: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy runningPrKey summaries
  ]
 where
  runningPrKey summary
    | summary.kind == PrReviewKind && summary.pid.running = (\repo pr -> repo <> "#" <> Text.pack (show pr)) <$> summary.repoFullName <*> summary.prNumber
    | otherwise = Nothing

duplicateWorkdirProblems :: [WatcherSummary] -> [Problem]
duplicateWorkdirProblems summaries =
  [ problem "warn" workdir' ("workdir is shared by multiple configs: " <> Text.intercalate ", " labels) Nothing
  | (workdir', labels) <- duplicateLabelsBy liveWorkdirKey summaries
  ]

liveWorkdirKey :: WatcherSummary -> Maybe Text
liveWorkdirKey summary
  | isTerminalWorkdirOwner summary = Nothing
  | otherwise = Text.pack <$> summary.workdirPath

isTerminalWorkdirOwner :: WatcherSummary -> Bool
isTerminalWorkdirOwner summary =
  case summary.kind of
    IssuePlanningKind -> summary.eventReplay.phase == Just "Complete"
    IssueImplementKind -> maybe False (`elem` terminalIssueStatuses) summary.issueStatus
    PrReviewKind -> summary.remotePr.merged

warnIssueImplementDirtyWorkdir :: Bool -> Bool -> Bool
warnIssueImplementDirtyWorkdir dirty daemonRunning =
  dirty && not daemonRunning

warnPrReviewDirtyWorkdir :: Bool -> Bool -> Bool -> Bool
warnPrReviewDirtyWorkdir dirty daemonRunning prMerged =
  dirty && not daemonRunning && not prMerged

maxParallelProblems :: [WatcherSummary] -> [Problem]
maxParallelProblems summaries =
  [ problem "warn" planner.label ("active implementers (" <> Text.pack (show activeCount) <> ") exceed maxParallel (" <> Text.pack (show maxParallel') <> ")") Nothing
  | planner <- summaries
  , planner.kind == IssuePlanningKind
  , Just repo <- [planner.repoFullName]
  , let maxParallel' = fromMaybe 8 planner.maxParallel
  , let activeCount = length [() | summary <- summaries, summary.repoFullName == Just repo, isActiveImplementer summary]
  , activeCount > maxParallel'
  ]

duplicateLabelsBy :: Ord key => (WatcherSummary -> Maybe key) -> [WatcherSummary] -> [(key, [Text])]
duplicateLabelsBy keyOf summaries =
  [ (key, labels)
  | (key, labels) <- Map.toList grouped
  , length labels > 1
  ]
 where
  grouped =
    Map.fromListWith
      (<>)
      [(key, [summary.label]) | summary <- summaries, Just key <- [keyOf summary]]

isActiveImplementer :: WatcherSummary -> Bool
isActiveImplementer summary =
  summary.kind == IssueImplementKind
    && (summary.pid.running || maybe False (`elem` activeIssueStatuses) summary.issueStatus)

terminalIssueStatuses :: [Text]
terminalIssueStatuses = ["complete"]

blockedSeverity :: WatcherSummary -> Text
blockedSeverity summary
  | summary.kind == PrReviewKind && summary.remotePr.merged = "warn"
  | otherwise = "error"

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

summaryObject :: [WatcherSummary] -> Value
summaryObject summaries =
  object
    [ "totalConfigs" .= length summaries
    , "planners" .= countKind IssuePlanningKind
    , "implementers" .= countKind IssueImplementKind
    , "reviewWatchers" .= countKind PrReviewKind
    , "runningDaemons" .= length [() | summary <- summaries, summary.pid.running]
    , "blockedConfigs" .= length [() | summary <- summaries, summary.blocked]
    , "activeImplementers" .= length [() | summary <- summaries, isActiveImplementer summary]
    ]
 where
  countKind kind' = length [() | summary <- summaries, summary.kind == kind']

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

itemLabel :: WatcherKind -> Maybe Text -> Maybe Int -> Maybe Int -> Text
itemLabel kind repo issue pr =
  case kind of
    IssuePlanningKind -> fromMaybe "unknown repo" repo <> " planner"
    IssueImplementKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) issue <> " implementer"
    PrReviewKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) pr <> " reviewer"

lookupStateText :: [Text] -> Value -> Maybe Text
lookupStateText = textAtPath

lookupStateBool :: [Text] -> Value -> Maybe Bool
lookupStateBool = boolAtPath
