{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoop.PrReviewHandoff
  ( issueImplementReviewHandoffAfterTick
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode)
import CodexWatcher.AppServerClient (AppServerEndpoint)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.CompatibilityRuntime (writeCompatibility)
import CodexWatcher.CompatibilityState (compatibilityStateWrites)
import CodexWatcher.Daemon (DaemonObservedTickResult (..), appendWatcherEvent)
import CodexWatcher.DaemonLoop (DaemonLoopTickResult (..))
import CodexWatcher.EventLog (EventReplayResult (..), WatcherEvent (..))
import CodexWatcher.Domain.IssueImplement.Watcher (IssueImplementObservation (..), IssueImplementTick (..), issueImplementObserve)
import CodexWatcher.Domain.PrReview.LaunchCli (ensurePrReviewWatcherForHandoff)
import CodexWatcher.Runtime (ioRuntimeInterpreter)
import CodexWatcher.Types
import Data.Text qualified as Text
import System.Exit (die)

issueImplementReviewHandoffAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO ()
issueImplementReviewHandoffAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, tick.loopObservedTick) of
    (IssueImplement, Just observedTick)
      | IssueReviewHandoffStartedEvent prNumber <- observedTick.daemonObservedEvent
      , Just (issueConfig, handoffPr) <- issueWaitingForPrMerge observedTick.daemonObservedState
      , handoffPr == prNumber ->
          ensurePrReviewWatcherOrBlock observedTick.daemonObservedState issueConfig prNumber
      | IssueReviewHandoffStartedEvent prNumber <- observedTick.daemonObservedEvent
      , Just (_issueConfig, handoffPr) <- issueWaitingForPrMerge observedTick.daemonObservedState
      , handoffPr /= prNumber ->
          blockIssueImplementerHandoff
            cli
            observedTick.daemonObservedState
            ( BlockedReason
                ( "PR review handoff PR number mismatch: expected #"
                    <> Text.pack (show (unPrNumber handoffPr))
                    <> ", actual #"
                    <> Text.pack (show (unPrNumber prNumber))
                )
            )
    (IssueImplement, _) ->
      case issueWaitingForPrMerge tick.loopReplayResult.replayState of
        Just (issueConfig, prNumber) ->
          ensurePrReviewWatcherOrBlock tick.loopReplayResult.replayState issueConfig prNumber
        Nothing ->
          pure ()
    _ ->
      pure ()
 where
  ensurePrReviewWatcherOrBlock state issueConfig prNumber =
    ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber
      >>= mapM_ (blockIssueImplementerHandoff cli state)

blockIssueImplementerHandoff :: LoopCli -> SomeWatcherState -> BlockedReason -> IO ()
blockIssueImplementerHandoff cli state reason =
  case cli.loopCliExecute of
    False ->
      putStrLn ("would block issue implementer: " <> Text.unpack reason.unBlockedReason)
    True ->
      case issueImplementObserve state (ObservedIssueImplementBlocked reason) of
        Left failure ->
          die ("failed to block issue implementer after PR review handoff: " <> Text.unpack failure)
        Right blockedTick -> do
          appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath blockedTick.issueImplementTickEvent
          mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir blockedTick.issueImplementTickState)
          putStrLn ("blocked issue implementer: " <> Text.unpack reason.unBlockedReason)

issueWaitingForPrMerge :: SomeWatcherState -> Maybe (IssueConfig, PrNumber)
issueWaitingForPrMerge (SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber)) =
  Just (issueConfig, prNumber)
issueWaitingForPrMerge _ =
  Nothing
