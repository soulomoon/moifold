{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RuntimeDefaults
  ( defaultApprovalPolicy
  , defaultEffort
  , defaultModel
  , defaultPlanCollaborationMode
  , defaultSandboxPolicy
  , defaultThreadStartOptions
  , defaultTurnStartOptions
  ) where

import CodexWatcher.AppServerProtocol
  ( ThreadStartOptions (..)
  , TurnStartOptions (..)
  , planCollaborationMode
  )
import CodexWatcher.Types (ThreadId)
import Data.Text (Text)
import Data.Aeson (Value)

defaultModel :: Text
defaultModel = "gpt-5.4"

defaultEffort :: Text
defaultEffort = "xhigh"

defaultApprovalPolicy :: Text
defaultApprovalPolicy = "never"

defaultSandboxPolicy :: Text
defaultSandboxPolicy = "danger-full-access"

defaultThreadStartOptions :: FilePath -> Text -> ThreadStartOptions
defaultThreadStartOptions cwd developerInstructions =
  ThreadStartOptions
    { threadCwd = cwd
    , threadApprovalPolicy = defaultApprovalPolicy
    , threadSandbox = defaultSandboxPolicy
    , threadModel = defaultModel
    , threadDeveloperInstructions = developerInstructions
    }

defaultTurnStartOptions :: ThreadId -> FilePath -> Text -> TurnStartOptions
defaultTurnStartOptions threadId cwd input =
  TurnStartOptions
    { turnThreadId = threadId
    , turnCwd = cwd
    , turnEffort = defaultEffort
    , turnModel = defaultModel
    , turnApprovalPolicy = defaultApprovalPolicy
    , turnSandboxPolicy = defaultSandboxPolicy
    , turnInput = input
    , turnOutputSchema = Nothing
    , turnCollaborationMode = Nothing
    }

defaultPlanCollaborationMode :: Text -> Value
defaultPlanCollaborationMode developerInstructions =
  planCollaborationMode developerInstructions defaultModel defaultEffort
