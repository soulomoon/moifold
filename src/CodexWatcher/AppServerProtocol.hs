{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AppServerProtocol
  ( AppServerRequest (..)
  , ThreadStartOptions (..)
  , TurnStartOptions (..)
  , initializeRequest
  , planCollaborationMode
  , threadNameSetRequest
  , threadReadRequest
  , threadStartRequest
  , turnInterruptRequest
  , turnStartRequest
  ) where

import CodexWatcher.Types
  ( ThreadId (..)
  , TurnId (..)
  )
import Data.Aeson
  ( ToJSON (..)
  , Value (..)
  , object
  , (.=)
  )
import Data.Text (Text)
import GHC.Generics (Generic)

data AppServerRequest = AppServerRequest
  { requestId :: Int
  , requestMethod :: Text
  , requestParams :: Value
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON AppServerRequest where
  toJSON request =
    object
      [ "jsonrpc" .= String "2.0"
      , "id" .= request.requestId
      , "method" .= request.requestMethod
      , "params" .= request.requestParams
      ]

data ThreadStartOptions = ThreadStartOptions
  { threadCwd :: FilePath
  , threadApprovalPolicy :: Text
  , threadSandbox :: Text
  , threadModel :: Text
  , threadDeveloperInstructions :: Text
  }
  deriving stock (Eq, Show, Generic)

data TurnStartOptions = TurnStartOptions
  { turnThreadId :: ThreadId
  , turnCwd :: FilePath
  , turnEffort :: Text
  , turnModel :: Text
  , turnApprovalPolicy :: Text
  , turnSandboxPolicy :: Text
  , turnInput :: Text
  , turnOutputSchema :: Maybe Value
  , turnCollaborationMode :: Maybe Value
  }
  deriving stock (Eq, Show, Generic)

initializeRequest :: Int -> Text -> Text -> AppServerRequest
initializeRequest requestId clientName clientVersion =
  AppServerRequest
    { requestId
    , requestMethod = "initialize"
    , requestParams =
        object
          [ "clientInfo" .= object ["name" .= clientName, "version" .= clientVersion]
          , "capabilities" .= object ["experimentalApi" .= True]
          ]
    }

threadStartRequest :: Int -> ThreadStartOptions -> AppServerRequest
threadStartRequest requestId options =
  AppServerRequest
    { requestId
    , requestMethod = "thread/start"
    , requestParams =
        object
          [ "cwd" .= options.threadCwd
          , "approvalPolicy" .= options.threadApprovalPolicy
          , "sandbox" .= options.threadSandbox
          , "model" .= options.threadModel
          , "modelProvider" .= Null
          , "developerInstructions" .= options.threadDeveloperInstructions
          , "baseInstructions" .= Null
          , "config" .= Null
          , "ephemeral" .= False
          , "personality" .= Null
          , "serviceTier" .= Null
          , "serviceName" .= Null
          ]
    }

threadNameSetRequest :: Int -> ThreadId -> Text -> AppServerRequest
threadNameSetRequest requestId threadId name =
  AppServerRequest
    { requestId
    , requestMethod = "thread/name/set"
    , requestParams = object ["threadId" .= unThreadId threadId, "name" .= name]
    }

threadReadRequest :: Int -> ThreadId -> Bool -> AppServerRequest
threadReadRequest requestId threadId includeTurns =
  AppServerRequest
    { requestId
    , requestMethod = "thread/read"
    , requestParams = object ["threadId" .= unThreadId threadId, "includeTurns" .= includeTurns]
    }

turnStartRequest :: Int -> TurnStartOptions -> AppServerRequest
turnStartRequest requestId options =
  AppServerRequest
    { requestId
    , requestMethod = "turn/start"
    , requestParams =
        let baseFields =
              [ "threadId" .= unThreadId options.turnThreadId
              , "cwd" .= options.turnCwd
              , "effort" .= options.turnEffort
              , "model" .= options.turnModel
              , "approvalPolicy" .= options.turnApprovalPolicy
              , "sandboxPolicy" .= options.turnSandboxPolicy
              , "personality" .= Null
              , "serviceTier" .= Null
              , "summary" .= Null
              , "outputSchema" .= maybe Null id options.turnOutputSchema
              , "input" .= [object ["type" .= ("text" :: Text), "text" .= options.turnInput]]
              ]
            fields =
              case options.turnCollaborationMode of
                Nothing -> baseFields
                Just collaborationMode -> baseFields <> ["collaborationMode" .= collaborationMode]
         in object fields
    }

turnInterruptRequest :: Int -> ThreadId -> TurnId -> AppServerRequest
turnInterruptRequest requestId threadId turnId =
  AppServerRequest
    { requestId
    , requestMethod = "turn/interrupt"
    , requestParams =
        object
          [ "threadId" .= unThreadId threadId
          , "turnId" .= unTurnId turnId
          ]
    }

planCollaborationMode :: Text -> Text -> Text -> Value
planCollaborationMode developerInstructions model reasoningEffort =
  object
    [ "mode" .= ("plan" :: Text)
    , "settings" .= object
        [ "developer_instructions" .= developerInstructions
        , "model" .= model
        , "reasoning_effort" .= reasoningEffort
        ]
    ]
