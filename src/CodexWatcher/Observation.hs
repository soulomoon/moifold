{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Observation
  ( ObservedTick (..)
  , invalidObservation
  , observedFromDecision
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Text (Text)
import Data.Text qualified as Text

data ObservedTick = ObservedTick
  { observedEvent :: WatcherEvent
  , observedState :: SomeWatcherState
  , observedEffects :: EffectPlan
  }
  deriving stock (Show)

observedFromDecision :: KnownDomain domain => WatcherEvent -> Decision domain -> ObservedTick
observedFromDecision event (Decision state effects) =
  ObservedTick
    { observedEvent = event
    , observedState = SomeWatcherState state
    , observedEffects = effects
    }

invalidObservation :: Show observation => Text -> SomeWatcherState -> observation -> Either Text a
invalidObservation label state observation =
  Left
    ( label
        <> " "
        <> Text.pack (show observation)
        <> " is invalid in "
        <> Text.pack (show (someDomain state))
        <> "/"
        <> Text.pack (show (somePhase state))
    )
