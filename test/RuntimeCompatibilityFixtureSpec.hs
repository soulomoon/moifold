{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module RuntimeCompatibilityFixtureSpec
  ( runtimeCompatibilityFixtureTests
  ) where

import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))
import CodexWatcher.Core.Kinds (Domain (..), Phase (..))
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (CompletionEvidence (..), SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..))
import CodexWatcher.Domain.IssuePlanning.Types
  ( BlockedPlanningIssue (..)
  , IssueDependency (..)
  , PlannerConfig (..)
  , PlanningGraph (..)
  )
import CodexWatcher.EffectInterpreter (CompiledEffectPlan (..), EffectRuntimeConfig (..), PlannedAction (..), compileEffectPlan)
import CodexWatcher.Effects (Effect (..), SomeEffect (..))
import CodexWatcher.EventLog.Types (ReplayFailure (..), WatcherEvent (..), eventName)
import CodexWatcher.EventLogRepair (repairFailureBlockStateJson)
import CodexWatcher.Runtime.BlockedState (blockedStateJson)
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.Runtime.Paths (runtimeStateDirFile)
import CodexWatcher.Snapshot (NodeBlockedState (..), NodeIssueDaemonState (..))
import Data.Aeson (Value (..), eitherDecodeStrict', object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.Either (isRight)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.FilePath ((</>))
import TestSupport.Workflow (assert, effectRuntimeConfig, maxParallelForTest, sequenceAnd)

runtimeCompatibilityFixtureTests :: IO Bool
runtimeCompatibilityFixtureTests =
  sequenceAnd
    [ fixtureShapeTests
    , daemonFixtureShapeTests
    , compatibilityProjectionFixtureTests
    , daemonCompatibilityProjectionFixtureTests
    , blockStateRepairFailureFixtureTests
    , blockStateCompatibilityShapeTests
    , recordPlanningGraphFixtureTest
    , healthcheckPlannerReaderBoundaryTest
    , daemonStateSourceBoundaryTest
    , blockStateSourceBoundaryTest
    ]

fixtureShapeTests :: IO Bool
fixtureShapeTests = do
  readyResult <- loadFixtureValue ("planner-ready" </> "planner-state.json")
  activeResult <- loadFixtureValue ("planner-active" </> "planner-state.json")
  waitingPlannerResult <- loadFixtureValue ("planner-waiting-ready-issues" </> "planner-state.json")
  planningResult <- loadFixtureValue ("planner-waiting-ready-issues" </> "planning-state.json")
  completeResult <- loadFixtureValue ("planner-complete" </> "planner-state.json")
  planningGraphResult <- loadPlanningGraphFixture ("planner-waiting-ready-issues" </> "planning-state.json")
  decodedOk <-
    assert
      "runtime compatibility planner/planning fixtures decode as JSON values"
      (all isRight [readyResult, activeResult, waitingPlannerResult, planningResult, completeResult])
  planningGraphOk <-
    assert
      "planning-state fixture decodes as the deterministic PlanningGraph"
      (planningGraphResult == Right fixturePlanningGraph)
  shapeOk <-
    case sequence [readyResult, activeResult, waitingPlannerResult, planningResult, completeResult] of
      Left _ -> pure False
      Right [readyValue, activeValue, waitingPlannerValue, planningValue, completeValue] ->
        sequenceAnd
          [ assert
              "planner-state fixtures match current summary/status JSON shapes"
              ( readyValue == plannerStateValue "ready"
                  && activeValue == plannerStateValue "active"
                  && waitingPlannerValue == plannerStateValue "waiting_ready_issues"
                  && completeValue == completePlannerStateValue
              )
          , assert
              "planning-state fixture matches current PlanningGraph JSON shape"
              (planningValue == toJSON fixturePlanningGraph)
          , assert
              "planner-state and planning-state fixture shapes are not interchangeable"
              ( all hasPlannerStatusKey [readyValue, activeValue, waitingPlannerValue, completeValue]
                  && all (not . hasPlanningGraphKey) [readyValue, activeValue, waitingPlannerValue, completeValue]
                  && hasPlanningGraphKey planningValue
                  && not (hasPlannerStatusKey planningValue)
                  && planningValue `notElem` [readyValue, activeValue, waitingPlannerValue, completeValue]
              )
          ]
      Right _ -> pure False
  pure (decodedOk && planningGraphOk && shapeOk)

compatibilityProjectionFixtureTests :: IO Bool
compatibilityProjectionFixtureTests =
  sequenceAnd
    [ assert
        "PlanningReady writes the ready planner-state fixture and no planning-state"
        (writesOnlyPlannerState (SomeWatcherState (PlanningReady fixturePlannerConfig)) (plannerStateValue "ready"))
    , assert
        "PlanningTurnActive writes the active planner-state fixture and no planning-state"
        ( writesOnlyPlannerState
            (SomeWatcherState (PlanningTurnActive fixturePlannerConfig (ActiveTurn (ThreadId "planner-thread") (TurnId "planner-turn"))))
            (plannerStateValue "active")
        )
    , assert
        "PlanningWaitingForReadyIssues writes distinct planner-state and planning-state fixtures"
        ( let writes = compatibilityStateWrites fixtureStateDir (SomeWatcherState (PlanningWaitingForReadyIssues fixturePlannerConfig fixturePlanningGraph))
           in singleWriteValue fixturePlannerPath writes == Just (plannerStateValue "waiting_ready_issues")
                && singleWriteValue fixturePlanningPath writes == Just (toJSON fixturePlanningGraph)
                && singleWriteValue fixturePlannerPath writes /= singleWriteValue fixturePlanningPath writes
        )
    , assert
        "PlanningComplete writes the complete planner-state fixture and no planning-state"
        (writesOnlyPlannerState (SomeWatcherState (CompleteState PlanningComplete)) completePlannerStateValue)
    ]

daemonFixtureShapeTests :: IO Bool
daemonFixtureShapeTests = do
  activeResult <- loadDaemonFixtureValue ("planning-active" </> "daemon-state.json")
  stoppedResult <- loadDaemonFixtureValue ("stopped" </> "daemon-state.json")
  activeDecodeResult <- loadDaemonFixtureState ("planning-active" </> "daemon-state.json")
  stoppedDecodeResult <- loadDaemonFixtureState ("stopped" </> "daemon-state.json")
  decodedOk <-
    assert
      "runtime compatibility daemon fixtures decode as JSON values"
      (all isRight [activeResult, stoppedResult])
  snapshotReaderOk <-
    assert
      "issue-implementation snapshot daemon reader accepts active and stopped daemon fixtures"
      ( activeDecodeResult == Right (NodeIssueDaemonState (Just "daemon-turn") (Just "plan") Nothing)
          && stoppedDecodeResult == Right (NodeIssueDaemonState Nothing Nothing Nothing)
      )
  shapeOk <-
    case (activeResult, stoppedResult) of
      (Right activeValue, Right stoppedValue) ->
        sequenceAnd
          [ assert
              "daemon active and stopped fixtures match current daemon-state JSON shapes"
              ( activeValue == activeDaemonStateValue
                  && stoppedValue == stoppedDaemonStateValue
              )
          , assert
              "daemon active and stopped fixture shapes are not interchangeable"
              ( activeValue /= stoppedValue
                  && hasObjectKey "activeThreadId" activeValue
                  && not (hasObjectKey "stopReason" activeValue)
                  && hasObjectKey "stopReason" stoppedValue
                  && not (hasObjectKey "activeThreadId" stoppedValue)
              )
          ]
      _ -> pure False
  pure (decodedOk && snapshotReaderOk && shapeOk)

daemonCompatibilityProjectionFixtureTests :: IO Bool
daemonCompatibilityProjectionFixtureTests =
  sequenceAnd
    [ assert
        "PlanningTurnActive writes the active daemon-state fixture"
        ( singleWriteValue
            fixtureDaemonPath
            ( compatibilityStateWrites
                fixtureStateDir
                (SomeWatcherState (PlanningTurnActive fixturePlannerConfig (ActiveTurn (ThreadId "daemon-thread") (TurnId "daemon-turn"))))
            )
            == Just activeDaemonStateValue
        )
    , assert
        "StoppedState writes the stopped daemon-state fixture"
        ( singleWriteValue
            fixtureDaemonPath
            ( compatibilityStateWrites
                fixtureStateDir
                (SomeWatcherState (StoppedState (StopReason "stopped for fixture") :: WatcherState 'IssuePlanning 'Stopped))
            )
            == Just stoppedDaemonStateValue
        )
    , assert
        "active and stopped daemon compatibility writes are not interchangeable"
        ( let activeWrites =
                compatibilityStateWrites
                  fixtureStateDir
                  (SomeWatcherState (PlanningTurnActive fixturePlannerConfig (ActiveTurn (ThreadId "daemon-thread") (TurnId "daemon-turn"))))
              stoppedWrites =
                compatibilityStateWrites
                  fixtureStateDir
                  (SomeWatcherState (StoppedState (StopReason "stopped for fixture") :: WatcherState 'IssuePlanning 'Stopped))
           in singleWriteValue fixtureDaemonPath activeWrites == Just activeDaemonStateValue
                && singleWriteValue fixtureDaemonPath stoppedWrites == Just stoppedDaemonStateValue
                && singleWriteValue fixtureDaemonPath activeWrites /= singleWriteValue fixtureDaemonPath stoppedWrites
        )
    ]

blockStateRepairFailureFixtureTests :: IO Bool
blockStateRepairFailureFixtureTests = do
  fixtureResult <- loadBlockStateFixtureValue ("repair-failure" </> "block-state.json")
  blockedStateResult <- loadBlockStateFixtureState ("repair-failure" </> "block-state.json")
  decodedOk <-
    assert
      "runtime compatibility repair-failure block-state fixture decodes as JSON"
      (isRight fixtureResult)
  snapshotReaderOk <-
    assert
      "snapshot blocked-state reader accepts repair-failure block-state fixture"
      (blockedStateResult == Right (NodeBlockedState True (Just fixtureReplayFailure.reason)))
  shapeOk <-
    case fixtureResult of
      Right fixtureValue ->
        sequenceAnd
          [ assert
              "repair-failure block-state fixture matches current generator output"
              (fixtureValue == repairFailureBlockStateJson fixtureReplayFailure)
          , assert
              "repair-failure block-state fixture keeps invalid-event-log fields"
              ( lookupObjectKey "blockedKind" fixtureValue == Just (String "invalid_event_log")
                  && lookupObjectKey "eventIndex" fixtureValue == Just (Number 3)
                  && lookupObjectKey "eventType" fixtureValue == Just (String (eventName fixtureReplayFailure.event))
                  && lookupObjectKey "event" fixtureValue == Just (toJSON fixtureReplayFailure.event)
              )
          , assert
              "repair-failure block-state embedded event keeps current event type"
              (case lookupObjectKey "event" fixtureValue of
                Just eventValue ->
                  lookupObjectKey "type" eventValue == Just (String (eventName fixtureReplayFailure.event))
                _ -> False
              )
          ]
      Left _ -> pure False
  pure (decodedOk && snapshotReaderOk && shapeOk)

blockStateCompatibilityShapeTests :: IO Bool
blockStateCompatibilityShapeTests = do
  fixtureResult <- loadBlockStateFixtureValue ("repair-failure" </> "block-state.json")
  case fixtureResult of
    Left _ -> pure False
    Right fixtureValue -> do
      let blockedReason = BlockedReason fixtureReplayFailure.reason
          normalBlockStateValue = blockedStateJson blockedReason
          config = effectRuntimeConfig fixtureRepo "/tmp/runtime-compatibility-fixture-workdir" 1
          directBlockPath = runtimeStateDirFile config.effectRuntimeStateDir "block-state.json"
          compiled = compileEffectPlan config [SomeEffect (RecordBlocked blockedReason)]
          compatibilityWrites =
            compatibilityStateWrites
              fixtureStateDir
              (SomeWatcherState (BlockedState blockedReason :: WatcherState 'IssuePlanning 'Blocked))
      sequenceAnd
        [ assert
            "normal blocked-state JSON is not interchangeable with repair-failure fixture"
            ( normalBlockStateValue /= fixtureValue
                && objectLacksKeys ["blockedKind", "eventIndex", "eventType", "event"] normalBlockStateValue
            )
        , assert
            "BlockedState compatibility projection keeps the normal block-state shape"
            ( singleWriteValue fixtureBlockStatePath compatibilityWrites == Just normalBlockStateValue
                && singleWriteValue fixtureBlockStatePath compatibilityWrites /= Just fixtureValue
                && maybe False (objectLacksKeys ["blockedKind", "eventIndex", "eventType", "event"]) (singleWriteValue fixtureBlockStatePath compatibilityWrites)
            )
        , assert
            "RecordBlocked compiled effect keeps the normal block-state shape"
            ( compiled.compiledActions == [PlannedWriteJson directBlockPath normalBlockStateValue]
                && compiled.compiledActions /= [PlannedWriteJson directBlockPath fixtureValue]
                && objectLacksKeys ["blockedKind", "eventIndex", "eventType", "event"] normalBlockStateValue
            )
        ]

recordPlanningGraphFixtureTest :: IO Bool
recordPlanningGraphFixtureTest = do
  let config = effectRuntimeConfig fixtureRepo "/tmp/runtime-compatibility-fixture-workdir" 1
      compiled = compileEffectPlan config [SomeEffect (RecordPlanningGraph fixturePlanningGraph)]
      planningPath = runtimeStateDirFile config.effectRuntimeStateDir "planning-state.json"
      plannerPath = runtimeStateDirFile config.effectRuntimeStateDir "planner-state.json"
  assert
    "RecordPlanningGraph writes only the planning-state graph fixture shape"
    ( compiled.compiledActions == [PlannedWriteJson planningPath (toJSON fixturePlanningGraph)]
        && all (/= PlannedWriteJson plannerPath (toJSON fixturePlanningGraph)) compiled.compiledActions
    )

healthcheckPlannerReaderBoundaryTest :: IO Bool
healthcheckPlannerReaderBoundaryTest = do
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  assert
    "healthcheck keeps issue planning plannerState on planner-state.json and not planning-state.json"
    ( "(\"plannerState\", \"planner-state.json\")" `Text.isInfixOf` healthcheckSource
        && not ("planning-state.json" `Text.isInfixOf` healthcheckSource)
    )

daemonStateSourceBoundaryTest :: IO Bool
daemonStateSourceBoundaryTest = do
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  snapshotSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Snapshot.hs")
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  assert
    "daemon-state compatibility interactions keep current healthcheck, snapshot, repair, and restart paths"
    ( "(\"daemonState\", \"daemon-state.json\")" `Text.isInfixOf` healthcheckSource
        && "SIssuePlanning ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "SIssueImplement ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "daemonResult <- decodeOptionalJsonFile (dir </> \"daemon-state.json\")" `Text.isInfixOf` snapshotSource
        && "writeCompatibilityFiles options.repairCliStateDir plan.repairReplayResult.replayState" `Text.isInfixOf` replaySource
        && "\"$state_dir/daemon-state.json\"" `Text.isInfixOf` restartSource
    )

blockStateSourceBoundaryTest :: IO Bool
blockStateSourceBoundaryTest = do
  runnerSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "AutomaticLoop" </> "Runner.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  snapshotSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Snapshot.hs")
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  assert
    "block-state compatibility interactions keep current repair-failure, healthcheck, snapshot, repair, and restart paths"
    ( "DaemonLoopDaemonFailure (DaemonReplayFailed replayFailure) -> do" `Text.isInfixOf` runnerSource
        && "writeJsonValue (stateDir </> \"block-state.json\") (repairFailureBlockStateJson replayFailure)" `Text.isInfixOf` runnerSource
        && "SIssuePlanning ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "SIssueImplement ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "(\"blockedState\", \"block-state.json\")" `Text.isInfixOf` healthcheckSource
        && "blockedResult <- decodeOptionalJsonFile (dir </> \"block-state.json\")" `Text.isInfixOf` snapshotSource
        && "removeFileIfExists (options.repairCliStateDir </> \"block-state.json\")" `Text.isInfixOf` replaySource
        && "\"$state_dir/block-state.json\"" `Text.isInfixOf` restartSource
    )

