{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Command.AppServerProbe
  ( probeAppServer
  ) where

import CodexWatcher.AppServerProtocol (initializeRequest, threadReadRequest, threadStartRequest, turnStartRequest)
import CodexWatcher.Cli.Types (AppServerProbeCli (..))
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), unThreadId, unTurnId)
import CodexWatcher.Workflow.Agent.Codex.Client
  ( formatAppServerClientFailure
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  )
import CodexWatcher.Workflow.Agent.Codex.Transport
  ( AppServerClientOptions (..)
  , defaultAppServerClientOptions
  , sendOneAppServerRequest
  )
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions, defaultTurnStartOptions)
import Control.Applicative ((<|>))
import Control.Monad (when)
import Data.Text qualified as Text
import System.Exit (die)

probeAppServer :: AppServerProbeCli -> IO ()
probeAppServer options = do
  let endpoint = options.appServerProbeCliEndpoint
      clientOptions = defaultAppServerClientOptions {appServerResponseTimeoutMicros = Just 5000000}
      send request = sendOneAppServerRequest endpoint clientOptions request

  initializeResult <- send (initializeRequest (RequestId 1) "moifold-probe" "0.1.0")
  case initializeResult of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right _ -> putStrLn "ok initialize"

  case options.appServerProbeCliThreadId of
    Nothing -> pure ()
    Just threadId -> do
      threadReadResult <- send (threadReadRequest (RequestId 2) threadId False)
      case threadReadResult of
        Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
        Right _ -> putStrLn ("ok thread/read " <> Text.unpack (unThreadId threadId))

  smokeThread <-
    if options.appServerProbeCliCreateSmokeThread || options.appServerProbeCliStartSmokeTurn
      then do
        threadStartResult <-
          send
            ( threadStartRequest
                (RequestId 3)
                (defaultThreadStartOptions options.appServerProbeCliWorkdir "moifold app-server smoke probe")
            )
        case threadStartResult >>= parseThreadStartThreadId of
          Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
          Right threadId -> do
            putStrLn ("ok thread/start " <> Text.unpack (unThreadId threadId))
            pure (Just threadId)
      else pure Nothing

  when options.appServerProbeCliStartSmokeTurn do
    let maybeThreadId = options.appServerProbeCliThreadId <|> smokeThread
    threadId <- maybe (die "--start-smoke-turn requires --thread-id or a successful smoke thread") pure maybeThreadId
    turnStartResult <-
      send
        ( turnStartRequest
            (RequestId 4)
            (defaultTurnStartOptions threadId options.appServerProbeCliWorkdir "Reply with OK for a moifold app-server smoke probe.")
        )
    case turnStartResult >>= parseTurnStartTurnId of
      Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
      Right turnId -> putStrLn ("ok turn/start " <> Text.unpack (unTurnId turnId))

  putStrLn "app-server probe passed"
