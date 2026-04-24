{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE StandaloneDeriving #-}

module CodexWatcher.Core.Thread
  ( ActiveTurn (..)
  , WorkerThread (..)
  , ReviewerThread (..)
  ) where

import CodexWatcher.Core.Ids (ThreadId, TurnId)
import CodexWatcher.Core.Kinds (ThreadActivity (..))

data ActiveTurn = ActiveTurn
  { activeThreadId :: ThreadId
  , activeTurnId :: TurnId
  }
  deriving stock (Eq, Show)

data WorkerThread (activity :: ThreadActivity) where
  WorkerIdle :: ThreadId -> WorkerThread 'Idle
  WorkerActive :: ActiveTurn -> WorkerThread 'Active

deriving stock instance Eq (WorkerThread activity)
deriving stock instance Show (WorkerThread activity)

data ReviewerThread (activity :: ThreadActivity) where
  ReviewerIdle :: ThreadId -> ReviewerThread 'Idle
  ReviewerActive :: ActiveTurn -> ReviewerThread 'Active

deriving stock instance Eq (ReviewerThread activity)
deriving stock instance Show (ReviewerThread activity)
