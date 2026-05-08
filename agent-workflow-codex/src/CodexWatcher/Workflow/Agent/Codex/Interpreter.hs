-- | Minimal app-server interpreter boundary: a typed request is sent and a JSON
-- value is returned. Concrete endpoint management and process ownership live
-- outside this record.
module CodexWatcher.Workflow.Agent.Codex.Interpreter
  ( AppServerInterpreter (..)
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest)
import Data.Aeson (Value)

data AppServerInterpreter m = AppServerInterpreter
  { appServerSendRequest :: AppServerRequest -> m Value
  }
