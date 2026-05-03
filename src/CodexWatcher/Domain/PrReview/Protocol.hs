{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module CodexWatcher.Domain.PrReview.Protocol
  ( SessionPhase (..)
  , WorkerPurpose (..)
  , WorkerSession
  , WorkerOutcome (..)
  , ReviewerSession
  , ReviewerOutcome (..)
  , newPrReviewWorkerSession
  , newPrReviewReviewerSession
  , startWorkerTurn
  , startWorkerTurnEvent
  , waitWorkerTurn
  , emitWorkerEvent
  , runPrReviewWorkerProtocol
  , startReviewerTurn
  , startReviewerTurnEvent
  , waitReviewerTurn
  , emitReviewerEvent
  , runPrReviewReviewerProtocol
  ) where

import CodexWatcher.EventLog.Types
import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)
import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Core.Thread (ActiveTurn (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, PrConfig, ReviewEvidence)
import Data.Text (Text)

data SessionPhase
  = SessionIdle
  | SessionActive
  | SessionObserved
  | SessionFinished

data WorkerPurpose
  = FixPrReviewFeedback
  deriving stock (Eq, Show)

data WorkerSession (phase :: SessionPhase) where
  PrReviewWorkerIdle
    :: PrConfig
    -> ThreadId
    -> ReviewEvidence
    -> WorkerSession 'SessionIdle

  PrReviewWorkerActive
    :: PrConfig
    -> ActiveTurn
    -> ReviewEvidence
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

data ReviewerSession (phase :: SessionPhase) where
  PrReviewReviewerIdle
    :: PrConfig
    -> ThreadId
    -> CommitSha
    -> ReviewerSession 'SessionIdle

  PrReviewReviewerActive
    :: PrConfig
    -> ActiveTurn
    -> CommitSha
    -> ReviewerSession 'SessionActive

  PrReviewReviewerObserved
    :: PrConfig
    -> ActiveTurn
    -> ReviewerOutcome
    -> ReviewerSession 'SessionObserved

  PrReviewReviewerFinished
    :: PrConfig
    -> ReviewerOutcome
    -> WatcherEvent
    -> ReviewerSession 'SessionFinished

deriving stock instance Show (ReviewerSession phase)

data WorkerOutcome
  = WorkerCompleted
  | WorkerIncomplete Text
  | WorkerBlocked BlockedReason
  deriving stock (Eq, Show)

data ReviewerOutcome
  = ReviewerClean CleanReviewEvidence [ReviewThreadId]
  | ReviewerProblemsAdded ReviewEvidence [ReviewThreadId]
  | ReviewerIncomplete Text
  | ReviewerBlocked BlockedReason
  deriving stock (Eq, Show)

newPrReviewWorkerSession :: PrConfig -> ThreadId -> ReviewEvidence -> WorkerSession 'SessionIdle
newPrReviewWorkerSession = PrReviewWorkerIdle

newPrReviewReviewerSession :: PrConfig -> ThreadId -> CommitSha -> ReviewerSession 'SessionIdle
newPrReviewReviewerSession = PrReviewReviewerIdle

startWorkerTurn :: TurnId -> WorkerSession 'SessionIdle -> WorkerSession 'SessionActive
startWorkerTurn turnId (PrReviewWorkerIdle config threadId evidence) =
  PrReviewWorkerActive config (ActiveTurn threadId turnId) evidence

startWorkerTurnEvent :: TurnId -> WorkerSession 'SessionIdle -> (WorkerSession 'SessionActive, WatcherEvent)
startWorkerTurnEvent turnId session@(PrReviewWorkerIdle _config _threadId evidence) =
  let active = startWorkerTurn turnId session
   in (active, PrReviewFeedbackFound evidence turnId)

waitWorkerTurn :: WorkerOutcome -> WorkerSession 'SessionActive -> WorkerSession 'SessionObserved
waitWorkerTurn outcome (PrReviewWorkerActive config activeTurn _evidence) =
  PrReviewWorkerObserved config activeTurn outcome

emitWorkerEvent :: WorkerSession 'SessionObserved -> WorkerSession 'SessionFinished
emitWorkerEvent (PrReviewWorkerObserved config _activeTurn outcome) =
  PrReviewWorkerFinished config outcome (workerEventForOutcome outcome)

runPrReviewWorkerProtocol :: TurnId -> WorkerOutcome -> WorkerSession 'SessionIdle -> (WorkerSession 'SessionFinished, [WatcherEvent])
runPrReviewWorkerProtocol turnId outcome session =
  let (active, startEvent) = startWorkerTurnEvent turnId session
      observed = waitWorkerTurn outcome active
      finished@(PrReviewWorkerFinished _ _ event) = emitWorkerEvent observed
   in (finished, [startEvent, event])

startReviewerTurn :: TurnId -> ReviewerSession 'SessionIdle -> ReviewerSession 'SessionActive
startReviewerTurn turnId (PrReviewReviewerIdle config threadId commit) =
  PrReviewReviewerActive config (ActiveTurn threadId turnId) commit

startReviewerTurnEvent :: TurnId -> ReviewerSession 'SessionIdle -> (ReviewerSession 'SessionActive, WatcherEvent)
startReviewerTurnEvent turnId session@(PrReviewReviewerIdle _config _threadId commit) =
  let active = startReviewerTurn turnId session
   in (active, PrReviewNoUnresolvedFound commit turnId)

waitReviewerTurn :: ReviewerOutcome -> ReviewerSession 'SessionActive -> ReviewerSession 'SessionObserved
waitReviewerTurn outcome (PrReviewReviewerActive config activeTurn _commit) =
  PrReviewReviewerObserved config activeTurn outcome

emitReviewerEvent :: ReviewerSession 'SessionObserved -> ReviewerSession 'SessionFinished
emitReviewerEvent (PrReviewReviewerObserved config _activeTurn outcome) =
  PrReviewReviewerFinished config outcome (reviewerEventForOutcome outcome)

runPrReviewReviewerProtocol :: TurnId -> ReviewerOutcome -> ReviewerSession 'SessionIdle -> (ReviewerSession 'SessionFinished, [WatcherEvent])
runPrReviewReviewerProtocol turnId outcome session =
  let (active, startEvent) = startReviewerTurnEvent turnId session
      observed = waitReviewerTurn outcome active
      finished@(PrReviewReviewerFinished _ _ event) = emitReviewerEvent observed
   in (finished, [startEvent, event])

workerEventForOutcome :: WorkerOutcome -> WatcherEvent
workerEventForOutcome WorkerCompleted = PrReviewFixCompleted
workerEventForOutcome (WorkerIncomplete reason) = PrReviewFixIncomplete reason
workerEventForOutcome (WorkerBlocked reason) = WatcherBlocked reason

reviewerEventForOutcome :: ReviewerOutcome -> WatcherEvent
reviewerEventForOutcome (ReviewerClean evidence resolvedThreadIds) = PrReviewCleanFound evidence resolvedThreadIds
reviewerEventForOutcome (ReviewerProblemsAdded evidence resolvedThreadIds) = PrReviewProblemsAdded evidence resolvedThreadIds
reviewerEventForOutcome (ReviewerIncomplete reason) = PrReviewReviewIncomplete reason
reviewerEventForOutcome (ReviewerBlocked reason) = WatcherBlocked reason
