{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.App.Common
  ( defaultEffectRuntimeConfig
  , defaultEffectRuntimeConfigWithPlannerScope
  , defaultThreadStartOptions
  , ensureLaunchStateWritable
  , formatReplayFailure
  , isPidRunning
  , issueNumbersText
  , pidFileNameForDomain
  , pidFileRunning
  , printChildCommand
  , readPidFileText
  , runWithOptionalPidFile
  , shellQuoteText
  , shellWords
  , stableExecutablePath
  , startAppServerThread
  , startWatcherChildProcess
  , validateRuntimeOwnerForExecution
  , watcherPidRunning
  , writeCompatibilityLaunch
  , writeWatcherBootstrap
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Cli
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog
import CodexWatcher.Migration
import CodexWatcher.Runtime
import CodexWatcher.TurnOutput
import CodexWatcher.Types
import Control.Exception (finally)
import Control.Monad (when)
import Data.Aeson (Value)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesFileExist, removeFile)
import System.Environment (getExecutablePath)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))
import System.IO (IOMode (AppendMode), hFlush, withFile)
import System.Posix.Process (getProcessID)
import System.Process qualified as Process

stableExecutablePath :: IO FilePath
stableExecutablePath = do
  executable <- getExecutablePath
  pure $
    maybe
      executable
      Text.unpack
      (Text.stripSuffix " (deleted)" (Text.pack executable))

pidFileNameForDomain :: CliDomain -> FilePath
pidFileNameForDomain CliPrReview = "watcher.pid"
pidFileNameForDomain CliIssueImplement = "issue-watcher.pid"
pidFileNameForDomain CliIssuePlanning = "issue-planning-watcher.pid"

runWithOptionalPidFile :: Maybe FilePath -> IO () -> IO ()
runWithOptionalPidFile Nothing action = action
runWithOptionalPidFile (Just pidPath) action = do
  ensurePidFileAvailable pidPath
  pidText <- Text.pack . show <$> getProcessID
  createDirectoryIfMissing True (takeDirectory pidPath)
  writeFile pidPath (Text.unpack pidText <> "\n")
  action `finally` removeOwnedPidFile pidPath pidText

ensurePidFileAvailable :: FilePath -> IO ()
ensurePidFileAvailable pidPath = do
  running <- pidFileRunning pidPath
  when running $
    die ("refusing to start because pid file is already running: " <> pidPath)

removeOwnedPidFile :: FilePath -> Text.Text -> IO ()
removeOwnedPidFile pidPath expectedPid = do
  exists <- doesFileExist pidPath
  when exists $ do
    currentPid <- Text.strip . Text.pack <$> readFile pidPath
    when (currentPid == expectedPid) $
      removeFile pidPath

isPidRunning :: Text.Text -> IO Bool
isPidRunning pidText = do
  report <- runRuntimeCommand (KillZero pidText)
  pure report.ok

pidFileRunning :: FilePath -> IO Bool
pidFileRunning pidPath = do
  pidText <- readPidFileText pidPath
  maybe (pure False) isPidRunning pidText

watcherPidRunning :: FilePath -> FilePath -> IO Bool
watcherPidRunning pidFileName stateDir =
  pidFileRunning (stateDir </> pidFileName)

readPidFileText :: FilePath -> IO (Maybe Text.Text)
readPidFileText pidPath = do
  exists <- doesFileExist pidPath
  if not exists
    then pure Nothing
    else do
      pidText <- Text.strip . Text.pack <$> readFile pidPath
      pure
        if Text.null pidText
          then Nothing
          else Just pidText

validateRuntimeOwnerForExecution :: FilePath -> ActionExecutionMode -> IO ()
validateRuntimeOwnerForExecution stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      ownerResult <- readRuntimeOwner stateDir
      case ownerResult of
        Left errorMessage ->
          die ("runtime owner marker is invalid: " <> Text.unpack errorMessage)
        Right (Just HaskellRuntime) ->
          pure ()
        Right (Just NodeRuntime) ->
          die "refusing to execute because runtime-owner.json is node; mark owner haskell before migration"
        Right Nothing ->
          die "refusing to execute because runtime-owner.json is missing; mark owner haskell before migration"

defaultThreadStartOptions :: FilePath -> Text.Text -> ThreadStartOptions
defaultThreadStartOptions cwd developerInstructions =
  ThreadStartOptions
    { threadCwd = cwd
    , threadApprovalPolicy = "never"
    , threadSandbox = "danger-full-access"
    , threadModel = "gpt-5.4"
    , threadDeveloperInstructions = developerInstructions
    }

startAppServerThread :: AppServerEndpoint -> Int -> ThreadStartOptions -> IO ThreadId
startAppServerThread endpoint requestId options = do
  response <-
    sendOneAppServerRequest
      endpoint
      defaultAppServerClientOptions
      (threadStartRequest requestId options)
  case response >>= parseThreadStartThreadId of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right threadId -> pure threadId

