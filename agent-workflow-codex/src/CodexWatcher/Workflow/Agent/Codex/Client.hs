{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Agent.Codex.Client
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
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest (..), threadReadRequest)
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))
import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON (..)
  , Object
  , Value (..)
  , eitherDecode'
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  , (.!=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable (toList)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import GHC.Generics (Generic)

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
  = AppServerResponse RequestId Value
  | AppServerErrorResponse RequestId JsonRpcError
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
        (AppServerErrorResponse (RequestId responseId) <$> objectValue .: "error")
          <|> (AppServerResponse (RequestId responseId) <$> objectValue .:? "result" .!= Null)
      Nothing ->
        AppServerNotification
          <$> objectValue .: "method"
          <*> objectValue .:? "params" .!= Null

data AppServerClientFailure
  = AppServerDecodeFailure Text
  | AppServerTransportFailure Text
  | AppServerResponseTimedOut RequestId
  | AppServerResponseIdMismatch RequestId RequestId
  | AppServerJsonRpcFailure RequestId JsonRpcError
  deriving stock (Eq, Show, Generic)

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

threadSystemError :: Value -> Maybe Text
threadSystemError value =
  let status =
        renderedTextAtPath ["thread", "status", "type"] value
          <|> renderedTextAtPath ["status", "type"] value
          <|> renderedTextAtPath ["thread", "status"] value
          <|> renderedTextAtPath ["status"] value
   in case Text.toLower . Text.strip <$> status of
        Just "systemerror" -> status
        Just "system_error" -> status
        _ -> Nothing

threadReadFallbackRequest :: AppServerRequest -> AppServerClientFailure -> Maybe AppServerRequest
threadReadFallbackRequest request = \case
  AppServerJsonRpcFailure _ errorValue
    | request.requestMethod == "thread/read"
    , lookupPath ["includeTurns"] request.requestParams == Just (Bool True)
    , jsonRpcErrorRequiresThreadReadFallback errorValue
    , Just threadIdText <- renderedTextAtPath ["threadId"] request.requestParams ->
        Just (threadReadRequest request.requestId (ThreadId threadIdText) False)
  _ ->
    Nothing

threadReadMaterializationPending :: Value -> Bool
threadReadMaterializationPending value =
  lookupPath [materializationPendingMarkerField] value == Just (Bool True)

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

markThreadReadMaterializationPending :: Value -> Value
markThreadReadMaterializationPending = \case
  Object objectValue ->
    Object (KeyMap.insert (Key.fromText materializationPendingMarkerField) (Bool True) objectValue)
  value ->
    object
      [ "value" .= value
      , Key.fromText materializationPendingMarkerField .= True
      ]

materializationPendingMarkerField :: Text
materializationPendingMarkerField =
  "_codexWatcherMaterializationPending"

jsonRpcErrorRequiresThreadReadFallback :: JsonRpcError -> Bool
jsonRpcErrorRequiresThreadReadFallback errorValue =
  let normalizedMessage = Text.toLower errorValue.jsonRpcErrorMessage
   in "not materialized yet" `Text.isInfixOf` normalizedMessage
        || "includeturns is unavailable before first user message" `Text.isInfixOf` normalizedMessage

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
      agentItems = agentItemsOutput objectValue
  pure (output <|> text <|> resultOutput <|> resultText <|> result <|> agentItems)

fieldOutput :: Text -> Object -> Maybe Text
fieldOutput key objectValue =
  turnOutputText =<< KeyMap.lookup (Key.fromText key) objectValue

nestedOutput :: [Text] -> Object -> Maybe Text
nestedOutput path objectValue =
  turnOutputText =<< lookupPath path (Object objectValue)

agentItemsOutput :: Object -> Maybe Text
agentItemsOutput objectValue =
  case KeyMap.lookup "items" objectValue of
    Just (Array items) ->
      lastMaybe (mapMaybe agentItemOutput (toList items))
    _ -> Nothing

agentItemOutput :: Value -> Maybe Text
agentItemOutput (Object item)
  | isAgentMessageItem item =
      nonEmptyText =<< (fieldOutput "text" item <|> fieldOutput "output" item <|> nestedOutput ["message", "text"] item <|> itemContentOutput item)
  | otherwise = Nothing
agentItemOutput _ = Nothing

isAgentMessageItem :: Object -> Bool
isAgentMessageItem item =
  case KeyMap.lookup "type" item of
    Just (String itemType) -> normalizedMessageType itemType `elem` ["agentmessage", "assistantmessage", "assistant"]
    _ -> False

itemContentOutput :: Object -> Maybe Text
itemContentOutput item =
  case KeyMap.lookup "content" item of
    Just (Array chunks) ->
      nonEmptyText =<< textFromChunks (toList chunks)
    Just value ->
      turnOutputText value
    Nothing -> Nothing

textFromChunks :: [Value] -> Maybe Text
textFromChunks chunks =
  case mapMaybe chunkText chunks of
    [] -> Nothing
    texts -> Just (Text.intercalate "\n" texts)

chunkText :: Value -> Maybe Text
chunkText (Object chunk) =
  fieldOutput "text" chunk <|> fieldOutput "content" chunk
chunkText value =
  turnOutputText value

normalizedMessageType :: Text -> Text
normalizedMessageType =
  Text.filter (/= '_') . Text.toLower . Text.strip

lastMaybe :: [a] -> Maybe a
lastMaybe =
  foldl (\_ item -> Just item) Nothing

nonEmptyText :: Text -> Maybe Text
nonEmptyText text
  | Text.null (Text.strip text) = Nothing
  | otherwise = Just text

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

renderedTextAtPath :: [Text] -> Value -> Maybe Text
renderedTextAtPath path value =
  case lookupPath path value of
    Just (String text) -> Just text
    Just other -> Just (Text.pack (show other))
    Nothing -> Nothing
