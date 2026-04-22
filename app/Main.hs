{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.Daemon
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.GoldenReplay
import CodexWatcher.Healthcheck
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Migration
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.Runtime
import CodexWatcher.Snapshot
import CodexWatcher.Types
import Data.Aeson (Value (..))
import Data.Text qualified as Text
import System.Environment (getArgs)
import System.Exit (die)
import Text.Read (readMaybe)

main :: IO ()
main =
  getArgs >>= \case
    ["replay", dir] -> replayAny dir
    ["replay-pr-review", dir] -> replayPrReview dir
    ["replay-issue-implement", dir] -> replayIssueImplement dir
    ["replay-events", path] -> replayEvents path
    "healthcheck" : rest -> runHealthcheck (parseHealthcheckOptions rest)
    "mark-runtime-owner" : rest -> markRuntimeOwner rest
    "observe-once" : rest -> observeOnce rest
    [] -> do
      putStrLn "codex-watcher-hs"
      putStrLn "usage: codex-watcher-hs replay <node-watcher-state-dir>"
      putStrLn "       codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"
      putStrLn "       codex-watcher-hs replay-issue-implement <node-issue-implement-state-dir>"
      putStrLn "       codex-watcher-hs replay-events <events.jsonl>"
      putStrLn "       codex-watcher-hs healthcheck [--state-root <path>] [--repo owner/name]"
      putStrLn "       codex-watcher-hs mark-runtime-owner --state-dir <path> --owner node|haskell"
      putStrLn "       codex-watcher-hs observe-once --events <events.jsonl> --state-dir <path> --repo owner/name --domain <domain> --observation <name> [--execute --app-server-host host --app-server-port port]"
      putStrLn "type-level domains:"
      print [IssuePlanning, IssueImplement, PrReview]
      putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
    _ -> die "usage: codex-watcher-hs replay <node-watcher-state-dir> | replay-events <events.jsonl> | healthcheck [--state-root <path>] [--repo owner/name] | mark-runtime-owner --state-dir <path> --owner node|haskell | observe-once --events <events.jsonl> --state-dir <path> --repo owner/name --domain <domain> --observation <name>"

parseHealthcheckOptions :: [String] -> HealthcheckOptions
parseHealthcheckOptions args =
  HealthcheckOptions
    { stateRoot = maybe "/workspace/artifacts" id (lookupFlag "--state-root" args)
    , repoFilter = Text.pack <$> lookupFlag "--repo" args
    }

lookupFlag :: String -> [String] -> Maybe String
lookupFlag _ [] = Nothing
lookupFlag flag (current : value : rest)
  | current == flag = Just value
  | otherwise = lookupFlag flag (value : rest)
lookupFlag _ [_] = Nothing

markRuntimeOwner :: [String] -> IO ()
markRuntimeOwner args = do
  stateDir <- maybe (die "mark-runtime-owner requires --state-dir <path>") pure (lookupFlag "--state-dir" args)
  ownerText <- maybe (die "mark-runtime-owner requires --owner node|haskell") (pure . Text.pack) (lookupFlag "--owner" args)
  owner <- either (die . Text.unpack) pure (parseRuntimeOwner ownerText)
  writeRuntimeOwner ioRuntimeInterpreter stateDir owner
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText owner) <> " to " <> stateDir)

observeOnce :: [String] -> IO ()
observeOnce args = do
  eventsPath <- requiredFlag "--events" args
  stateDir <- requiredFlag "--state-dir" args
  repo <- RepoName . Text.pack <$> requiredFlag "--repo" args
  observation <- parseDaemonObservation args
  executor <- observeOnceExecutor args
  let workdir = maybe "." id (lookupFlag "--workdir" args)
      options =
        DaemonOptions
          { daemonEventLogPath = eventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig repo workdir stateDir
          , daemonExecutionMode = if hasFlag "--execute" args then ExecuteActions else DryRunActions
          }
  result <- runObservedDaemonTickFromFile executor options observation
  case result of
    Left failure -> die (Text.unpack (formatDaemonFailure failure))
    Right tick -> do
      putStrLn ("event: " <> show tick.daemonObservedEvent)
      putStrLn ("phase: " <> show (somePhase tick.daemonObservedState))
      putStrLn ("compatibility writes: " <> show (length tick.daemonObservedCompatibilityWrites))
      putStrLn ("actions: " <> show (length tick.daemonObservedActionReports))
      putStrLn ("mode: " <> show options.daemonExecutionMode)

