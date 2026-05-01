{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.BlockedState
  ( blockedStateJson
  ) where

import CodexWatcher.Core.Reason (BlockedReason (..))
import Data.Aeson (Value, object, (.=))

blockedStateJson :: BlockedReason -> Value
blockedStateJson reason =
  object
    [ "blocked" .= True
    , "reason" .= unBlockedReason reason
    ]