writeCompatibilityLaunch :: RuntimeInterpreter IO -> CompatibilityWrite -> IO ()
writeCompatibilityLaunch interpreter write =
  interpreter.runtimeWriteJsonValue write.compatibilityWritePath write.compatibilityWriteValue

ensureLaunchStateWritable :: String -> FilePath -> FilePath -> FilePath -> IO ()
ensureLaunchStateWritable label stateDir configPath eventsPath = do
  configExists <- doesFileExist configPath
  eventsExists <- doesFileExist eventsPath
  when (configExists || eventsExists) $
    die ("refusing to overwrite existing " <> label <> " state: " <> stateDir)

writeWatcherBootstrap :: FilePath -> FilePath -> Value -> WatcherEvent -> [CompatibilityWrite] -> IO ()
writeWatcherBootstrap configPath eventsPath configJson initialEvent compatibilityWrites = do
  let stateDir = takeDirectory configPath
  createDirectoryIfMissing True stateDir
  writeJsonValue configPath configJson
  appendWatcherEvent ioRuntimeInterpreter eventsPath initialEvent
  mapM_ (writeCompatibilityLaunch ioRuntimeInterpreter) compatibilityWrites
  writeRuntimeOwner ioRuntimeInterpreter stateDir HaskellRuntime

printChildCommand :: String -> [String] -> IO ()
printChildCommand label args = do
  executable <- stableExecutablePath
  putStrLn (label <> unwords (executable : args))

startWatcherChildProcess :: FilePath -> [String] -> Text.Text -> IO ()
startWatcherChildProcess stateDir childArgs startedMessage = do
  executable <- stableExecutablePath
  let stdoutPath = stateDir </> "daemon.log"
      stderrPath = stateDir </> "daemon.err.log"
  withFile stdoutPath AppendMode \stdoutHandle ->
    withFile stderrPath AppendMode \stderrHandle -> do
      hFlush stdoutHandle
      hFlush stderrHandle
      (_, _, _, processHandle) <-
        Process.createProcess
          (Process.proc executable childArgs)
            { Process.std_out = Process.UseHandle stdoutHandle
            , Process.std_err = Process.UseHandle stderrHandle
            , Process.close_fds = True
            }
      pid <- Process.getPid processHandle
      putStrLn (Text.unpack startedMessage <> " pid " <> maybe "unknown" show pid)

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig =
  defaultEffectRuntimeConfigWithPlannerScope []

defaultEffectRuntimeConfigWithPlannerScope :: [IssueNumber] -> RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfigWithPlannerScope scopeIssues repo workdir stateDir =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = stateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = 1
    , effectRuntimePlannerTurn =
        (turnConfig (plannerTurnInputForScope scopeIssues))
          { turnRuntimeCollaborationMode =
              Just
                ( planCollaborationMode
                    (issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues)
                    "gpt-5.4"
                    "xhigh"
                )
          }
    , effectRuntimeWorkerTurn = turnConfig prReviewWorkerTurnInput
    , effectRuntimeIssueTriageTurn = turnConfig issueTriageTurnInput
    , effectRuntimeIssuePlanTurn =
        (turnConfig issuePlanTurnInput)
          { turnRuntimeCollaborationMode =
              Just (planCollaborationMode "Issue-specific plan-mode instructions are generated when the plan turn starts." "gpt-5.4" "xhigh")
          }
    , effectRuntimeIssueImplementationTurn = turnConfig issueImplementationTurnInput
    , effectRuntimeReviewerTurn = turnConfig "Reviewer prompt is generated per PR target commit."
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
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = Nothing
      }

plannerTurnInputForScope :: [IssueNumber] -> Text.Text
plannerTurnInputForScope [] =
  plannerTurnInput
plannerTurnInputForScope scopeIssues =
  plannerTurnInput
    <> " Target scope: only these root issues and their existing or newly created GitHub sub-issues are in scope: "
    <> issueNumbersText scopeIssues
    <> ". Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees. If a scoped root issue needs decomposition, create concrete GitHub sub-issues under that root, then let the watcher re-enter planning. When returning ready_issues, blocked_issues, and dependencies, include only scoped root issues and descendants that belong to these issue trees."

issueNumbersText :: [IssueNumber] -> Text.Text
issueNumbersText =
  Text.intercalate "," . fmap (Text.pack . show . unIssueNumber)

shellWords :: [Text.Text] -> Text.Text
shellWords =
  Text.unwords . fmap shellQuoteText

shellQuoteText :: Text.Text -> Text.Text
shellQuoteText text =
  "'" <> Text.replace "'" "'\"'\"'" text <> "'"

formatReplayFailure :: ReplayFailure -> String
formatReplayFailure failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