writesOnlyPlannerState :: SomeWatcherState -> Value -> Bool
writesOnlyPlannerState state expectedPlannerValue =
  let writes = compatibilityStateWrites fixtureStateDir state
   in singleWriteValue fixturePlannerPath writes == Just expectedPlannerValue
        && singleWriteValue fixturePlanningPath writes == Nothing

singleWriteValue :: FilePath -> [CompatibilityWrite] -> Maybe Value
singleWriteValue path writes =
  case [value | CompatibilityWrite writePath value <- writes, writePath == path] of
    [value] -> Just value
    _ -> Nothing

loadFixtureValue :: FilePath -> IO (Either String Value)
loadFixtureValue relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (fixtureRoot </> relativePath)

loadPlanningGraphFixture :: FilePath -> IO (Either String PlanningGraph)
loadPlanningGraphFixture relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (fixtureRoot </> relativePath)

loadDaemonFixtureValue :: FilePath -> IO (Either String Value)
loadDaemonFixtureValue relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (daemonFixtureRoot </> relativePath)

loadDaemonFixtureState :: FilePath -> IO (Either String NodeIssueDaemonState)
loadDaemonFixtureState relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (daemonFixtureRoot </> relativePath)

loadBlockStateFixtureValue :: FilePath -> IO (Either String Value)
loadBlockStateFixtureValue relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (blockStateFixtureRoot </> relativePath)

