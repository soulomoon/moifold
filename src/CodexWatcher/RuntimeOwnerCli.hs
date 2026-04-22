{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RuntimeOwnerCli
  ( claimRuntimeOwner
  , validateRuntimeOwnerForExecution
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.RuntimeOwner (RuntimeOwner (..), readRuntimeOwner, runtimeOwnerText, writeRuntimeOwner)
import CodexWatcher.Runtime (ioRuntimeInterpreter)
import Data.Text qualified as Text
import System.Exit (die)

claimRuntimeOwner :: FilePath -> IO ()
claimRuntimeOwner stateDir = do
  let owner = HaskellRuntime
  writeRuntimeOwner ioRuntimeInterpreter stateDir owner
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText owner) <> " to " <> stateDir)

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
        Right Nothing ->
          die "refusing to execute because runtime-owner.json is missing; claim this state directory before execute mode"
