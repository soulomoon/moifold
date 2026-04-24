{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.AutomaticLoop.Runner (runAutomaticLoop)
import CodexWatcher.Cli
import CodexWatcher.DaemonControlCli (stopDaemon)
import CodexWatcher.Healthcheck
import CodexWatcher.IssueFanoutCli (issueFanout)
import CodexWatcher.ObserveCli (observeOnce)
import CodexWatcher.ReplayCli (repairInvalidState, replayEvents)
import CodexWatcher.Runtime.Owner.Cli (clearRuntimeLease)
import CodexWatcher.RunnerGuardCli (runWatcherRunnerGuard)
import CodexWatcher.ServiceCli (renderService)
import CodexWatcher.Types (RepoName (unRepoName))

main :: IO ()
main =
  execCliCommandParser >>= runCliCommand

runCliCommand :: CliCommand -> IO ()
runCliCommand = \case
  CliReplayEvents path -> replayEvents path
  CliHealthcheck options -> runHealthcheck (healthcheckOptionsFromCli options)
  CliClearRuntimeLease stateDir -> clearRuntimeLease stateDir
  CliStopDaemon options -> stopDaemon options
  CliRenderService options -> renderService options
  CliIssueFanout options -> issueFanout options
  CliObserveOnce options -> observeOnce options
  CliRunLoop options -> runAutomaticLoop options
  CliGuardWatcher options -> runWatcherRunnerGuard options
  CliRepairInvalidState options -> repairInvalidState options

healthcheckOptionsFromCli :: HealthcheckCli -> HealthcheckOptions
healthcheckOptionsFromCli options =
  HealthcheckOptions
    { stateRoot = options.healthcheckCliStateRoot
    , repoFilter = unRepoName <$> options.healthcheckCliRepo
    , appServerEndpoint = options.healthcheckCliEndpoint
    }