loadBlockStateFixtureState :: FilePath -> IO (Either String NodeBlockedState)
loadBlockStateFixtureState relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (blockStateFixtureRoot </> relativePath)

hasPlannerStatusKey :: Value -> Bool
hasPlannerStatusKey =
  hasObjectKey "status"

hasPlanningGraphKey :: Value -> Bool
hasPlanningGraphKey value =
  all (`hasObjectKey` value) ["ready_issues", "blocked_issues", "dependencies"]

hasObjectKey :: Text -> Value -> Bool
hasObjectKey key (Object objectValue) =
  KeyMap.member (Key.fromText key) objectValue
hasObjectKey _ _ =
  False

lookupObjectKey :: Text -> Value -> Maybe Value
lookupObjectKey key (Object objectValue) =
  KeyMap.lookup (Key.fromText key) objectValue
lookupObjectKey _ _ =
  Nothing

objectLacksKeys :: [Text] -> Value -> Bool
objectLacksKeys keys value =
  all (not . (`hasObjectKey` value)) keys

plannerStateValue :: Text -> Value
plannerStateValue statusValue =
  object
    [ "repoFullName" .= ("soulomoon/mlf2" :: Text)
    , "maxParallel" .= (2 :: Int)
    , "scopeIssueNumbers" .= ([12] :: [Int])
    , "status" .= statusValue
    ]

