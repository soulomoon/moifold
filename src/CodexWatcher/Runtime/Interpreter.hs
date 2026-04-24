module CodexWatcher.Runtime.Interpreter
  ( RuntimeInterpreter (..)
  , ioRuntimeInterpreter
  ) where

import CodexWatcher.Runtime.Command.Types
import CodexWatcher.Runtime.File
import CodexWatcher.Runtime.Process (runRuntimeCommand)
import Data.Aeson (Value)
import Data.Text (Text)

data RuntimeInterpreter m = RuntimeInterpreter
  { runtimeRunCommand :: RuntimeCommand -> m CommandReport
  , runtimeReadJsonValue :: FilePath -> m (Either Text Value)
  , runtimeWriteJsonValue :: FilePath -> Value -> m ()
  , runtimeWriteTextFile :: FilePath -> Text -> m ()
  , runtimeAppendJsonLine :: FilePath -> Value -> m ()
  }

ioRuntimeInterpreter :: RuntimeInterpreter IO
ioRuntimeInterpreter =
  RuntimeInterpreter
    { runtimeRunCommand = runRuntimeCommand
    , runtimeReadJsonValue = readJsonValue
    , runtimeWriteJsonValue = writeJsonValue
    , runtimeWriteTextFile = writeTextFile
    , runtimeAppendJsonLine = appendJsonLine
    }
