{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module CodexWatcher.Protocol
  ( SessionPhase (..)
  , WorkerPurpose (..)
  , WorkerSession
  , WorkerOutcome (..)
  , newPrReviewWorkerSession
  , startWorkerTurn
  , startWorkerTurnEvent
  , waitWorkerTurn
  , emitWorkerEvent
  , runPrReviewWorkerProtocol
  ) where

import CodexWatcher.EventLog
import CodexWatcher.Types
import Data.List.NonEmpty (NonEmpty)

data SessionPhase
  = SessionIdle
  | SessionActive
  | SessionObserved
  | SessionFinished

data WorkerPurpose
  = FixPrReviewThreads
  deriving stock (Eq, Show)

data WorkerSession (phase :: SessionPhase) where
  PrReviewWorkerIdle
    :: PrConfig
    -> ThreadId
    -> NonEmpty ReviewThreadId
    -> CommitSha
    -> WorkerSession 'SessionIdle

  PrReviewWorkerActive
    :: PrConfig
    -> ActiveTurn
    -> NonEmpty ReviewThreadId
    -> CommitSha
    -> WorkerSession 'SessionActive

  PrReviewWorkerObserved
    :: PrConfig
    -> ActiveTurn
    -> WorkerOutcome
    -> WorkerSession 'SessionObserved

  PrReviewWorkerFinished
    :: PrConfig
    -> WorkerOutcome
    -> WatcherEvent
    -> WorkerSession 'SessionFinished

deriving stock instance Show (WorkerSession phase)

data WorkerOutcome
  = WorkerCompleted
  | WorkerBlocked BlockedReason
  deriving stock (Eq, Show)

newPrReviewWorkerSession :: PrConfig -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> WorkerSession 'SessionIdle
newPrReviewWorkerSession = PrReviewWorkerIdle

startWorkerTurn :: TurnId -> WorkerSession 'SessionIdle -> WorkerSession 'SessionActive
startWorkerTurn turnId (PrReviewWorkerIdle config threadId unresolved commit) =
  PrReviewWorkerActive config (ActiveTurn threadId turnId) unresolved commit

startWorkerTurnEvent :: TurnId -> WorkerSession 'SessionIdle -> (WorkerSession 'SessionActive, WatcherEvent)
startWorkerTurnEvent turnId session@(PrReviewWorkerIdle _config _threadId unresolved commit) =
  let active = startWorkerTurn turnId session
   in (active, PrReviewUnresolvedFound unresolved commit turnId)

waitWorkerTurn :: WorkerOutcome -> WorkerSession 'SessionActive -> WorkerSession 'SessionObserved
waitWorkerTurn outcome (PrReviewWorkerActive config activeTurn _unresolved _commit) =
  PrReviewWorkerObserved config activeTurn outcome

emitWorkerEvent :: WorkerSession 'SessionObserved -> WorkerSession 'SessionFinished
emitWorkerEvent (PrReviewWorkerObserved config _activeTurn outcome) =
  PrReviewWorkerFinished config outcome (eventForOutcome outcome)

runPrReviewWorkerProtocol :: TurnId -> WorkerOutcome -> WorkerSession 'SessionIdle -> (WorkerSession 'SessionFinished, [WatcherEvent])
runPrReviewWorkerProtocol turnId outcome session =
  let (active, startEvent) = startWorkerTurnEvent turnId session
      observed = waitWorkerTurn outcome active
      finished@(PrReviewWorkerFinished _ _ event) = emitWorkerEvent observed
   in (finished, [startEvent, event])

eventForOutcome :: WorkerOutcome -> WatcherEvent
eventForOutcome WorkerCompleted = PrReviewFixCompleted
eventForOutcome (WorkerBlocked reason) = WatcherBlocked reason
