{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module TestSupport.AppServer
  ( withEndpointBackedAppServer
  , jsonRpcResult
  , jsonRpcError
  ) where

import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))
import Control.Concurrent (forkIO, killThread, threadDelay)
import Control.Exception (SomeException, bracketOnError, catch, finally)
import Data.Aeson
  ( Value (..)
  , eitherDecode'
  , encode
  , object
  , (.=)
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Text (Text)
import Data.Aeson.KeyMap qualified as KeyMap
import Network.Socket qualified as Socket
import Network.WebSockets qualified as WebSockets
import System.IO.Error (catchIOError)

withEndpointBackedAppServer :: (Value -> IO Value) -> (AppServerEndpoint -> IO [Value] -> IO a) -> IO a
withEndpointBackedAppServer responseFor action = do
  port <- findOpenPort
  requestsRef <- newIORef []
  serverThread <- forkIO (WebSockets.runServer "127.0.0.1" port (serverApp requestsRef responseFor))
  waitForServer port
  action (AppServerEndpoint "127.0.0.1" port "/") (readIORef requestsRef)
    `finally` killThread serverThread

jsonRpcResult :: Value -> Value -> Value
jsonRpcResult request resultValue =
  object
    [ "jsonrpc" .= ("2.0" :: Text)
    , "id" .= requestIdValue request
    , "result" .= resultValue
    ]

jsonRpcError :: Value -> Int -> Text -> Value
jsonRpcError request code message =
  object
    [ "jsonrpc" .= ("2.0" :: Text)
    , "id" .= requestIdValue request
    , "error" .= object ["code" .= code, "message" .= message]
    ]

serverApp :: IORef [Value] -> (Value -> IO Value) -> WebSockets.ServerApp
serverApp requestsRef responseFor pending = do
  connection <- WebSockets.acceptRequest pending
  loop connection `catch` \(_ :: SomeException) -> pure ()
 where
  loop connection = do
    bytes <- WebSockets.receiveData connection :: IO LazyByteString.ByteString
    case eitherDecode' bytes of
      Left _ ->
        loop connection
      Right request -> do
        recordRequest request
        case (requestMethod request, requestHasId request) of
          (Just "initialize", _) -> do
            WebSockets.sendTextData connection (encode (jsonRpcResult request (object [])) :: LazyByteString.ByteString)
            loop connection
          (_, False) ->
            loop connection
          (Just _, True) -> do
            response <- responseFor request
            WebSockets.sendTextData connection (encode response :: LazyByteString.ByteString)
            loop connection
          (Nothing, True) ->
            loop connection
  recordRequest request =
    atomicModifyIORef' requestsRef \requests -> (requests <> [request], ())

findOpenPort :: IO Int
findOpenPort =
  Socket.withSocketsDo $
    bracketOnError
      (Socket.socket Socket.AF_INET Socket.Stream Socket.defaultProtocol)
      Socket.close
      \socket -> do
        Socket.setSocketOption socket Socket.ReuseAddr 1
        Socket.bind socket (Socket.SockAddrInet 0 loopbackHostAddress)
        port <- Socket.socketPort socket
        Socket.close socket
        pure (fromIntegral port)

waitForServer :: Int -> IO ()
waitForServer port =
  go (50 :: Int)
 where
  go attempts
    | attempts <= 0 = pure ()
    | otherwise =
        tryConnect `catchIOError` \_ -> do
          threadDelay 20000
          go (attempts - 1)
  tryConnect =
    Socket.withSocketsDo $
      bracketOnError
        (Socket.socket Socket.AF_INET Socket.Stream Socket.defaultProtocol)
        Socket.close
        \socket -> do
          Socket.connect socket (Socket.SockAddrInet (fromIntegral port) loopbackHostAddress)
          Socket.close socket

loopbackHostAddress :: Socket.HostAddress
loopbackHostAddress =
  Socket.tupleToHostAddress (127, 0, 0, 1)

requestMethod :: Value -> Maybe Text
requestMethod (Object objectValue) =
  methodFromObject objectValue
requestMethod _ =
  Nothing

methodFromObject :: KeyMap.KeyMap Value -> Maybe Text
methodFromObject objectValue =
  case KeyMap.lookup "method" objectValue of
    Just (String method) -> Just method
    _ -> Nothing

requestIdValue :: Value -> Value
requestIdValue (Object objectValue) =
  case KeyMap.lookup "id" objectValue of
    Just value -> value
    Nothing -> Null
requestIdValue _ =
  Null

requestHasId :: Value -> Bool
requestHasId request =
  requestIdValue request /= Null