completePlannerStateValue :: Value
completePlannerStateValue =
  object ["status" .= ("complete" :: Text)]

activeDaemonStateValue :: Value
activeDaemonStateValue =
  object
    [ "activeTurnId" .= ("daemon-turn" :: Text)
    , "activeTurnPurpose" .= ("plan" :: Text)
    , "activeThreadId" .= ("daemon-thread" :: Text)
    ]

stoppedDaemonStateValue :: Value
stoppedDaemonStateValue =
  object
    [ "activeTurnId" .= Null
    , "activeTurnPurpose" .= Null
    , "stopReason" .= ("stopped for fixture" :: Text)
    ]

fixtureReplayFailure :: ReplayFailure
fixtureReplayFailure =
  ReplayFailure
    3
    (IssueImplementationCompletedEvent (PrNumber 42) Nothing)
    "event issue_implementation_completed is invalid in IssueImplement/PlanReady"

fixtureRepo :: RepoName
fixtureRepo =
  RepoName "soulomoon/mlf2"

fixturePlannerConfig :: PlannerConfig
fixturePlannerConfig =
  PlannerConfig
    { plannerRepo = fixtureRepo
    , plannerMaxParallel = maxParallelForTest 2
    , plannerScopeIssues = [IssueNumber 12]
    }

