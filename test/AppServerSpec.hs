{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module AppServerSpec
  ( prop_appServerClientInitializesSingleRequestSessions
  , prop_appServerClientDetectsSystemErrorThreadStatus
  , prop_appServerClientMatchesSuccessResponse
  , prop_appServerClientMaterializationFallbackMarksSyntheticResponse
  , prop_appServerClientMaterializationFallbackRetriesWithoutTurns
  , prop_appServerClientParsesNestedThreadReadTurns
  , prop_appServerClientParsesThreadReadTurns
  , prop_appServerClientParsesThreadStartThreadId
  , prop_appServerClientStartsThreadWithInterpreter
  , prop_appServerClientParsesTurnStartTurnId
  , prop_appServerClientRejectsMismatchedResponseIds
  , prop_appServerClientRejectsUnsupportedJsonRpcVersion
  , prop_appServerClientSkipsNotifications
  , prop_appServerClientSurfacesJsonRpcErrors
  , prop_appServerInitializeRequestMatchesJsonRpc
  , prop_appServerInitializedNotificationMatchesJsonRpc
  , prop_appServerThreadReadAndInterruptUseThreadIds
  , prop_appServerThreadStartKeepsNodeNullFields
  , prop_appServerTurnStartOmitsAbsentOutputSchema
  , prop_appServerTurnStartPlanModeEncodesCollaborationMode
  ) where

import CodexWatcher.ActionExecutor (AppServerInterpreter (..))
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.RuntimeDefaults
import CodexWatcher.TurnClassifier (StructuredTurnOutcome (..), parseStructuredTurnOutcome)
import CodexWatcher.TurnOutput (structuredTurnOutputSchema)
import CodexWatcher.Types
import Data.Aeson (Value (..), object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Functor.Identity (Identity (..))
import Data.Text (Text)

prop_appServerInitializeRequestMatchesJsonRpc :: Bool
prop_appServerInitializeRequestMatchesJsonRpc =
  toJSON (initializeRequest (RequestId 1) "codex-script" "0.1.0")
    == object
      [ "jsonrpc" .= ("2.0" :: Text)
      , "id" .= (1 :: Int)
      , "method" .= ("initialize" :: Text)
      , "params" .= object
          [ "clientInfo" .= object ["name" .= ("codex-script" :: Text), "version" .= ("0.1.0" :: Text)]
          , "capabilities" .= object ["experimentalApi" .= True]
          ]
      ]

prop_appServerInitializedNotificationMatchesJsonRpc :: Bool
prop_appServerInitializedNotificationMatchesJsonRpc =
  initializedNotification
    == object
      [ "jsonrpc" .= ("2.0" :: Text)
      , "method" .= ("initialized" :: Text)
      , "params" .= object []
      ]

prop_appServerThreadStartKeepsNodeNullFields :: Bool
prop_appServerThreadStartKeepsNodeNullFields =
  let request =
        threadStartRequest
          (RequestId 2)
          (defaultThreadStartOptions "/workspace/repo" "developer")
   in request.requestMethod == "thread/start"
        && all
          (\key -> lookupValue key request.requestParams == Just Null)
          ["modelProvider", "baseInstructions", "config", "personality", "serviceTier", "serviceName"]
        && lookupValue "ephemeral" request.requestParams == Just (Bool False)

prop_appServerTurnStartPlanModeEncodesCollaborationMode :: ThreadId -> Bool
prop_appServerTurnStartPlanModeEncodesCollaborationMode threadId =
  let collaborationMode = planCollaborationMode "plan only" defaultModel defaultEffort
      request =
        turnStartRequest
          (RequestId 3)
          ( (defaultTurnStartOptions threadId "/workspace/repo" "write the plan")
              { turnOutputSchema = Just structuredTurnOutputSchema
              , turnCollaborationMode = Just collaborationMode
              }
          )
   in request.requestMethod == "turn/start"
        && lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
        && lookupValue "collaborationMode" request.requestParams == Just collaborationMode
        && lookupValue "sandboxPolicy" request.requestParams == Just (object ["type" .= ("dangerFullAccess" :: Text)])
        && lookupValue "summary" request.requestParams == Just Null
        && lookupValue "input" request.requestParams == Just (toJSON [object ["type" .= ("text" :: Text), "text" .= ("write the plan" :: Text)]])
        && lookupValue "outputSchema" request.requestParams == Just structuredTurnOutputSchema

prop_appServerTurnStartOmitsAbsentOutputSchema :: ThreadId -> Bool
prop_appServerTurnStartOmitsAbsentOutputSchema threadId =
  let request =
        turnStartRequest
          (RequestId 4)
          (defaultTurnStartOptions threadId "/workspace/repo" "write the plan")
   in request.requestMethod == "turn/start"
        && lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
        && lookupValue "outputSchema" request.requestParams == Nothing
        && lookupValue "collaborationMode" request.requestParams == Nothing

prop_appServerThreadReadAndInterruptUseThreadIds :: ThreadId -> TurnId -> Bool
prop_appServerThreadReadAndInterruptUseThreadIds threadId turnId =
  let readRequest = threadReadRequest (RequestId 4) threadId True
      interruptRequest = turnInterruptRequest (RequestId 5) threadId turnId
   in readRequest.requestMethod == "thread/read"
        && lookupValue "threadId" readRequest.requestParams == Just (String (unThreadId threadId))
        && lookupValue "includeTurns" readRequest.requestParams == Just (Bool True)
        && interruptRequest.requestMethod == "turn/interrupt"
        && lookupValue "threadId" interruptRequest.requestParams == Just (String (unThreadId threadId))
        && lookupValue "turnId" interruptRequest.requestParams == Just (String (unTurnId turnId))

prop_appServerClientInitializesSingleRequestSessions :: ThreadId -> Bool
prop_appServerClientInitializesSingleRequestSessions threadId =
  let request = threadReadRequest (RequestId 4) threadId True
      session = appServerRequestSession request
   in fmap requestMethod session == ["initialize", "thread/read"]
        && fmap requestId session == [RequestId 0, RequestId 4]
        && appServerRequestSession (initializeRequest (RequestId 10) "client" "1") == [initializeRequest (RequestId 10) "client" "1"]

prop_appServerClientDetectsSystemErrorThreadStatus :: Bool
prop_appServerClientDetectsSystemErrorThreadStatus =
  threadSystemError
    ( object
        [ "thread"
            .= object
              [ "status" .= object ["type" .= ("systemError" :: Text)]
              , "turns"
                  .= [ object
                        [ "id" .= ("turn-target" :: Text)
                        , "status" .= ("completed" :: Text)
                        ]
                     ]
              ]
        ]
    )
    == Just "systemError"

prop_appServerClientMatchesSuccessResponse :: Bool
prop_appServerClientMatchesSuccessResponse =
  let request = initializeRequest (RequestId 80) "codex-watcher-hs" "0.1.0"
      result = object ["server" .= ("ready" :: Text)]
      response = object ["jsonrpc" .= ("2.0" :: Text), "id" .= (80 :: Int), "result" .= result]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Right (Just value) -> value == result
        _ -> False

prop_appServerClientSkipsNotifications :: Bool
prop_appServerClientSkipsNotifications =
  let request = initializeRequest (RequestId 81) "codex-watcher-hs" "0.1.0"
      notification = object ["jsonrpc" .= ("2.0" :: Text), "method" .= ("turn/update" :: Text), "params" .= object ["status" .= ("running" :: Text)]]
   in case decodeAppServerIncomingValue notification >>= matchAppServerIncoming request of
        Right Nothing -> True
        _ -> False

prop_appServerClientRejectsMismatchedResponseIds :: Bool
prop_appServerClientRejectsMismatchedResponseIds =
  let request = initializeRequest (RequestId 82) "codex-watcher-hs" "0.1.0"
      response = object ["jsonrpc" .= ("2.0" :: Text), "id" .= (83 :: Int), "result" .= object []]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Left (AppServerResponseIdMismatch (RequestId 82) (RequestId 83)) -> True
        _ -> False

prop_appServerClientSurfacesJsonRpcErrors :: Bool
prop_appServerClientSurfacesJsonRpcErrors =
  let request = initializeRequest (RequestId 84) "codex-watcher-hs" "0.1.0"
      response =
        object
          [ "jsonrpc" .= ("2.0" :: Text)
          , "id" .= (84 :: Int)
          , "error" .= object ["code" .= (-32000 :: Int), "message" .= ("boom" :: Text)]
          ]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Left (AppServerJsonRpcFailure (RequestId 84) errorValue) ->
          jsonRpcErrorCode errorValue == -32000 && jsonRpcErrorMessage errorValue == "boom"
        _ -> False

prop_appServerClientMaterializationFallbackRetriesWithoutTurns :: ThreadId -> Bool
prop_appServerClientMaterializationFallbackRetriesWithoutTurns threadId =
  let request = threadReadRequest (RequestId 86) threadId True
      failure =
        AppServerJsonRpcFailure
          (RequestId 86)
          (JsonRpcError (-32000) "thread is not materialized yet; includeTurns is unavailable before first user message" Nothing)
   in threadReadFallbackRequest request failure == Just (threadReadRequest (RequestId 86) threadId False)

prop_appServerClientMaterializationFallbackMarksSyntheticResponse :: Bool
prop_appServerClientMaterializationFallbackMarksSyntheticResponse =
  threadReadMaterializationPending
    ( object
        [ "thread" .= object ["id" .= ("thread-created" :: Text)]
        , "_codexWatcherMaterializationPending" .= True
        ]
    )

prop_appServerClientRejectsUnsupportedJsonRpcVersion :: Bool
prop_appServerClientRejectsUnsupportedJsonRpcVersion =
  let response = object ["jsonrpc" .= ("1.0" :: Text), "id" .= (85 :: Int), "result" .= object []]
   in case decodeAppServerIncomingValue response of
        Left AppServerDecodeFailure {} -> True
        _ -> False

prop_appServerClientParsesThreadReadTurns :: Bool
prop_appServerClientParsesThreadReadTurns =
  let response =
        object
          [ "turns"
              .= [ object
                    [ "id" .= ("turn-old" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= ("old output" :: Text)
                    ]
                 , object
                    [ "turnId" .= ("turn-target" :: Text)
                    , "status" .= ("running" :: Text)
                    , "result" .= object ["text" .= ("target output" :: Text)]
                    ]
                 , object
                    [ "turnId" .= ("turn-target" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "result" .= object ["text" .= ("latest output" :: Text)]
                    ]
                 , object
                    [ "turnId" .= ("turn-structured" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= object ["outcome" .= ("blocked" :: Text), "reason" .= ("schema blocker" :: Text)]
                    ]
                 , object
                    [ "id" .= ("turn-agent-item" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "items"
                        .= [ object
                              [ "type" .= ("userMessage" :: Text)
                              , "content" .= [object ["type" .= ("text" :: Text), "text" .= ("prompt" :: Text)]]
                              ]
                           , object
                              [ "type" .= ("agentMessage" :: Text)
                              , "phase" .= ("final_answer" :: Text)
                              , "text" .= ("{\"outcome\":\"complete\",\"summary\":\"ok\"}" :: Text)
                              ]
                           ]
                    ]
                 ]
          ]
   in case parseThreadReadTurns response of
        Right turns ->
          latestTurnById (TurnId "turn-target") turns
            == Just (AppServerTurn (TurnId "turn-target") "completed" (Just "latest output"))
            && ( (parseStructuredTurnOutcome =<< (appServerTurnOutput =<< latestTurnById (TurnId "turn-structured") turns))
                   == Just (StructuredBlocked "schema blocker")
               )
            && ( (parseStructuredTurnOutcome =<< (appServerTurnOutput =<< latestTurnById (TurnId "turn-agent-item") turns))
                   == Just (StructuredComplete "ok")
               )
        Left _ -> False

prop_appServerClientParsesTurnStartTurnId :: Bool
prop_appServerClientParsesTurnStartTurnId =
  parseTurnStartTurnId (object ["turn" .= object ["id" .= ("turn-created" :: Text)]])
    == Right (TurnId "turn-created")

prop_appServerClientParsesThreadStartThreadId :: Bool
prop_appServerClientParsesThreadStartThreadId =
  parseThreadStartThreadId (object ["thread" .= object ["id" .= ("thread-created" :: Text)]])
    == Right (ThreadId "thread-created")

prop_appServerClientStartsThreadWithInterpreter :: Bool
prop_appServerClientStartsThreadWithInterpreter =
  let options = defaultThreadStartOptions "/workspace/repo" "developer"
      expectedRequest = threadStartRequest (RequestId 17) options
      interpreter =
        AppServerInterpreter
          ( \request ->
              Identity $
                if request == expectedRequest
                  then object ["thread" .= object ["id" .= ("thread-created" :: Text)]]
                  else error "unexpected thread/start request"
          )
   in runIdentity (startThreadWithInterpreter interpreter (RequestId 17) options)
        == Right (ThreadId "thread-created")

prop_appServerClientParsesNestedThreadReadTurns :: Bool
prop_appServerClientParsesNestedThreadReadTurns =
  parseThreadReadTurns
    ( object
        [ "thread"
            .= object
              [ "turns"
                  .= [ object
                        [ "id" .= ("turn-nested" :: Text)
                        , "status" .= ("completed" :: Text)
                        ]
                     ]
              ]
        ]
    )
    == Right [AppServerTurn (TurnId "turn-nested") "completed" Nothing]

lookupValue :: Text -> Value -> Maybe Value
lookupValue key (Object object') = KeyMap.lookup (Key.fromText key) object'
lookupValue _ _ = Nothing