observeOnceExecutor :: [String] -> IO (ActionExecutor IO)
observeOnceExecutor args
  | hasFlag "--execute" args = do
      host <- requiredFlag "--app-server-host" args
      port <- requiredIntFlag "--app-server-port" args
      let path = maybe "/" id (lookupFlag "--app-server-path" args)
          endpoint = AppServerEndpoint host port path
      pure (ioActionExecutor (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions) (pure ()) (pure ()))
  | otherwise =
      pure (ioActionExecutor (AppServerInterpreter (\_ -> pure Null)) (pure ()) (pure ()))

parseDaemonObservation :: [String] -> IO DaemonObservation
parseDaemonObservation args = do
  domain <- requiredFlag "--domain" args
  observation <- requiredFlag "--observation" args
  case (domain, observation) of
    ("issue-planning", "turn-started") ->
      DaemonIssuePlanningObservation
        <$> (ObservedPlanningTurnStarted <$> requiredThreadId "--thread-id" args <*> requiredTurnId "--turn-id" args)
    ("issue-planning", "turn-completed") ->
      pure (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
    ("issue-implement", "triage-turn-started") ->
      DaemonIssueImplementObservation . ObservedTriageTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "triage-already-fixed") ->
      pure (DaemonIssueImplementObservation ObservedTriageAlreadyFixed)
    ("issue-implement", "triage-needs-implementation") ->
      pure (DaemonIssueImplementObservation ObservedTriageNeedsImplementation)
    ("issue-implement", "triage-blocked") ->
      DaemonIssueImplementObservation . ObservedTriageBlocked <$> requiredBlockedReason args
    ("issue-implement", "plan-turn-started") ->
      DaemonIssueImplementObservation . ObservedPlanTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "plan-completed") ->
      pure (DaemonIssueImplementObservation (ObservedPlanCompleted (TurnId . Text.pack <$> lookupFlag "--implementation-turn-id" args)))
    ("issue-implement", "pr-created") ->
      DaemonIssueImplementObservation . ObservedPullRequestCreated <$> requiredPrNumber args
    ("issue-implement", "pr-reused") ->
      DaemonIssueImplementObservation . ObservedPullRequestReused <$> requiredPrNumber args
    ("issue-implement", "implementation-turn-started") ->
      DaemonIssueImplementObservation . ObservedImplementationTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "implementation-incomplete") ->
      pure (DaemonIssueImplementObservation (ObservedImplementationIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args)))))
    ("issue-implement", "implementation-blocked") ->
      DaemonIssueImplementObservation . ObservedImplementationBlocked <$> requiredBlockedReason args
    ("issue-implement", "review-handoff-initialized") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffInitialized <$> requiredPrNumber args
    ("issue-implement", "review-handoff-started") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffStarted <$> requiredPrNumber args
    ("issue-implement", "implementation-completed") ->
      DaemonIssueImplementObservation . ObservedImplementationCompleted <$> requiredPrNumber args
    ("pr-review", "review-threads") ->
      DaemonPrReviewObservation
        <$> (ObservedReviewThreads <$> reviewThreadsReportFromArgs args <*> requiredCommitSha "--commit-sha" args <*> requiredTurnId "--turn-id" args)
    ("pr-review", "worker-completed") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
    ("pr-review", "worker-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args))))))
    ("pr-review", "worker-blocked") ->
      DaemonPrReviewObservation . ObservedWorkerOutcome . WorkerBlocked <$> requiredBlockedReason args
    ("pr-review", "reviewer-clean") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerClean <$> requiredCleanReviewEvidence args
    ("pr-review", "reviewer-problems") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerProblemsAdded <$> requiredCommitSha "--commit-sha" args
    ("pr-review", "reviewer-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args))))))
    ("pr-review", "reviewer-blocked") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerBlocked <$> requiredBlockedReason args
    ("pr-review", "merge-completed") ->
      DaemonPrReviewObservation . ObservedMergeCompleted . MergeCommit <$> requiredCommitSha "--merge-commit-sha" args
    ("pr-review", "blocked") ->
      DaemonPrReviewObservation . ObservedPrReviewBlocked <$> requiredBlockedReason args
    _ ->
      die ("unsupported observe-once domain/observation: " <> domain <> "/" <> observation)

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig repo workdir stateDir =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = stateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = 1
    , effectRuntimePlannerTurn = turnConfig "planner turn"
    , effectRuntimeWorkerTurn = turnConfig "worker turn"
    , effectRuntimeReviewerTurn = turnConfig "reviewer turn"
    }
 where
  turnConfig input =
    TurnRuntimeConfig
      { turnRuntimeCwd = workdir
      , turnRuntimeModel = "gpt-5.4"
      , turnRuntimeEffort = "xhigh"
      , turnRuntimeApprovalPolicy = "never"
      , turnRuntimeSandboxPolicy = "danger-full-access"
      , turnRuntimeInput = input
      , turnRuntimeCollaborationMode = Nothing
      }

reviewThreadsReportFromArgs :: [String] -> IO ReviewThreadsReport
reviewThreadsReportFromArgs args =
  pure
    ReviewThreadsReport
      { reviewThreads = unresolvedThreads
      , unresolvedReviewThreads = unresolvedThreads
      }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False Nothing Nothing Nothing [])
      (reviewThreadIdsFromArgs args)

