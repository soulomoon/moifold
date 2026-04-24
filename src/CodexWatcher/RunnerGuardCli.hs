{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.RunnerGuardCli
  ( boolSwitch
  , guardCommandForDomain
  , guardStartCommand
  , loopCliCommandArgs
  , runCommandForDomain
  , runWatcherRunnerGuard
  , shellQuoteText
  , shellWords
  , watcherStartCommand
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.ChildDaemon (runWithOptionalPidFile, stableExecutablePath)
import CodexWatcher.Cli.Types
import CodexWatcher.CliPaths (defaultCliPidPath)
import CodexWatcher.IssueText (issueNumbersCsv)
import CodexWatcher.RunnerGuard
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..))
import CodexWatcher.Runtime.File (writeJsonValue)
import CodexWatcher.Runtime.Process (commandSummary)
import CodexWatcher.Types
import Control.Concurrent (threadDelay)
import Data.Aeson (object, toJSON, (.=))
import Data.Proxy (Proxy (..))
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.FilePath ((</>))

runWatcherRunnerGuard :: GuardWatcherCli -> IO ()
runWatcherRunnerGuard cli =
  withDomain cli.guardCliLoop.loopCliDomain \proxy ->
    runWatcherRunnerGuardTyped proxy cli

runWatcherRunnerGuardTyped :: forall domain. KnownDomain domain => Proxy domain -> GuardWatcherCli -> IO ()
runWatcherRunnerGuardTyped _ cli = do
  executable <- stableExecutablePath
  defaultRepairCwd <- getCurrentDirectory
  let loopCli = cli.guardCliLoop
      guardPidFile = maybe (loopCli.loopCliStateDir </> "runner-guard.pid") id cli.guardCliPidFile
      watcherPidFile = maybe (defaultCliPidPath loopCli.loopCliDomain loopCli.loopCliStateDir) id loopCli.loopCliPidFile
      repairCwd = maybe defaultRepairCwd id cli.guardCliRepairCwd
      guardConfig :: RunnerGuardConfig domain
      guardConfig =
        RunnerGuardConfig
          { guardRepo = loopCli.loopCliRepo
          , guardEventsPath = loopCli.loopCliEventsPath
          , guardStateDir = loopCli.loopCliStateDir
          , guardWatcherPidFile = watcherPidFile
          , guardAppServerEndpoint = loopCli.loopCliEndpoint
          , guardStaleSeconds = cli.guardCliStaleSeconds
          , guardRepairCwd = repairCwd
          , guardRestartWatcherCommand = watcherStartCommand executable watcherPidFile loopCli
          , guardRestartGuardCommand = guardStartCommand executable guardPidFile cli
          }
  runWithOptionalPidFile (Just guardPidFile) (runnerGuardLoop guardConfig cli.guardCliPollSeconds)

runnerGuardLoop :: KnownDomain domain => RunnerGuardConfig domain -> PollSeconds -> IO ()
runnerGuardLoop config pollSeconds = do
  checkRunnerGuard config >>= \case
    Nothing -> do
      threadDelay (pollSecondsMicros pollSeconds)
      runnerGuardLoop config pollSeconds
    Just guardProblem -> do
      createDirectoryIfMissing True config.guardStateDir
      writeJsonValue (config.guardStateDir </> "runner-guard-problem.json") (toJSON guardProblem)
      handleRunnerGuardProblem config pollSeconds guardProblem

handleRunnerGuardProblem :: KnownDomain domain => RunnerGuardConfig domain -> PollSeconds -> RunnerGuardProblem -> IO ()
handleRunnerGuardProblem config pollSeconds guardProblem =
  case guardProblem.runnerGuardProblemAction of
    RestartWatcher -> do
      report <- commandSummary "bash" ["-lc", Text.unpack config.guardRestartWatcherCommand] Nothing
      writeJsonValue
        (config.guardStateDir </> "runner-guard-restart.json")
        ( object
            [ "problem" .= guardProblem
            , "command" .= config.guardRestartWatcherCommand
            , "report" .= report
            ]
        )
      if report.ok
        then do
          putStrLn "runner guard restarted watcher"
          threadDelay (pollSecondsMicros pollSeconds)
          runnerGuardLoop config pollSeconds
        else do
          let repairProblem =
                RunnerGuardProblem
                  { runnerGuardProblemAction = LaunchRepairThread
                  , runnerGuardProblemSummary = "runner guard failed to restart watcher"
                  , runnerGuardProblemDetails =
                      guardProblem.runnerGuardProblemSummary
                        : guardProblem.runnerGuardProblemDetails
                          <> [ "restart command: " <> config.guardRestartWatcherCommand
                             , "restart output: " <> commandText report
                             ]
                  }
          launchRunnerGuardRepair config repairProblem
    LaunchRepairThread ->
      launchRunnerGuardRepair config guardProblem

launchRunnerGuardRepair :: KnownDomain domain => RunnerGuardConfig domain -> RunnerGuardProblem -> IO ()
launchRunnerGuardRepair config guardProblem = do
  repair <- startRunnerGuardRepairThread config guardProblem
  writeJsonValue (config.guardStateDir </> "runner-guard-repair.json") (toJSON repair)
  putStrLn ("runner guard launched repair thread " <> Text.unpack (unThreadId repair.runnerGuardRepairThreadId) <> " turn " <> Text.unpack (unTurnId repair.runnerGuardRepairTurnId))

