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
  ) where

import CodexWatcher.ActionExecutor (AppServerInterpreter (..))
import CodexWatcher.AppServerProtocol (AppServerRequest (..), initializeRequest)
import CodexWatcher.Types (ThreadId (..), TurnId (..))
import Control.Applicative ((<|>))
import Control.Exception (IOException, bracket, try)
import Data.Bits ((.&.), (.|.), shiftL, shiftR, xor)
import Data.Aeson
  ( FromJSON (..)
  , Object
  , Value (..)
  , eitherDecode'
  , encode
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import GHC.Generics (Generic)
import Data.Word (Word64, Word8)
import Network.Socket
  ( AddrInfo (..)
  , HostName
  , PortNumber
  , Socket
  , SocketType (Stream)
  , close
  , connect
  , defaultHints
  , getAddrInfo
  , socket
  , withSocketsDo
  )
import Network.Socket.ByteString qualified as SocketByteString
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
  { unAppServerConnection :: Socket
  }

data JsonRpcError = JsonRpcError
  { jsonRpcErrorCode :: Int
  , jsonRpcErrorMessage :: Text
  , jsonRpcErrorData :: Maybe Value
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON JsonRpcError where
  parseJSON = withObject "JsonRpcError" \objectValue ->
    JsonRpcError
      <$> objectValue .: "code"
      <*> objectValue .: "message"
      <*> objectValue .:? "data"

data AppServerIncoming
  = AppServerResponse Int Value
  | AppServerErrorResponse Int JsonRpcError
  | AppServerNotification Text Value
  deriving stock (Eq, Show, Generic)

data AppServerTurn = AppServerTurn
  { appServerTurnId :: TurnId
  , appServerTurnStatus :: Text
  , appServerTurnOutput :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON AppServerTurn where
  parseJSON = withObject "AppServerTurn" \objectValue ->
    AppServerTurn
      <$> (TurnId <$> turnIdField objectValue)
      <*> objectValue .:? "status" .!= "unknown"
      <*> optionalTurnOutput objectValue

instance FromJSON AppServerIncoming where
  parseJSON = withObject "AppServerIncoming" \objectValue -> do
    validateJsonRpcVersion objectValue
    maybeResponseId <- objectValue .:? "id"
    case maybeResponseId :: Maybe Int of
      Just responseId ->
        (AppServerErrorResponse responseId <$> objectValue .: "error")
          <|> (AppServerResponse responseId <$> objectValue .:? "result" .!= Null)
      Nothing ->
        AppServerNotification
          <$> objectValue .: "method"
          <*> objectValue .:? "params" .!= Null

data AppServerClientFailure
  = AppServerDecodeFailure Text
  | AppServerTransportFailure Text
  | AppServerResponseTimedOut Int
  | AppServerResponseIdMismatch Int Int
  | AppServerJsonRpcFailure Int JsonRpcError
  deriving stock (Eq, Show, Generic)

connectAppServer :: AppServerEndpoint -> (AppServerConnection -> IO a) -> IO a
connectAppServer endpoint action =
  withSocketsDo $
    bracket (openAppServerConnection endpoint) (close . unAppServerConnection) action

sendOneAppServerRequest :: AppServerEndpoint -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendOneAppServerRequest endpoint options request =
  try (connectAppServer endpoint \connection -> sendAppServerRequestSession connection options (appServerRequestSession request)) >>= \case
    Left (exception :: IOException) -> pure (Left (AppServerTransportFailure (Text.pack (show exception))))
    Right result -> pure result

appServerRequestSession :: AppServerRequest -> [AppServerRequest]
appServerRequestSession request
  | request.requestMethod == "initialize" = [request]
  | otherwise = [initializeRequest 0 "codex-watcher-hs" "0.1.0", request]

sendAppServerRequestSession :: AppServerConnection -> AppServerClientOptions -> [AppServerRequest] -> IO (Either AppServerClientFailure Value)
sendAppServerRequestSession _connection _options [] =
  pure (Right Null)
sendAppServerRequestSession connection options [request] =
  sendAppServerRequest connection options request
sendAppServerRequestSession connection options (request : rest) = do
  result <- sendAppServerRequest connection options request
  case result of
    Left failure -> pure (Left failure)
    Right _ -> sendAppServerRequestSession connection options rest

sendAppServerRequest :: AppServerConnection -> AppServerClientOptions -> AppServerRequest -> IO (Either AppServerClientFailure Value)
sendAppServerRequest connection options request = do
  sendResult <- try (sendWebSocketText connection.unAppServerConnection (encode request)) :: IO (Either IOException ())
  case sendResult of
    Left exception -> pure (Left (AppServerTransportFailure (Text.pack (show exception))))
    Right () -> receiveMatchedResponse connection options request

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

decodeAppServerIncoming :: LazyByteString.ByteString -> Either AppServerClientFailure AppServerIncoming
decodeAppServerIncoming bytes =
  case eitherDecode' bytes of
    Left errorMessage -> Left (AppServerDecodeFailure (Text.pack errorMessage))
    Right incoming -> Right incoming

decodeAppServerIncomingValue :: Value -> Either AppServerClientFailure AppServerIncoming
decodeAppServerIncomingValue value =
  case parseEither parseJSON value of
    Left errorMessage -> Left (AppServerDecodeFailure (Text.pack errorMessage))
    Right incoming -> Right incoming

matchAppServerIncoming :: AppServerRequest -> AppServerIncoming -> Either AppServerClientFailure (Maybe Value)
matchAppServerIncoming request = \case
  AppServerNotification {} ->
    Right Nothing
  AppServerResponse responseId result
    | responseId == request.requestId -> Right (Just result)
    | otherwise -> Left (AppServerResponseIdMismatch request.requestId responseId)
  AppServerErrorResponse responseId errorValue
    | responseId == request.requestId -> Left (AppServerJsonRpcFailure responseId errorValue)
    | otherwise -> Left (AppServerResponseIdMismatch request.requestId responseId)

parseThreadReadTurns :: Value -> Either AppServerClientFailure [AppServerTurn]
parseThreadReadTurns value =
  case parseEither threadReadTurnsParser value of
    Left errorMessage -> Left (AppServerDecodeFailure (Text.pack errorMessage))
    Right turns -> Right turns

parseTurnStartTurnId :: Value -> Either AppServerClientFailure TurnId
parseTurnStartTurnId value =
  case parseEither turnStartTurnIdParser value of
    Left errorMessage -> Left (AppServerDecodeFailure (Text.pack errorMessage))
    Right turnId -> Right turnId

parseThreadStartThreadId :: Value -> Either AppServerClientFailure ThreadId
parseThreadStartThreadId value =
  case parseEither threadStartThreadIdParser value of
    Left errorMessage -> Left (AppServerDecodeFailure (Text.pack errorMessage))
    Right threadId -> Right threadId

latestTurnById :: TurnId -> [AppServerTurn] -> Maybe AppServerTurn
latestTurnById turnId =
  foldl
    ( \found turn ->
        if appServerTurnId turn == turnId
          then Just turn
          else found
    )
    Nothing

formatAppServerClientFailure :: AppServerClientFailure -> Text
formatAppServerClientFailure = \case
  AppServerDecodeFailure message ->
    "app-server JSON decode failed: " <> message
  AppServerTransportFailure message ->
    "app-server transport failed: " <> message
  AppServerResponseTimedOut requestId ->
    "app-server response timed out for request id " <> Text.pack (show requestId)
  AppServerResponseIdMismatch expected actual ->
    "app-server response id mismatch: expected " <> Text.pack (show expected) <> ", got " <> Text.pack (show actual)
  AppServerJsonRpcFailure responseId errorValue ->
    "app-server JSON-RPC error for request id "
      <> Text.pack (show responseId)
      <> ": "
      <> errorValue.jsonRpcErrorMessage

validateJsonRpcVersion :: Object -> Parser ()
validateJsonRpcVersion objectValue = do
  maybeVersion <- objectValue .:? "jsonrpc"
  case maybeVersion :: Maybe Text of
    Nothing -> pure ()
    Just "2.0" -> pure ()
    Just other -> fail ("unsupported jsonrpc version: " <> Text.unpack other)

threadReadTurnsParser :: Value -> Parser [AppServerTurn]
threadReadTurnsParser = withObject "ThreadReadResult" \objectValue ->
  case KeyMap.lookup "turns" objectValue <|> lookupPath ["thread", "turns"] (Object objectValue) of
    Just turnsValue -> parseJSON turnsValue
    Nothing -> pure []

turnStartTurnIdParser :: Value -> Parser TurnId
turnStartTurnIdParser = withObject "TurnStartResult" \objectValue ->
  TurnId
    <$> ( objectValue .: "turnId"
            <|> objectValue .: "id"
            <|> nestedRequiredText ["turn", "turnId"] objectValue
            <|> nestedRequiredText ["turn", "id"] objectValue
        )

threadStartThreadIdParser :: Value -> Parser ThreadId
threadStartThreadIdParser = withObject "ThreadStartResult" \objectValue ->
  ThreadId
    <$> ( objectValue .: "threadId"
            <|> objectValue .: "id"
            <|> nestedRequiredText ["thread", "threadId"] objectValue
            <|> nestedRequiredText ["thread", "id"] objectValue
        )

turnIdField :: Object -> Parser Text
turnIdField objectValue =
  objectValue .: "id" <|> objectValue .: "turnId"

optionalTurnOutput :: Object -> Parser (Maybe Text)
optionalTurnOutput objectValue = do
  let output = fieldOutput "output" objectValue
      text = fieldOutput "text" objectValue
      resultOutput = nestedOutput ["result", "output"] objectValue
      resultText = nestedOutput ["result", "text"] objectValue
      result = fieldOutput "result" objectValue
  pure (output <|> text <|> resultOutput <|> resultText <|> result)

fieldOutput :: Text -> Object -> Maybe Text
fieldOutput key objectValue =
  turnOutputText =<< KeyMap.lookup (Key.fromText key) objectValue

nestedOutput :: [Text] -> Object -> Maybe Text
nestedOutput path objectValue =
  turnOutputText =<< lookupPath path (Object objectValue)

turnOutputText :: Value -> Maybe Text
turnOutputText = \case
  Null -> Nothing
  String text -> Just text
  value -> Just (Text.Encoding.decodeUtf8 (LazyByteString.toStrict (encode value)))

nestedRequiredText :: [Text] -> Object -> Parser Text
nestedRequiredText path objectValue =
  case lookupPath path (Object objectValue) of
    Just (String text) -> pure text
    _ -> fail ("missing text field: " <> Text.unpack (Text.intercalate "." path))

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (key : rest) (Object objectValue) = KeyMap.lookup (Key.fromText key) objectValue >>= lookupPath rest
lookupPath _ _ = Nothing

openAppServerConnection :: AppServerEndpoint -> IO AppServerConnection
openAppServerConnection endpoint = do
  addrInfo <- resolveEndpoint endpoint.appServerHost (fromIntegral endpoint.appServerPort)
  sock <- socket (addrFamily addrInfo) Stream (addrProtocol addrInfo)
  connect sock (addrAddress addrInfo)
  SocketByteString.sendAll sock (handshakeRequest endpoint)
  response <- readHttpHeaders sock ByteString.empty
  if isSwitchingProtocols response
    then pure (AppServerConnection sock)
    else fail ("app-server WebSocket handshake failed: " <> ByteString.Char8.unpack response)

resolveEndpoint :: HostName -> PortNumber -> IO AddrInfo
resolveEndpoint host port = do
  addrInfos <- getAddrInfo (Just defaultHints) (Just host) (Just (show port))
  case addrInfos of
    first : _ -> pure first
    [] -> fail ("could not resolve app-server host: " <> host)

handshakeRequest :: AppServerEndpoint -> ByteString.ByteString
handshakeRequest endpoint =
  ByteString.Char8.pack $
    "GET "
      <> normalizedPath endpoint.appServerPath
      <> " HTTP/1.1\r\n"
      <> "Host: "
      <> endpoint.appServerHost
      <> ":"
      <> show endpoint.appServerPort
      <> "\r\n"
      <> "Upgrade: websocket\r\n"
      <> "Connection: Upgrade\r\n"
      <> "Sec-WebSocket-Version: 13\r\n"
      <> "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
      <> "\r\n"

normalizedPath :: String -> String
normalizedPath "" = "/"
normalizedPath path@('/' : _) = path
normalizedPath path = "/" <> path

readHttpHeaders :: Socket -> ByteString.ByteString -> IO ByteString.ByteString
readHttpHeaders sock accumulated
  | "\r\n\r\n" `ByteString.isInfixOf` accumulated = pure accumulated
  | otherwise = do
      chunk <- SocketByteString.recv sock 4096
      if ByteString.null chunk
        then pure accumulated
        else readHttpHeaders sock (accumulated <> chunk)

isSwitchingProtocols :: ByteString.ByteString -> Bool
isSwitchingProtocols response =
  case ByteString.Char8.lines response of
    statusLine : _ -> " 101 " `ByteString.Char8.isInfixOf` statusLine || ByteString.Char8.isSuffixOf " 101" statusLine
    [] -> False

sendWebSocketText :: Socket -> LazyByteString.ByteString -> IO ()
sendWebSocketText sock lazyPayload =
  SocketByteString.sendAll sock (frameHeader <> maskedPayload)
 where
  payload = LazyByteString.toStrict lazyPayload
  payloadLength = ByteString.length payload
  maskKey = ByteString.pack [0x12, 0x34, 0x56, 0x78]
  (lengthByte, extendedLength) = encodedPayloadLength payloadLength
  frameHeader = ByteString.pack [0x81, 0x80 .|. lengthByte] <> extendedLength <> maskKey
  maskedPayload = maskPayload maskKey payload

encodedPayloadLength :: Int -> (Word8, ByteString.ByteString)
encodedPayloadLength payloadLength
  | payloadLength <= 125 =
      (fromIntegral payloadLength, ByteString.empty)
  | payloadLength <= 65535 =
      (126, word16Bytes payloadLength)
  | otherwise =
      (127, word64Bytes (fromIntegral payloadLength))

receiveWebSocketMessage :: Socket -> IO (Either AppServerClientFailure LazyByteString.ByteString)
receiveWebSocketMessage sock =
  try (receiveFrame sock) >>= \case
    Left (exception :: IOException) -> pure (Left (AppServerTransportFailure (Text.pack (show exception))))
    Right result -> pure result

receiveFrame :: Socket -> IO (Either AppServerClientFailure LazyByteString.ByteString)
receiveFrame sock = do
  header <- recvExactly sock 2
  let firstByte = ByteString.index header 0
      secondByte = ByteString.index header 1
      opcode = firstByte .&. 0x0f
      isMasked = secondByte .&. 0x80 /= 0
      initialLength = secondByte .&. 0x7f
  payloadLength <- readPayloadLength sock initialLength
  maskKey <- if isMasked then recvExactly sock 4 else pure ByteString.empty
  payload <- recvExactly sock payloadLength
  let decodedPayload = if isMasked then maskPayload maskKey payload else payload
  case opcode of
    0x1 -> pure (Right (LazyByteString.fromStrict decodedPayload))
    0x2 -> pure (Right (LazyByteString.fromStrict decodedPayload))
    0x8 -> pure (Left (AppServerTransportFailure "app-server closed WebSocket connection"))
    0x9 -> do
      sendPong sock decodedPayload
      receiveFrame sock
    0xA ->
      receiveFrame sock
    _ ->
      pure (Left (AppServerTransportFailure ("unsupported WebSocket opcode: " <> Text.pack (show opcode))))

readPayloadLength :: Socket -> Word8 -> IO Int
readPayloadLength sock initialLength
  | initialLength < 126 = pure (fromIntegral initialLength)
  | initialLength == 126 = word16FromBytes <$> recvExactly sock 2
  | otherwise = fromIntegral . word64FromBytes <$> recvExactly sock 8

recvExactly :: Socket -> Int -> IO ByteString.ByteString
recvExactly sock byteCount = go byteCount ByteString.empty
 where
  go remaining accumulated
    | remaining <= 0 = pure accumulated
    | otherwise = do
        chunk <- SocketByteString.recv sock remaining
        if ByteString.null chunk
          then fail "unexpected end of WebSocket stream"
          else go (remaining - ByteString.length chunk) (accumulated <> chunk)

sendPong :: Socket -> ByteString.ByteString -> IO ()
sendPong sock payload =
  SocketByteString.sendAll sock (ByteString.pack [0x8A, 0x80 .|. fromIntegral (ByteString.length payload)] <> maskKey <> maskPayload maskKey payload)
 where
  maskKey = ByteString.pack [0x87, 0x65, 0x43, 0x21]

maskPayload :: ByteString.ByteString -> ByteString.ByteString -> ByteString.ByteString
maskPayload maskKey payload =
  ByteString.pack (zipWith xor (ByteString.unpack payload) (cycle (ByteString.unpack maskKey)))

word16Bytes :: Int -> ByteString.ByteString
word16Bytes value =
  ByteString.pack
    [ fromIntegral (value `shiftR` 8)
    , fromIntegral value
    ]

word16FromBytes :: ByteString.ByteString -> Int
word16FromBytes bytes =
  (fromIntegral (ByteString.index bytes 0) `shiftL` 8) + fromIntegral (ByteString.index bytes 1)

word64Bytes :: Word64 -> ByteString.ByteString
word64Bytes value =
  ByteString.pack
    [ fromIntegral (value `shiftR` 56)
    , fromIntegral (value `shiftR` 48)
    , fromIntegral (value `shiftR` 40)
    , fromIntegral (value `shiftR` 32)
    , fromIntegral (value `shiftR` 24)
    , fromIntegral (value `shiftR` 16)
    , fromIntegral (value `shiftR` 8)
    , fromIntegral value
    ]

word64FromBytes :: ByteString.ByteString -> Word64
word64FromBytes bytes =
  foldl
    (\accumulator index -> (accumulator `shiftL` 8) + fromIntegral (ByteString.index bytes index))
    0
    [0 .. 7]
