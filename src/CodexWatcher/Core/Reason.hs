{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Core.Reason
  ( BlockedReason (..)
  , StopReason (..)
  ) where

import Data.Text (Text)

newtype BlockedReason = BlockedReason { unBlockedReason :: Text }
  deriving stock (Eq, Show)

newtype StopReason = StopReason { unStopReason :: Text }
  deriving stock (Eq, Show)
