{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Workflow.Agent.Ids
  ( RequestId (..)
  , ThreadId (..)
  , TurnId (..)
  , nextRequestId
  ) where

import Data.Aeson (ToJSON (..))
import Data.Text (Text)

newtype ThreadId = ThreadId { unThreadId :: Text }
  deriving stock (Eq, Show)

newtype TurnId = TurnId { unTurnId :: Text }
  deriving stock (Eq, Show)

newtype RequestId = RequestId { unRequestId :: Int }
  deriving stock (Eq, Ord)

instance Show RequestId where
  show =
    show . unRequestId

instance ToJSON RequestId where
  toJSON =
    toJSON . unRequestId

nextRequestId :: RequestId -> RequestId
nextRequestId requestId =
  RequestId (unRequestId requestId + 1)
