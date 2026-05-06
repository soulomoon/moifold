{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AppServerProtocol
  ( AppServerRequest (..)
  , ThreadStartOptions (..)
  , TurnStartOptions (..)
  , initializedNotification
  , initializeRequest
  , planCollaborationMode
  , threadNameSetRequest
  , threadReadRequest
  , threadStartRequest
  , turnInterruptRequest
  , turnStartRequest
  ) where

import CodexWatcher.Workflow.Agent.Ids
  ( RequestId (..)
  , ThreadId (..)
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
  { requestId :: RequestId
  , requestMethod :: Text
  , requestParams :: Value
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON AppServerRequest where
  toJSON request =
    object
      [ "jsonrpc" .= String "2.0"
      , "id" .= unRequestId request.requestId
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

initializeRequest :: RequestId -> Text -> Text -> AppServerRequest
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

initializedNotification :: Value
initializedNotification =
  object
    [ "jsonrpc" .= String "2.0"
    , "method" .= ("initialized" :: Text)
    , "params" .= object []
    ]

threadStartRequest :: RequestId -> ThreadStartOptions -> AppServerRequest
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

threadNameSetRequest :: RequestId -> ThreadId -> Text -> AppServerRequest
threadNameSetRequest requestId threadId name =
  AppServerRequest
    { requestId
    , requestMethod = "thread/name/set"
    , requestParams = object ["threadId" .= unThreadId threadId, "name" .= name]
    }

threadReadRequest :: RequestId -> ThreadId -> Bool -> AppServerRequest
threadReadRequest requestId threadId includeTurns =
  AppServerRequest
    { requestId
    , requestMethod = "thread/read"
    , requestParams = object ["threadId" .= unThreadId threadId, "includeTurns" .= includeTurns]
    }

turnStartRequest :: RequestId -> TurnStartOptions -> AppServerRequest
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
              , "sandboxPolicy" .= turnSandboxPolicyValue options.turnSandboxPolicy
              , "personality" .= Null
              , "serviceTier" .= Null
              , "summary" .= Null
              , "input" .= [object ["type" .= ("text" :: Text), "text" .= options.turnInput]]
              ]
            fields =
              maybe baseFields (\outputSchema -> baseFields <> ["outputSchema" .= outputSchema]) options.turnOutputSchema
                <> maybe [] (\collaborationMode -> ["collaborationMode" .= collaborationMode]) options.turnCollaborationMode
         in object fields
    }

turnInterruptRequest :: RequestId -> ThreadId -> TurnId -> AppServerRequest
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

turnSandboxPolicyValue :: Text -> Value
turnSandboxPolicyValue "danger-full-access" = object ["type" .= ("dangerFullAccess" :: Text)]
turnSandboxPolicyValue "dangerFullAccess" = object ["type" .= ("dangerFullAccess" :: Text)]
turnSandboxPolicyValue "read-only" = object ["type" .= ("readOnly" :: Text)]
turnSandboxPolicyValue "readOnly" = object ["type" .= ("readOnly" :: Text)]
turnSandboxPolicyValue "workspace-write" = object ["type" .= ("workspaceWrite" :: Text)]
turnSandboxPolicyValue "workspaceWrite" = object ["type" .= ("workspaceWrite" :: Text)]
turnSandboxPolicyValue other = object ["type" .= other]
