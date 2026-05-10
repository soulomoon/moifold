{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CliSpec
  ( prop_cliParsesAppServerProbe
  , prop_cliParsesHealthcheckAndRunLoop
  , prop_cliRejectsBadDomain
  , prop_cliParsesGenericRunnerGuardDomains
  ) where

import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))
import CodexWatcher.Cli.Parser (parseCliCommand)
import CodexWatcher.Cli.Types
import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.Limits (PollSeconds, StaleSeconds, mkPollSeconds, mkStaleSeconds)

prop_cliParsesAppServerProbe :: Bool
prop_cliParsesAppServerProbe =
  parseCliCommand
    [ "probe-app-server"
    , "--app-server-host"
    , "127.0.0.1"
    , "--app-server-port"
    , "4500"
    , "--app-server-path"
    , "/rpc"
    , "--thread-id"
    , "thread-1"
    , "--create-smoke-thread"
    , "--start-smoke-turn"
    , "--workdir"
    , "/tmp/repo"
    ]
    == Right
      ( CliProbeAppServer
          AppServerProbeCli
            { appServerProbeCliEndpoint = AppServerEndpoint "127.0.0.1" 4500 "/rpc"
            , appServerProbeCliThreadId = Just (ThreadId "thread-1")
            , appServerProbeCliCreateSmokeThread = True
            , appServerProbeCliStartSmokeTurn = True
            , appServerProbeCliWorkdir = "/tmp/repo"
            }
      )

prop_cliParsesHealthcheckAndRunLoop :: Bool
prop_cliParsesHealthcheckAndRunLoop =
  parseCliCommand ["healthcheck", "--state-root", "/tmp/state", "--repo", "owner/name"]
    == Right
      ( CliHealthcheck
          HealthcheckCli
            { healthcheckCliStateRoot = "/tmp/state"
            , healthcheckCliRepo = Just (RepoName "owner/name")
            , healthcheckCliEndpoint = Nothing
            }
      )
    && parseCliCommand ["clear-runtime-lease", "--state-dir", "/tmp/state"]
      == Right (CliClearRuntimeLease "/tmp/state")
    && parseCliCommand
      [ "run-issue-planning"
      , "--events"
      , "/tmp/events.jsonl"
      , "--state-dir"
      , "/tmp/state"
      , "--repo"
      , "owner/name"
      , "--app-server-host"
      , "127.0.0.1"
      , "--app-server-port"
      , "3000"
      , "--thread-id"
      , "planner-thread"
      , "--scope-issue"
      , "12"
      , "--loop"
      , "--iterations"
      , "2"
      ]
      == Right
        ( CliRunLoop
            LoopCli
              { loopCliDomain = IssuePlanning
              , loopCliEventsPath = "/tmp/events.jsonl"
              , loopCliStateDir = "/tmp/state"
              , loopCliRepo = RepoName "owner/name"
              , loopCliWorkdir = "."
              , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
              , loopCliPollSeconds = pollSecondsForTest 30
              , loopCliExecute = False
              , loopCliLoop = True
              , loopCliIterations = Just 2
              , loopCliPidFile = Nothing
              , loopCliPlannerThread = Just (ThreadId "planner-thread")
              , loopCliScopeIssues = [IssueNumber 12]
              , loopCliImplementersRoot = Nothing
              , loopCliOpenIssues = Nothing
              , loopCliActiveIssues = Nothing
              , loopCliImplementerWorkdirRoot = Nothing
              , loopCliWorkdirRoot = Nothing
              , loopCliBranchPrefix = "codex/issue-"
              , loopCliThreadPrefix = "issue-worker-"
              }
        )
    && parseCliCommand
      [ "guard-issue-planning"
      , "--events"
      , "/tmp/events.jsonl"
      , "--state-dir"
      , "/tmp/state"
      , "--repo"
      , "owner/name"
      , "--app-server-host"
      , "127.0.0.1"
      , "--app-server-port"
      , "3000"
      , "--thread-id"
      , "planner-thread"
      , "--execute"
      , "--loop"
      , "--guard-pid-file"
      , "/tmp/state/runner-guard.pid"
      , "--guard-poll-seconds"
      , "15"
      , "--stale-seconds"
      , "120"
      , "--repair-cwd"
      , "/tmp/repo"
      ]
      == Right
        ( CliGuardWatcher
            GuardWatcherCli
              { guardCliLoop =
                  LoopCli
                    { loopCliDomain = IssuePlanning
                    , loopCliEventsPath = "/tmp/events.jsonl"
                    , loopCliStateDir = "/tmp/state"
                    , loopCliRepo = RepoName "owner/name"
                    , loopCliWorkdir = "."
                    , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
                    , loopCliPollSeconds = pollSecondsForTest 30
                    , loopCliExecute = True
                    , loopCliLoop = True
                    , loopCliIterations = Nothing
                    , loopCliPidFile = Nothing
                    , loopCliPlannerThread = Just (ThreadId "planner-thread")
                    , loopCliScopeIssues = []
                    , loopCliImplementersRoot = Nothing
                    , loopCliOpenIssues = Nothing
                    , loopCliActiveIssues = Nothing
                    , loopCliImplementerWorkdirRoot = Nothing
                    , loopCliWorkdirRoot = Nothing
                    , loopCliBranchPrefix = "codex/issue-"
                    , loopCliThreadPrefix = "issue-worker-"
                    }
              , guardCliPidFile = Just "/tmp/state/runner-guard.pid"
              , guardCliPollSeconds = pollSecondsForTest 15
              , guardCliStaleSeconds = staleSecondsForTest 120
              , guardCliRepairCwd = Just "/tmp/repo"
              }
        )

prop_cliRejectsBadDomain :: Bool
prop_cliRejectsBadDomain =
  isLeft (parseCliCommand ["stop-daemon", "--state-dir", "/tmp/state", "--domain", "unknown"])
    && legacyReplayCommandsAreHidden
 where
  legacyReplayCommandsAreHidden =
    all
      isLeft
      [ parseCliCommand ["replay", "/tmp/state"]
      , parseCliCommand ["replay-pr-review", "/tmp/state"]
      , parseCliCommand ["replay-issue-implement", "/tmp/state"]
      ]

  isLeft result =
    case result of
      Left _ -> True
      Right _ -> False

prop_cliParsesGenericRunnerGuardDomains :: Bool
prop_cliParsesGenericRunnerGuardDomains =
  guardDomainOf "guard-pr-review" == Just PrReview
    && guardDomainOf "guard-issue-implement" == Just IssueImplement
 where
  guardDomainOf command =
    case parseCliCommand
      [ command
      , "--events"
      , "/tmp/events.jsonl"
      , "--state-dir"
      , "/tmp/state"
      , "--repo"
      , "owner/name"
      , "--app-server-host"
      , "127.0.0.1"
      , "--app-server-port"
      , "3000"
      ] of
      Right (CliGuardWatcher guard) -> Just guard.guardCliLoop.loopCliDomain
      _ -> Nothing

pollSecondsForTest :: Int -> PollSeconds
pollSecondsForTest seconds =
  case mkPollSeconds seconds of
    Just parsed -> parsed
    Nothing -> error ("invalid test poll seconds: " <> show seconds)

staleSecondsForTest :: Int -> StaleSeconds
staleSecondsForTest seconds =
  case mkStaleSeconds seconds of
    Just parsed -> parsed
    Nothing -> error ("invalid test stale seconds: " <> show seconds)
