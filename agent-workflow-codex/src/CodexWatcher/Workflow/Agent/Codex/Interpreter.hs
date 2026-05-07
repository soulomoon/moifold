module CodexWatcher.Workflow.Agent.Codex.Interpreter
  ( AppServerInterpreter (..)
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest)
import Data.Aeson (Value)

data AppServerInterpreter m = AppServerInterpreter
  { appServerSendRequest :: AppServerRequest -> m Value
  }
