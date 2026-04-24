{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.AutomaticLoop.Runner (runAutomaticLoop)
import CodexWatcher.Cli.Parser (execCliCommandParser)
import CodexWatcher.Cli.Types
import CodexWatcher.Cli.Command.DaemonControl (stopDaemon)
import CodexWatcher.Healthcheck
import CodexWatcher.Cli.Command.IssueFanout (issueFanout)
import CodexWatcher.Cli.Command.Observe (observeOnce)
import CodexWatcher.Cli.Command.Replay (repairInvalidState, replayEvents)
import CodexWatcher.Runtime.Owner.Cli (clearRuntimeLease)
import CodexWatcher.Cli.Command.RunnerGuard (runWatcherRunnerGuard)
import CodexWatcher.Cli.Command.Service (renderService)
import CodexWatcher.Core.Ids (RepoName (unRepoName))

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
