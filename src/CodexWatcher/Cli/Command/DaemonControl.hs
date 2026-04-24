{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Cli.Command.DaemonControl
  ( stopDaemon
  ) where

import CodexWatcher.ChildDaemon (isPidRunning)
import CodexWatcher.Cli.Types (StopDaemonCli (..))
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (KillTerm))
import CodexWatcher.Runtime.Process (runRuntimeCommand)
import CodexWatcher.Runtime.WatcherPaths qualified as WatcherPaths
import Control.Monad (when)
import Data.Text qualified as Text
import System.Directory (doesFileExist)
import System.Exit (die)

stopDaemon :: StopDaemonCli -> IO ()
stopDaemon options = do
  pidPath <- stopDaemonPidPath options
  exists <- doesFileExist pidPath
  if not exists
    then putStrLn ("daemon pid file does not exist: " <> pidPath)
    else do
      pidText <- Text.strip . Text.pack <$> readFile pidPath
      when (Text.null pidText) $
        die ("daemon pid file is empty: " <> pidPath)
      running <- isPidRunning pidText
      if not running
        then putStrLn ("daemon is not running for pid file: " <> pidPath)
        else do
          report <- runRuntimeCommand (KillTerm pidText)
          if report.ok
            then putStrLn ("sent TERM to daemon pid " <> Text.unpack pidText)
            else die ("failed to stop daemon: " <> Text.unpack (commandText report))

stopDaemonPidPath :: StopDaemonCli -> IO FilePath
stopDaemonPidPath options =
  case options.stopDaemonCliPidFile of
    Just pidPath -> pure pidPath
    Nothing -> do
      stateDir <- maybe (die "stop-daemon requires --pid-file <path> or --state-dir <path> --domain <domain>") pure options.stopDaemonCliStateDir
      domain <- maybe (die "stop-daemon requires --pid-file <path> or --state-dir <path> --domain <domain>") pure options.stopDaemonCliDomain
      pure (WatcherPaths.defaultPidPath domain stateDir)
