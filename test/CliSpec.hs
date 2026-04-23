{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CliSpec
  ( prop_cliParsesHealthcheckAndRunLoop
  , prop_cliRejectsBadDomain
  , prop_cliParsesGenericRunnerGuardDomains
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.Cli
import CodexWatcher.Types

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
              { loopCliDomain = CliIssuePlanning
              , loopCliEventsPath = "/tmp/events.jsonl"
              , loopCliStateDir = "/tmp/state"
              , loopCliRepo = RepoName "owner/name"
              , loopCliWorkdir = "."
              , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
              , loopCliPollSeconds = 30
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
              , loopCliStartChildren = False
              , loopCliChildPollSeconds = Nothing
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
                    { loopCliDomain = CliIssuePlanning
                    , loopCliEventsPath = "/tmp/events.jsonl"
                    , loopCliStateDir = "/tmp/state"
                    , loopCliRepo = RepoName "owner/name"
                    , loopCliWorkdir = "."
                    , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
                    , loopCliPollSeconds = 30
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
                    , loopCliStartChildren = False
                    , loopCliChildPollSeconds = Nothing
                    }
              , guardCliPidFile = Just "/tmp/state/runner-guard.pid"
              , guardCliPollSeconds = 15
              , guardCliStaleSeconds = 120
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
  guardDomainOf "guard-pr-review" == Just CliPrReview
    && guardDomainOf "guard-issue-implement" == Just CliIssueImplement
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
