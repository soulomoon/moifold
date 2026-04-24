{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}

module CodexWatcher.Runtime.Paths
  ( RuntimeWorkdir (..)
  , RuntimeStateDir (..)
  , RuntimeCwd (..)
  , runtimeWorkdirPath
  , runtimeStateDirPath
  , runtimeStateDirFile
  , runtimeCwdPath
  ) where

import System.FilePath ((</>))

newtype RuntimeWorkdir = RuntimeWorkdir { unRuntimeWorkdir :: FilePath }
  deriving stock (Eq, Show)

newtype RuntimeStateDir = RuntimeStateDir { unRuntimeStateDir :: FilePath }
  deriving stock (Eq, Show)

data RuntimeCwd
  = RuntimeWorkdirCwd RuntimeWorkdir
  | RuntimeStateDirCwd RuntimeStateDir
  deriving stock (Eq, Show)

runtimeWorkdirPath :: RuntimeWorkdir -> FilePath
runtimeWorkdirPath =
  unRuntimeWorkdir

runtimeStateDirPath :: RuntimeStateDir -> FilePath
runtimeStateDirPath =
  unRuntimeStateDir

runtimeStateDirFile :: RuntimeStateDir -> FilePath -> FilePath
runtimeStateDirFile stateDir fileName =
  unRuntimeStateDir stateDir </> fileName

runtimeCwdPath :: RuntimeCwd -> FilePath
runtimeCwdPath = \case
  RuntimeWorkdirCwd workdir -> runtimeWorkdirPath workdir
  RuntimeStateDirCwd stateDir -> runtimeStateDirPath stateDir