fixturePlanningGraph :: PlanningGraph
fixturePlanningGraph =
  PlanningGraph
    { planningReadyIssues = [IssueNumber 12]
    , planningBlockedIssues =
        [ BlockedPlanningIssue
            { blockedPlanningIssue = IssueNumber 13
            , blockedPlanningDependsOn = [IssueNumber 12]
            , blockedPlanningReason = "wait for prerequisite"
            }
        ]
    , planningDependencies =
        [ IssueDependency
            { dependencyIssue = IssueNumber 13
            , dependencyDependsOn = [IssueNumber 12]
            }
        ]
    }

fixtureRoot :: FilePath
fixtureRoot =
  "golden" </> "runtime-compatibility" </> "issue-planning"

daemonFixtureRoot :: FilePath
daemonFixtureRoot =
  "golden" </> "runtime-compatibility" </> "daemon-state"

blockStateFixtureRoot :: FilePath
blockStateFixtureRoot =
  "golden" </> "runtime-compatibility" </> "block-state"

fixtureStateDir :: FilePath
fixtureStateDir =
  "/tmp/runtime-compatibility-fixtures"

fixturePlannerPath :: FilePath
fixturePlannerPath =
  fixtureStateDir </> "planner-state.json"

fixturePlanningPath :: FilePath
fixturePlanningPath =
  fixtureStateDir </> "planning-state.json"

fixtureDaemonPath :: FilePath
fixtureDaemonPath =
  fixtureStateDir </> "daemon-state.json"

fixtureBlockStatePath :: FilePath
fixtureBlockStatePath =
  fixtureStateDir </> "block-state.json"