reviewThreadIdsFromArgs :: [String] -> [ReviewThreadId]
reviewThreadIdsFromArgs args =
  case lookupFlag "--review-thread-ids" args of
    Nothing -> []
    Just value ->
      fmap (ReviewThreadId . Text.strip . Text.pack) (filter (not . null) (splitComma value))

splitComma :: String -> [String]
splitComma [] = []
splitComma text =
  case break (== ',') text of
    (part, []) -> [part]
    (part, _comma : rest) -> part : splitComma rest

requiredCleanReviewEvidence :: [String] -> IO CleanReviewEvidence
requiredCleanReviewEvidence args =
  CleanReviewEvidence
    <$> requiredCommitSha "--commit-sha" args
    <*> pure (Text.pack (maybe "LGTM" id (lookupFlag "--comment" args)))

requiredBlockedReason :: [String] -> IO BlockedReason
requiredBlockedReason args =
  BlockedReason . Text.pack <$> requiredFlag "--reason" args

requiredThreadId :: String -> [String] -> IO ThreadId
requiredThreadId flag args = ThreadId . Text.pack <$> requiredFlag flag args

requiredTurnId :: String -> [String] -> IO TurnId
requiredTurnId flag args = TurnId . Text.pack <$> requiredFlag flag args

requiredCommitSha :: String -> [String] -> IO CommitSha
requiredCommitSha flag args = CommitSha . Text.pack <$> requiredFlag flag args

requiredPrNumber :: [String] -> IO PrNumber
requiredPrNumber args = PrNumber <$> requiredIntFlag "--pr-number" args

requiredIntFlag :: String -> [String] -> IO Int
requiredIntFlag flag args = do
  value <- requiredFlag flag args
  maybe (die ("invalid integer for " <> flag <> ": " <> value)) pure (readMaybe value)

requiredFlag :: String -> [String] -> IO String
requiredFlag flag args =
  maybe (die ("missing required flag " <> flag)) pure (lookupFlag flag args)

hasFlag :: String -> [String] -> Bool
hasFlag flag = elem flag

replayAny :: FilePath -> IO ()
replayAny dir = do
  loaded <- loadNodeSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeSnapshot snapshot)
  printReplay replay

replayPrReview :: FilePath -> IO ()
replayPrReview dir = do
  loaded <- loadNodePrReviewSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodePrReviewSnapshot snapshot)
  printReplay replay

replayIssueImplement :: FilePath -> IO ()
replayIssueImplement dir = do
  loaded <- loadNodeIssueImplementSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeIssueImplementSnapshot snapshot)
  printReplay replay

printReplay :: ReplayResult -> IO ()
printReplay replay = do
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  mapM_ (putStrLn . ("warning: " <>) . Text.unpack) replay.replayWarnings

replayEvents :: FilePath -> IO ()
replayEvents path = do
  loaded <- loadEventLogFile path
  events <- either die pure loaded
  replay <- either (die . formatReplayFailure) pure (replayEventLog events)
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  putStrLn ("events: " <> show (length events))
  putStrLn ("effect batches: " <> show (length replay.replayEffects))

formatReplayFailure :: ReplayFailure -> String
formatReplayFailure failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
