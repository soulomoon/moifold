{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.ChildDaemon
  ( DaemonPidReadiness (..)
  , daemonPidFileStatus
  , ensurePidFileAvailable
  , isPidRunning
  , readPidFile
  , removeOwnedPidFile
  , runWithOptionalPidFile
  , stableExecutablePath
  , startChildDaemon
  , waitForStartedDaemon
  ) where

import CodexWatcher.Runtime (CommandReport (..), RuntimeCommand (KillZero), runRuntimeCommand)
import Control.Concurrent (forkIO, threadDelay)
import Control.Exception (IOException, finally, try)
import Control.Monad (unless, void, when)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectory, createDirectoryIfMissing, doesFileExist, removeFile, removePathForcibly)
import System.Environment (getExecutablePath)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))
import System.IO (IOMode (AppendMode), hFlush, hPutStrLn, withFile)
import System.Posix.Process (getProcessID)
import System.Process.Typed qualified as Process.Typed

data DaemonPidReadiness
  = DaemonPidReady
  | DaemonPidNotReady Text
  deriving stock (Eq, Show)

stableExecutablePath :: IO FilePath
stableExecutablePath = do
  executable <- getExecutablePath
  pure $
    maybe
      executable
      Text.unpack
      (Text.stripSuffix " (deleted)" (Text.pack executable))

startChildDaemon :: String -> FilePath -> FilePath -> [String] -> IO ()
startChildDaemon label stateDir pidFileName childArgs = do
  executable <- stableExecutablePath
  let stdoutPath = stateDir </> "daemon.log"
      stderrPath = stateDir </> "daemon.err.log"
      pidPath = stateDir </> pidFileName
      commandLine = unwords (executable : childArgs)
  withFile stdoutPath AppendMode \stdoutHandle ->
    withFile stderrPath AppendMode \stderrHandle -> do
      hPutStrLn stdoutHandle ("starting " <> label <> ": " <> commandLine)
      hFlush stdoutHandle
      hFlush stderrHandle
      process <-
        Process.Typed.startProcess
          ( Process.Typed.setCloseFds True
              $ Process.Typed.setStdout (Process.Typed.useHandleOpen stdoutHandle)
              $ Process.Typed.setStderr (Process.Typed.useHandleOpen stderrHandle)
              $ Process.Typed.proc executable childArgs
          )
      pid <- Process.Typed.getPid process
      void (forkIO (void (Process.Typed.waitExitCode process)))
      waitForStartedDaemon label pidPath (Text.pack . show <$> pid)
      putStrLn ("started " <> label <> " pid " <> maybe "unknown" show pid)

waitForStartedDaemon :: String -> FilePath -> Maybe Text -> IO ()
waitForStartedDaemon label pidPath expectedPid =
  go (20 :: Int)
 where
  go attemptsLeft = do
    status <- daemonPidFileStatus pidPath expectedPid
    case status of
      DaemonPidReady -> pure ()
      DaemonPidNotReady detail
        | attemptsLeft <= 0 ->
            die ("started " <> label <> " but daemon pid did not become running: " <> Text.unpack detail)
        | otherwise -> do
            threadDelay 250000
            go (attemptsLeft - 1)

daemonPidFileStatus :: FilePath -> Maybe Text -> IO DaemonPidReadiness
daemonPidFileStatus pidPath expectedPid = do
  maybePid <- readPidFile pidPath
  case maybePid of
    Nothing ->
      pure (DaemonPidNotReady ("pid file is missing or empty: " <> Text.pack pidPath))
    Just pidText -> do
      running <- isPidRunning pidText
      pure
        if running && maybe True (== pidText) expectedPid
          then DaemonPidReady
          else
            DaemonPidNotReady
              ( "pid file "
                  <> Text.pack pidPath
                  <> " contains "
                  <> pidText
                  <> ", expected "
                  <> maybe "<any running pid>" id expectedPid
                  <> ", running="
                  <> Text.pack (show running)
              )

readPidFile :: FilePath -> IO (Maybe Text)
readPidFile pidPath = do
  exists <- doesFileExist pidPath
  if not exists
    then pure Nothing
    else do
      pidText <- Text.strip . Text.pack <$> readFile pidPath
      pure if Text.null pidText then Nothing else Just pidText

isPidRunning :: Text -> IO Bool
isPidRunning pidText = do
  report <- runRuntimeCommand (KillZero pidText)
  pure report.ok

runWithOptionalPidFile :: Maybe FilePath -> IO () -> IO ()
runWithOptionalPidFile Nothing action = action
runWithOptionalPidFile (Just pidPath) action = do
  pidText <- Text.pack . show <$> getProcessID
  acquirePidFileLock pidPath
  (writeFile pidPath (Text.unpack pidText <> "\n") >> action) `finally` removeOwnedPidFile pidPath pidText

ensurePidFileAvailable :: FilePath -> IO ()
ensurePidFileAvailable pidPath = do
  maybePid <- readPidFile pidPath
  case maybePid of
    Nothing -> pure ()
    Just pidText -> do
      running <- isPidRunning pidText
      when running $
        die ("refusing to start because pid file is already running: " <> pidPath)

acquirePidFileLock :: FilePath -> IO ()
acquirePidFileLock pidPath = do
  createDirectoryIfMissing True (takeDirectory pidPath)
  acquired <- tryCreatePidLock pidPath
  unless acquired do
    maybePid <- readPidFile pidPath
    running <- maybe (pure False) isPidRunning maybePid
    if running
      then die ("refusing to start because pid file is already running: " <> pidPath)
      else do
        removePathForcibly (pidLockPath pidPath)
        acquiredAfterCleanup <- tryCreatePidLock pidPath
        unless acquiredAfterCleanup $
          die ("refusing to start because pid lock is already held: " <> pidLockPath pidPath)

tryCreatePidLock :: FilePath -> IO Bool
tryCreatePidLock pidPath = do
  result <- try (createDirectory (pidLockPath pidPath)) :: IO (Either IOException ())
  pure case result of
    Right () -> True
    Left _ -> False

removeOwnedPidFile :: FilePath -> Text -> IO ()
removeOwnedPidFile pidPath expectedPid = do
  maybePid <- readPidFile pidPath
  case maybePid of
    Just currentPid | currentPid == expectedPid -> do
      removeFile pidPath
      removePathForcibly (pidLockPath pidPath)
    _ -> pure ()

pidLockPath :: FilePath -> FilePath
pidLockPath pidPath =
  pidPath <> ".lock"
