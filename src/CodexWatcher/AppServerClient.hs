{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CodexWatcher.AppServerClient
  ( AppServerClientFailure (..)
  , AppServerClientOptions (..)
  , AppServerConnection (..)
  , AppServerEndpoint (..)
  , AppServerIncoming (..)
  , AppServerTurn (..)
  , JsonRpcError (..)
  , appServerRequestSession
  , appServerInterpreterFromEndpoint
  , connectAppServer
  , decodeAppServerIncoming
  , decodeAppServerIncomingValue
  , defaultAppServerClientOptions
  , formatAppServerClientFailure
  , latestTurnById
  , matchAppServerIncoming
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  , parseThreadReadTurns
  , sendAppServerRequest
  , sendOneAppServerRequest
  , startThreadWithEndpoint
  , startThreadWithInterpreter
  , threadReadFallbackRequest
  , threadReadMaterializationPending
  , threadSystemError
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest (..), ThreadStartOptions, initializeRequest, initializedNotification, threadStartRequest)
import CodexWatcher.Core.Ids (RequestId (..), ThreadId (..))
import CodexWatcher.Workflow.Agent.Codex.Client
  ( AppServerClientFailure (..)
  , AppServerIncoming (..)
  , AppServerTurn (..)
  , JsonRpcError (..)
  , decodeAppServerIncoming
  , decodeAppServerIncomingValue
  , formatAppServerClientFailure
  , latestTurnById
  , markThreadReadMaterializationPending
  , matchAppServerIncoming
  , parseThreadReadTurns
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  , threadReadFallbackRequest
  , threadReadMaterializationPending
  , threadSystemError
  )
import CodexWatcher.Workflow.Agent.Codex.Interpreter (AppServerInterpreter (..))
import Control.Exception (AsyncException, SomeException, displayException, fromException, throwIO, try)
import Data.Aeson
  ( Value (..)
  , encode
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Network.WebSockets qualified as WebSockets
import System.Timeout (timeout)

data AppServerEndpoint = AppServerEndpoint
  { appServerHost :: String
  , appServerPort :: Int
  , appServerPath :: String
  }
  deriving stock (Eq, Show, Generic)

data AppServerClientOptions = AppServerClientOptions
  { appServerResponseTimeoutMicros :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)

defaultAppServerClientOptions :: AppServerClientOptions
defaultAppServerClientOptions =
  AppServerClientOptions
    { appServerResponseTimeoutMicros = Just 300000000
    }

newtype AppServerConnection = AppServerConnection
  { unAppServerConnection :: WebSockets.Connection
  }

connectAppServer :: AppServerEndpoint -> (AppServerConnection -> IO a) -> IO a
connectAppServer endpoint action =
  WebSockets.runClient endpoint.appServerHost endpoint.appServerPort (normalizedPath endpoint.appServerPath) \connection ->
    action (AppServerConnection connection)

sendOneAppServerRequest :: AppServerEndpoint -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendOneAppServerRequest endpoint options request =
  sendRequestWithFallback endpoint options request

sendRequestWithFallback :: AppServerEndpoint -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendRequestWithFallback endpoint options request = do
  initial <- sendOneAppServerRequestOnce endpoint options request
  case initial of
    Left failure
      | Just fallbackRequest <- threadReadFallbackRequest request failure -> do
          fallbackResult <- sendOneAppServerRequestOnce endpoint options fallbackRequest
          pure (markThreadReadMaterializationPending <$> fallbackResult)
    _ ->
      pure initial

sendOneAppServerRequestOnce :: AppServerEndpoint -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendOneAppServerRequestOnce endpoint options request =
  transportTry (connectAppServer endpoint \connection -> sendAppServerRequestSession connection options (appServerRequestSession request)) >>= \case
    Left message -> pure (Left (AppServerTransportFailure message))
    Right result -> pure result

startThreadWithEndpoint :: AppServerEndpoint -> AppServerClientOptions -> RequestId -> ThreadStartOptions -> IO (Either AppServerClientFailure ThreadId)
startThreadWithEndpoint endpoint options =
  startThreadWithSender (sendOneAppServerRequest endpoint options)

startThreadWithInterpreter :: Monad m => AppServerInterpreter m -> RequestId -> ThreadStartOptions -> m (Either AppServerClientFailure ThreadId)
startThreadWithInterpreter interpreter =
  startThreadWithSender (\request -> Right <$> interpreter.appServerSendRequest request)

appServerRequestSession :: AppServerRequest -> [AppServerRequest]
appServerRequestSession request
  | request.requestMethod == "initialize" = [request]
  | otherwise = [initializeRequest (RequestId 0) "moifold" "0.1.0", request]

sendAppServerRequestSession :: AppServerConnection -> AppServerClientOptions -> [AppServerRequest] -> IO (Either AppServerClientFailure Value)
sendAppServerRequestSession _connection _options [] =
  pure (Right Null)
sendAppServerRequestSession connection options [request]
  | request.requestMethod == "initialize" =
      sendInitializedSession connection options request (pure . Right)
  | otherwise =
      sendAppServerRequest connection options request
sendAppServerRequestSession connection options (request : rest) = do
  if request.requestMethod == "initialize"
    then sendInitializedSession connection options request \_ -> sendAppServerRequestSession connection options rest
    else do
      result <- sendAppServerRequest connection options request
      case result of
        Left failure -> pure (Left failure)
        Right _ -> sendAppServerRequestSession connection options rest

sendInitializedSession
  :: AppServerConnection
  -> AppServerClientOptions
  -> AppServerRequest
  -> (Value -> IO (Either AppServerClientFailure Value))
  -> IO (Either AppServerClientFailure Value)
sendInitializedSession connection options request continue = do
  result <- sendAppServerRequest connection options request
  case result of
    Left failure -> pure (Left failure)
    Right value -> do
      initializedResult <- sendAppServerNotification connection initializedNotification
      case initializedResult of
        Left failure -> pure (Left failure)
        Right () -> continue value

sendAppServerRequest :: AppServerConnection -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendAppServerRequest connection options request = do
  transportTry (WebSockets.sendTextData connection.unAppServerConnection (encode request :: LazyByteString.ByteString)) >>= \case
    Left message -> pure (Left (AppServerTransportFailure message))
    Right () -> receiveMatchedResponse connection options request

sendAppServerNotification :: AppServerConnection -> Value -> IO (Either AppServerClientFailure ())
sendAppServerNotification connection notification =
  transportTry (WebSockets.sendTextData connection.unAppServerConnection (encode notification :: LazyByteString.ByteString)) >>= \case
    Left message -> pure (Left (AppServerTransportFailure message))
    Right () -> pure (Right ())

startThreadWithSender
  :: Monad m
  => (AppServerRequest -> m (Either AppServerClientFailure Value))
  -> RequestId
  -> ThreadStartOptions
  -> m (Either AppServerClientFailure ThreadId)
startThreadWithSender send requestId options =
  (>>= parseThreadStartThreadId) <$> send (threadStartRequest requestId options)

transportTry :: IO a -> IO (Either Text a)
transportTry action =
  try action >>= \case
    Left (exception :: SomeException) ->
      case fromException exception of
        Just (asyncException :: AsyncException) -> throwIO asyncException
        Nothing -> pure (Left (Text.pack (displayException exception)))
    Right value ->
      pure (Right value)

appServerInterpreterFromEndpoint :: AppServerEndpoint -> AppServerClientOptions -> AppServerInterpreter IO
appServerInterpreterFromEndpoint endpoint options =
  AppServerInterpreter
    { appServerSendRequest = \request -> do
        result <- sendOneAppServerRequest endpoint options request
        case result of
          Right value -> pure value
          Left failure -> fail (Text.unpack (formatAppServerClientFailure failure))
    }

receiveMatchedResponse :: AppServerConnection -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
receiveMatchedResponse connection options request =
  withMaybeTimeout options.appServerResponseTimeoutMicros (go :: IO (Either AppServerClientFailure Value)) >>= \case
    Nothing -> pure (Left (AppServerResponseTimedOut request.requestId))
    Just result -> pure result
 where
  go = do
    messageResult <- receiveWebSocketMessage connection.unAppServerConnection
    case messageResult of
      Left failure -> pure (Left failure)
      Right bytes ->
        case decodeAppServerIncoming bytes >>= matchAppServerIncoming request of
          Left failure -> pure (Left failure)
          Right Nothing -> go
          Right (Just value) -> pure (Right value)

withMaybeTimeout :: Maybe Int -> IO a -> IO (Maybe a)
withMaybeTimeout Nothing action = Just <$> action
withMaybeTimeout (Just micros) action = timeout micros action

normalizedPath :: String -> String
normalizedPath "" = "/"
normalizedPath path@('/' : _) = path
normalizedPath path = "/" <> path

receiveWebSocketMessage :: WebSockets.Connection -> IO (Either AppServerClientFailure LazyByteString.ByteString)
receiveWebSocketMessage connection =
  transportTry (WebSockets.receiveData connection :: IO LazyByteString.ByteString) >>= \case
    Left message -> pure (Left (AppServerTransportFailure message))
    Right bytes -> pure (Right bytes)