watcherStartCommand :: FilePath -> FilePath -> LoopCli -> Text.Text
watcherStartCommand executable watcherPidFile cli =
  "setsid -f "
    <> shellWords (Text.pack executable : Text.pack (runCommandForDomain cli.loopCliDomain) : loopCliCommandArgs watcherPidFile cli)
    <> " >> "
    <> shellQuoteText (Text.pack (cli.loopCliStateDir </> "watcher.log"))
    <> " 2>> "
    <> shellQuoteText (Text.pack (cli.loopCliStateDir </> "watcher.err.log"))

guardStartCommand :: FilePath -> FilePath -> GuardWatcherCli -> Text.Text
guardStartCommand executable guardPidFile cli =
  "setsid -f "
    <> shellWords (Text.pack executable : Text.pack (guardCommandForDomain cli.guardCliLoop.loopCliDomain) : guardCliCommandArgs guardPidFile cli)
    <> " >> "
    <> shellQuoteText (Text.pack (cli.guardCliLoop.loopCliStateDir </> "runner-guard.log"))
    <> " 2>> "
    <> shellQuoteText (Text.pack (cli.guardCliLoop.loopCliStateDir </> "runner-guard.err.log"))

guardCliCommandArgs :: FilePath -> GuardWatcherCli -> [Text.Text]
guardCliCommandArgs guardPidFile cli =
  loopCliCommandArgs watcherPidFile cli.guardCliLoop
    <> ["--guard-pid-file", Text.pack guardPidFile, "--guard-poll-seconds", Text.pack (show cli.guardCliPollSeconds), "--stale-seconds", Text.pack (show cli.guardCliStaleSeconds)]
    <> maybe [] (\repairCwd -> ["--repair-cwd", Text.pack repairCwd]) cli.guardCliRepairCwd
 where
  watcherPidFile = maybe (defaultCliPidPath cli.guardCliLoop.loopCliDomain cli.guardCliLoop.loopCliStateDir) id cli.guardCliLoop.loopCliPidFile

loopCliCommandArgs :: FilePath -> LoopCli -> [Text.Text]
loopCliCommandArgs watcherPidFile cli =
  [ "--events"
  , Text.pack cli.loopCliEventsPath
  , "--state-dir"
  , Text.pack cli.loopCliStateDir
  , "--repo"
  , unRepoName cli.loopCliRepo
  , "--workdir"
  , Text.pack cli.loopCliWorkdir
  , "--app-server-host"
  , Text.pack cli.loopCliEndpoint.appServerHost
  , "--app-server-port"
  , Text.pack (show cli.loopCliEndpoint.appServerPort)
  , "--app-server-path"
  , Text.pack cli.loopCliEndpoint.appServerPath
  , "--poll-seconds"
  , Text.pack (show cli.loopCliPollSeconds)
  , "--pid-file"
  , Text.pack watcherPidFile
  ]
    <> boolSwitch cli.loopCliExecute "--execute"
    <> boolSwitch cli.loopCliLoop "--loop"
    <> maybe [] (\iterations -> ["--iterations", Text.pack (show iterations)]) cli.loopCliIterations
    <> ( case cli.loopCliScopeIssues of
           [] -> []
           issueNumbers -> ["--scope-issues", issueNumbersCsv issueNumbers]
       )
    <> maybe [] (\root -> ["--implementers-root", Text.pack root]) cli.loopCliImplementersRoot
    <> maybe [] (\issues -> ["--open-issues", issueNumbersCsv issues]) cli.loopCliOpenIssues
    <> maybe [] (\issues -> ["--active-issues", issueNumbersCsv issues]) cli.loopCliActiveIssues
    <> maybe [] (\root -> ["--implementer-workdir-root", Text.pack root]) cli.loopCliImplementerWorkdirRoot
    <> maybe [] (\root -> ["--workdir-root", Text.pack root]) cli.loopCliWorkdirRoot
    <> ["--branch-prefix", cli.loopCliBranchPrefix, "--thread-prefix", cli.loopCliThreadPrefix]
    <> boolSwitch cli.loopCliStartChildren "--start-children"
    <> maybe [] (\seconds -> ["--child-poll-seconds", Text.pack (show seconds)]) cli.loopCliChildPollSeconds

runCommandForDomain :: Domain -> String
runCommandForDomain = \case
  PrReview -> "run-pr-review"
  IssueImplement -> "run-issue-implement"
  IssuePlanning -> "run-issue-planning"

guardCommandForDomain :: Domain -> String
guardCommandForDomain = \case
  PrReview -> "guard-pr-review"
  IssueImplement -> "guard-issue-implement"
  IssuePlanning -> "guard-issue-planning"

boolSwitch :: Bool -> Text.Text -> [Text.Text]
boolSwitch enabled switchText =
  [switchText | enabled]

shellWords :: [Text.Text] -> Text.Text
shellWords =
  Text.unwords . fmap shellQuoteText

shellQuoteText :: Text.Text -> Text.Text
shellQuoteText text =
  "'" <> Text.replace "'" "'\"'\"'" text <> "'"
