{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module RuntimeCompatibilityFixtureSpec
  ( runtimeCompatibilityFixtureTests
  ) where

import CodexWatcher.Core.Kinds (Domain (..), Phase (..))
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (CompletionEvidence (..), SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Core.Thread (ActiveTurn (..))
import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.AppServerProtocol (AppServerRequest (..))
import CodexWatcher.Cli.Command.Replay (repairInvalidState)
import CodexWatcher.Cli.Types (RepairInvalidStateCli (..))
import CodexWatcher.Daemon (DaemonObservedTickResult (..), DaemonOptions (..))
import CodexWatcher.DaemonLoop (DaemonLoopConfig (..), DaemonLoopTickResult (..), formatDaemonLoopFailure, runAutomaticDaemonLoopOnceWithEvents)
import CodexWatcher.Domain.IssuePlanning.Graph.Canonical (PlanningIssueFact (..), planningIssueFactsFromSnapshot)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types
  ( BlockedPlanningIssue (..)
  , IssueDependency (..)
  , PlannerConfig (..)
  , PlanningGraph (..)
  )
import CodexWatcher.EffectInterpreter (CompiledEffectPlan (..), EffectRuntimeConfig (..), PlannedAction (..), compileEffectPlan)
import CodexWatcher.Effects (Effect (..), SomeEffect (..))
import CodexWatcher.EventLog.Types (EventReplayResult (replayState), ReplayFailure (..), WatcherEvent (..), eventName)
import CodexWatcher.EventLogRepair (EventLogRepairPlan (..), repairIssueImplementEventLog)
import CodexWatcher.Runtime.BlockedState (blockedStateJson)
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Owner.Store (readRuntimeOwner, readRuntimeOwnerMarker, runtimeLeaseJson)
import CodexWatcher.Runtime.Owner.Types (RuntimeLease (..), RuntimeOwner (..), RuntimeOwnerMarker (..))
import CodexWatcher.Runtime.Paths (runtimeStateDirFile)
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))
import Control.Monad (when)
import Data.Aeson (Result (..), Value (..), eitherDecodeStrict', encode, fromJSON, object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Either (isRight)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, removePathForcibly)
import System.FilePath (takeDirectory, (</>))
import TestSupport.Workflow (FakeActionCall (..), assert, defaultFakeAppServer, defaultFakeCommand, effectRuntimeConfig, fakeActionExecutorWith, maxParallelForTest, sequenceAnd)

runtimeCompatibilityFixtureTests :: IO Bool
runtimeCompatibilityFixtureTests =
  sequenceAnd
    [ fixtureShapeTests
    , daemonFixtureShapeTests
    , compatibilityProjectionFixtureTests
    , daemonCompatibilityProjectionFixtureTests
    , blockStateCompatibilityShapeTests
    , repairStateFixtureTests
    , repairStateExecuteShapeTest
    , runtimeOwnerFixtureTests
    , issueSnapshotFixtureTests
    , recordPlanningGraphFixtureTest
    , healthcheckPlannerReaderBoundaryTest
    , healthcheckRuntimeStateReadNonReadContractTest
    , daemonStateSourceBoundaryTest
    , blockStateSourceBoundaryTest
    , repairStateSourceBoundaryTest
    , runtimeOwnerSourceBoundaryTest
    , issueSnapshotSourceBoundaryTest
    , localRuntimeFileCandidateDecisionTest
    ]

fixtureShapeTests :: IO Bool
fixtureShapeTests = do
  readyResult <- loadFixtureValue ("planner-ready" </> "planner-state.json")
  activeResult <- loadFixtureValue ("planner-active" </> "planner-state.json")
  waitingPlannerResult <- loadFixtureValue ("planner-waiting-ready-issues" </> "planner-state.json")
  completeResult <- loadFixtureValue ("planner-complete" </> "planner-state.json")
  planningStateFixtureExists <- doesFileExist (fixtureRoot </> "planner-waiting-ready-issues" </> "planning-state.json")
  decodedOk <-
    assert
      "runtime compatibility planner-state fixtures decode as JSON values"
      (all isRight [readyResult, activeResult, waitingPlannerResult, completeResult])
  planningGraphOk <-
    assert
      "removed planning-state fixture is absent"
      (not planningStateFixtureExists)
  shapeOk <-
    case sequence [readyResult, activeResult, waitingPlannerResult, completeResult] of
      Left _ -> pure False
      Right [readyValue, activeValue, waitingPlannerValue, completeValue] ->
        sequenceAnd
          [ assert
              "planner-state fixtures match current summary/status JSON shapes"
              ( readyValue == plannerStateValue "ready"
                  && activeValue == plannerStateValue "active"
                  && waitingPlannerValue == plannerStateValue "waiting_ready_issues"
                  && completeValue == completePlannerStateValue
              )
          , assert
              "planner-state fixtures do not contain planning graph keys"
              ( all hasPlannerStatusKey [readyValue, activeValue, waitingPlannerValue, completeValue]
                  && all (not . hasPlanningGraphKey) [readyValue, activeValue, waitingPlannerValue, completeValue]
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
        "PlanningWaitingForReadyIssues writes planner-state and no planning-state"
        (writesOnlyPlannerState (SomeWatcherState (PlanningWaitingForReadyIssues fixturePlannerConfig fixturePlanningGraph)) (plannerStateValue "waiting_ready_issues"))
    , assert
        "PlanningComplete writes the complete planner-state fixture and no planning-state"
        (writesOnlyPlannerState (SomeWatcherState (CompleteState PlanningComplete)) completePlannerStateValue)
    ]

daemonFixtureShapeTests :: IO Bool
daemonFixtureShapeTests = do
  activeResult <- loadDaemonFixtureValue ("planning-active" </> "daemon-state.json")
  stoppedResult <- loadDaemonFixtureValue ("stopped" </> "daemon-state.json")
  decodedOk <-
    assert
      "runtime compatibility daemon fixtures decode as JSON values"
      (all isRight [activeResult, stoppedResult])
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
  pure (decodedOk && shapeOk)

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

blockStateCompatibilityShapeTests :: IO Bool
blockStateCompatibilityShapeTests =
  let blockedReason = BlockedReason "event replay failed"
      normalBlockStateValue = blockedStateJson blockedReason
      config = effectRuntimeConfig fixtureRepo "/tmp/runtime-compatibility-fixture-workdir" 1
      directBlockPath = runtimeStateDirFile config.effectRuntimeStateDir "block-state.json"
      compiled = compileEffectPlan config [SomeEffect (RecordBlocked blockedReason)]
      compatibilityWrites =
        compatibilityStateWrites
          fixtureStateDir
          (SomeWatcherState (BlockedState blockedReason :: WatcherState 'IssuePlanning 'Blocked))
   in sequenceAnd
        [ assert
            "BlockedState compatibility projection keeps the normal block-state shape"
            ( singleWriteValue fixtureBlockStatePath compatibilityWrites == Just normalBlockStateValue
                && maybe False (objectLacksKeys ["blockedKind", "eventIndex", "eventType", "event"]) (singleWriteValue fixtureBlockStatePath compatibilityWrites)
            )
        , assert
            "RecordBlocked compiled effect no longer writes the normal block-state file"
            ( null compiled.compiledActions
                && not (PlannedWriteJson directBlockPath normalBlockStateValue `elem` compiled.compiledActions)
                && objectLacksKeys ["blockedKind", "eventIndex", "eventType", "event"] normalBlockStateValue
            )
        ]

repairStateFixtureTests :: IO Bool
repairStateFixtureTests = do
  fixtureResult <- loadRepairStateFixtureValue ("completion-without-implementation" </> "repair-state.json")
  let planResult = repairIssueImplementEventLog repairStateInvalidEvents
  decodedOk <-
    assert
      "runtime compatibility repair-state fixture decodes as JSON"
      (isRight fixtureResult)
  shapeOk <-
    case (fixtureResult, planResult) of
      (Right fixtureValue, Right plan) ->
        sequenceAnd
          [ assert
              "repair-state fixture matches current repair summary generator fields"
              (fixtureValue == repairSummaryValue repairStateFixtureArchivePath plan)
          , assert
              "repair-state fixture keeps exact current completion-without-implementation summary shape"
              ( lookupObjectKey "repaired" fixtureValue == Just (Bool True)
                  && lookupObjectKey "strategy" fixtureValue == Just (String plan.repairStrategy)
                  && lookupObjectKey "archivePath" fixtureValue == Just (String (Text.pack repairStateFixtureArchivePath))
                  && lookupObjectKey "failedEventIndex" fixtureValue == Just (Number 5)
                  && lookupObjectKey "failedEventType" fixtureValue == Just (String (eventName plan.repairFailure.event))
                  && lookupObjectKey "failedReason" fixtureValue == Just (String plan.repairFailure.reason)
                  && lookupObjectKey "insertedEvents" fixtureValue == Just (toJSON (fmap eventName plan.repairInsertedEvents))
                  && lookupObjectKey "droppedEvents" fixtureValue == Just (toJSON (fmap eventName plan.repairDroppedEvents))
                  && lookupObjectKey "finalDomain" fixtureValue == Just (String (showText (someDomain plan.repairReplayResult.replayState)))
                  && lookupObjectKey "finalPhase" fixtureValue == Just (String (showText (somePhase plan.repairReplayResult.replayState)))
              )
          , assert
              "repair-state fixture is not interchangeable with normal block-state JSON"
              (objectLacksKeys ["blocked", "blockedKind", "eventIndex", "eventType", "event"] fixtureValue)
          ]
      _ -> pure False
  pure (decodedOk && shapeOk)

repairStateExecuteShapeTest :: IO Bool
repairStateExecuteShapeTest = do
  let stateDir = "/tmp/moifold-repair-state-fixture-test"
      eventsPath = stateDir </> "events.jsonl"
      repairStatePath = stateDir </> "repair-state.json"
  resetDirectory stateDir
  writeWatcherEventsForTest eventsPath repairStateInvalidEvents
  repairInvalidState
    RepairInvalidStateCli
      { repairCliEventsPath = eventsPath
      , repairCliStateDir = stateDir
      , repairCliExecute = True
      }
  fixtureResult <- loadRepairStateFixtureValue ("completion-without-implementation" </> "repair-state.json")
  generatedResult <- eitherDecodeStrict' <$> ByteString.readFile repairStatePath
  let normalizedGenerated = generatedResult >>= maybe (Left "archivePath did not match execute archive format") Right . normalizeRepairArchivePath eventsPath
      result =
        case (fixtureResult, normalizedGenerated) of
          (Right fixtureValue, Right generatedValue) -> fixtureValue == generatedValue
          _ -> False
  cleanupDirectory stateDir
  assert
    "repair-invalid-state --execute writes the repair-state summary shape before archive-path normalization"
    result

runtimeOwnerFixtureTests :: IO Bool
runtimeOwnerFixtureTests = do
  fixtureBytes <- ByteString.readFile runtimeOwnerFixturePath
  let fixtureResult = eitherDecodeStrict' fixtureBytes
  decodedOk <-
    assert
      "runtime compatibility runtime-owner fixture decodes as JSON"
      (isRight fixtureResult)
  shapeOk <-
    case fixtureResult of
      Right fixtureValue ->
        sequenceAnd
          [ assert
              "runtime-owner fixture matches current runtimeLeaseJson lease shape"
              (fixtureValue == runtimeLeaseJson fixtureRuntimeLease)
          , assert
              "runtime-owner fixture keeps lease at the top level and legacy fields out of the top level"
              ( hasObjectKey "lease" fixtureValue
                  && objectLacksKeys ["owner", "runtime", "pid", "hostname", "claimedAt", "expiresAt", "eventLogHeadHash"] fixtureValue
              )
          , assert
              "runtime-owner fixture keeps current nested lease fields"
              (case lookupObjectKey "lease" fixtureValue of
                Just leaseValue ->
                  lookupObjectKey "runtime" leaseValue == Just (String "haskell")
                    && lookupObjectKey "pid" leaseValue == Just (String "123456")
                    && lookupObjectKey "hostname" leaseValue == Just (String "runtime-fixture-host")
                    && lookupObjectKey "claimedAt" leaseValue == Just (String "2026-01-01T00:00:00Z")
                    && lookupObjectKey "expiresAt" leaseValue == Just (String "2026-01-01T01:00:00Z")
                    && lookupObjectKey "eventLogHeadHash" leaseValue == Just (String "fixture-head")
                _ -> False)
          ]
      Left _ -> pure False
  readerOk <- runtimeOwnerFixtureReaderTest fixtureBytes
  pure (decodedOk && shapeOk && readerOk)

runtimeOwnerFixtureReaderTest :: ByteString.ByteString -> IO Bool
runtimeOwnerFixtureReaderTest fixtureBytes = do
  let stateDir = "/tmp/moifold-runtime-owner-fixture-test"
      ownerPath = stateDir </> "runtime-owner.json"
  resetDirectory stateDir
  ByteString.writeFile ownerPath fixtureBytes
  markerResult <- readRuntimeOwnerMarker stateDir
  ownerResult <- readRuntimeOwner stateDir
  cleanupDirectory stateDir
  assert
    "runtime owner readers accept the checked-in lease fixture"
    ( markerResult == Right (Just (RuntimeOwnerLeased fixtureRuntimeLease))
        && ownerResult == Right (Just HaskellRuntime)
    )

issueSnapshotFixtureTests :: IO Bool
issueSnapshotFixtureTests = do
  fixtureBytes <- ByteString.readFile issueSnapshotFixturePath
  let fixtureResult = eitherDecodeStrict' fixtureBytes
  decodedOk <-
    assert
      "runtime compatibility issue-snapshot fixture decodes as JSON"
      (isRight fixtureResult)
  shapeOk <-
    case fixtureResult of
      Right fixtureValue ->
        sequenceAnd
          [ assert
              "issue-snapshot fixture matches the current deterministic live snapshot shape"
              (fixtureValue == fixtureIssueSnapshotValue)
          , assert
              "issue-snapshot fixture keeps the current top-level issue-planning keys only"
              ( all (`hasObjectKey` fixtureValue) ["repoFullName", "scopeIssueNumbers", "issues"]
                  && objectLacksKeys ["status", "ready_issues", "blocked_issues", "dependencies", "lease", "blocked", "repaired"] fixtureValue
              )
          , assert
              "issue-snapshot fixture keeps the current scoped root issue fields"
              (case lookupObjectKey "issues" fixtureValue >>= singleArrayValue of
                Just rootIssue ->
                  all
                    (`hasObjectKey` rootIssue)
                    [ "number"
                    , "title"
                    , "state"
                    , "closed"
                    , "body"
                    , "url"
                    , "labels"
                    , "assignees"
                    , "createdAt"
                    , "updatedAt"
                    , "parentIssueNumber"
                    , "subIssues"
                    ]
                    && lookupObjectKey "parentIssueNumber" rootIssue == Just Null
                    && lookupObjectKey "labels" rootIssue == Just (toJSON ([] :: [Value]))
                    && lookupObjectKey "assignees" rootIssue == Just (toJSON ([] :: [Value]))
                _ -> False)
          , assert
              "issue-snapshot fixture keeps the current closed child sub-issue fields"
              (case lookupObjectKey "issues" fixtureValue >>= singleArrayValue >>= lookupObjectKey "subIssues" >>= singleArrayValue of
                Just childIssue ->
                  all (`hasObjectKey` childIssue) ["number", "title", "state", "closed", "body", "url", "parentIssueNumber"]
                    && lookupObjectKey "number" childIssue == Just (Number 26)
                    && lookupObjectKey "state" childIssue == Just (String "CLOSED")
                    && lookupObjectKey "closed" childIssue == Just (Bool True)
                    && lookupObjectKey "parentIssueNumber" childIssue == Just (Number 12)
                _ -> False)
          ]
      Left _ -> pure False
  parserOk <-
    case fixtureResult of
      Right fixtureValue ->
        assert
          "planningIssueFactsFromSnapshot accepts the checked-in issue-snapshot fixture"
          ( planningIssueFactsFromSnapshot fixtureValue
              == Right
                [ PlanningIssueFact
                    { planningIssueFactNumber = IssueNumber 12
                    , planningIssueFactClosed = False
                    , planningIssueFactParent = Nothing
                    , planningIssueFactSubIssues = [IssueNumber 26]
                    }
                , PlanningIssueFact
                    { planningIssueFactNumber = IssueNumber 26
                    , planningIssueFactClosed = True
                    , planningIssueFactParent = Just (IssueNumber 12)
                    , planningIssueFactSubIssues = []
                    }
                ]
          )
      Left _ -> pure False
  writerOk <- issueSnapshotExecuteWriterTest
  pure (decodedOk && shapeOk && parserOk && writerOk)

issueSnapshotExecuteWriterTest :: IO Bool
issueSnapshotExecuteWriterTest = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          RawCommand "gh" ["issue", "view", "12", "--repo", "soulomoon/mlf2", "--json", _] Nothing ->
            jsonCommandReport issueSnapshotRootIssueCommandValue
          RawCommand "gh" ["api", "repos/soulomoon/mlf2/issues/12/sub_issues", "--paginate", "--jq", _] Nothing ->
            jsonCommandReport (toJSON [issueSnapshotChildIssueValue])
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig fixtureRepo "/tmp/work" 121
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events = [IssuePlanningInitialized fixturePlannerConfig]
      snapshotPath = runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "issue-snapshot.json"
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          snapshotWrites = [value | FakeWriteJson path value <- calls, path == snapshotPath]
          threadStarts = [request | FakeAppServer request <- calls, request.requestMethod == "thread/start"]
          turnStarts = [request | FakeAppServer request <- calls, request.requestMethod == "turn/start"]
      sequenceAnd
        [ assert
            "automatic planning execute writes exactly one issue-snapshot fixture value"
            (snapshotWrites == [fixtureIssueSnapshotValue])
        , assert
            "automatic planning execute writes issue-snapshot before planner turn start"
            (snapshotWriteBeforeTurnStart snapshotPath calls)
        , assert
            "automatic planning execute starts one planner thread and one planner turn for open scoped issue"
            (length threadStarts == 1 && length turnStarts == 1)
        , assert
            "automatic planning execute emits the planner turn started event for open scoped issue"
            (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "thread-started") (TurnId "turn-started")))
        ]
    Left failure -> do
      putStrLn ("FAIL issue-snapshot execute writer fixture: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  snapshotWriteBeforeTurnStart :: FilePath -> [FakeActionCall] -> Bool
  snapshotWriteBeforeTurnStart snapshotPath calls =
    case break isTurnStart calls of
      (beforeStart, FakeAppServer {} : _) -> any (isSnapshotWrite snapshotPath) beforeStart
      _ -> False

  isTurnStart :: FakeActionCall -> Bool
  isTurnStart = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
    _ -> False

  isSnapshotWrite :: FilePath -> FakeActionCall -> Bool
  isSnapshotWrite snapshotPath = \case
    FakeWriteJson path _ -> path == snapshotPath
    _ -> False

recordPlanningGraphFixtureTest :: IO Bool
recordPlanningGraphFixtureTest = do
  let config = effectRuntimeConfig fixtureRepo "/tmp/runtime-compatibility-fixture-workdir" 1
      compiled = compileEffectPlan config [SomeEffect (RecordPlanningGraph fixturePlanningGraph)]
      planningPath = runtimeStateDirFile config.effectRuntimeStateDir "planning-state.json"
      plannerPath = runtimeStateDirFile config.effectRuntimeStateDir "planner-state.json"
  assert
    "RecordPlanningGraph no longer writes planning-state compatibility files"
    ( null compiled.compiledActions
        && not (PlannedWriteJson planningPath (toJSON fixturePlanningGraph) `elem` compiled.compiledActions)
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

healthcheckRuntimeStateReadNonReadContractTest :: IO Bool
healthcheckRuntimeStateReadNonReadContractTest = do
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  assert
    "healthcheck keeps consolidated runtime-state projection/non-read contract"
    ( textNeedlesInOrder
        [ "projectStateFiles :: SDomain kind -> FilePath -> Maybe SomeWatcherState -> IO Value"
        , "object <$> traverse projectStateFile (stateFileSpecs kind)"
        , "writes = maybe [] (compatibilityStateWrites stateDir') replayState"
        , "projectStateFile (key, fileName) = do"
        , "if fileName == \"runtime-owner.json\""
        , "then readOptionalValueFile (stateDir' </> fileName)"
        , "else pure (lookupProjectedState fileName writes)"
        , "pure (Key.fromText key .= fromMaybe Null value)"
        , "stateFileSpecs :: SDomain kind -> [(Text, FilePath)]"
        , "SIssuePlanning ->"
        , "sharedStateFiles"
        , "(\"plannerState\", \"planner-state.json\")"
        , "SIssueImplement ->"
        , "sharedStateFiles"
        , "(\"issueState\", \"issue-state.json\")"
        , "SPrReview ->"
        , "(\"blockedState\", \"block-state.json\")"
        , "(\"runtimeOwner\", \"runtime-owner.json\")"
        , "sharedStateFiles :: [(Text, FilePath)] -> [(Text, FilePath)]"
        , "sharedStateFiles domainFiles ="
        , "(\"daemonState\", \"daemon-state.json\")"
        , ": domainFiles"
        , "<> [ (\"blockedState\", \"block-state.json\")"
        , ", (\"runtimeOwner\", \"runtime-owner.json\")"
        , "readOptionalValueFile :: FilePath -> IO (Maybe Value)"
        , "else either (const Nothing) Just <$> readJsonValue path"
        , "lookupProjectedState :: FilePath -> [CompatibilityWrite] -> Maybe Value"
        , "takeFileName path == fileName"
        ]
        healthcheckSource
        && "runtimeOwner' = config.runtimeOwner <|> lookupStateText [\"runtimeOwner\", \"owner\"] states" `Text.isInfixOf` healthcheckSource
        && "states <- projectStateFiles kind stateDir' replayState" `Text.isInfixOf` healthcheckSource
        && not ("states <- readStateFiles kind stateDir'" `Text.isInfixOf` healthcheckSource)
        && not ("planning-state.json" `Text.isInfixOf` healthcheckSource)
        && not ("repair-state.json" `Text.isInfixOf` healthcheckSource)
        && not ("issue-snapshot.json" `Text.isInfixOf` healthcheckSource)
        && not ("writeJsonValue" `Text.isInfixOf` healthcheckSource)
        && not ("lookupStateText [\"runtimeOwner\", \"lease\", \"runtime\"]" `Text.isInfixOf` healthcheckSource)
    )

daemonStateSourceBoundaryTest :: IO Bool
daemonStateSourceBoundaryTest = do
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  snapshotSourceExists <- doesFileExist ("src" </> "CodexWatcher" </> "Snapshot.hs")
  assert
    "daemon-state compatibility interactions keep projection paths without snapshot readers, restart cleanup, or repair rewrites"
    ( "(\"daemonState\", \"daemon-state.json\")" `Text.isInfixOf` healthcheckSource
        && "SIssuePlanning ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "SIssueImplement ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && not snapshotSourceExists
        && not ("writeCompatibilityFiles" `Text.isInfixOf` replaySource)
        && not ("\"$state_dir/daemon-state.json\"" `Text.isInfixOf` restartSource)
    )

blockStateSourceBoundaryTest :: IO Bool
blockStateSourceBoundaryTest = do
  runnerSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "AutomaticLoop" </> "Runner.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  snapshotSourceExists <- doesFileExist ("src" </> "CodexWatcher" </> "Snapshot.hs")
  assert
    "block-state compatibility interactions keep projection/repair cleanup paths without snapshot readers, restart cleanup, or repair-failure writes"
    ( not ("repairFailureBlockStateJson" `Text.isInfixOf` runnerSource)
        && not ("writeJsonValue (stateDir </> \"block-state.json\")" `Text.isInfixOf` runnerSource)
        && "SIssuePlanning ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "SIssueImplement ->\n    sharedStateFiles" `Text.isInfixOf` healthcheckSource
        && "(\"blockedState\", \"block-state.json\")" `Text.isInfixOf` healthcheckSource
        && not snapshotSourceExists
        && "removeFileIfExists (options.repairCliStateDir </> \"block-state.json\")" `Text.isInfixOf` replaySource
        && not ("\"$state_dir/block-state.json\"" `Text.isInfixOf` restartSource)
    )

repairStateSourceBoundaryTest :: IO Bool
repairStateSourceBoundaryTest = do
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  snapshotSourceExists <- doesFileExist ("src" </> "CodexWatcher" </> "Snapshot.hs")
  runtimeSources <- traverse TextIO.readFile runtimeSourceFiles
  automaticLoopSources <- traverse TextIO.readFile automaticLoopSourceFiles
  sequenceAnd
    [ assert
        "repair CLI dry-run reports the repair plan before the execute write branch"
        ( textNeedlesInOrder
            [ "plan <- either (die . Text.unpack) pure (repairIssueImplementEventLog events)"
            , "putStrLn (\"repair strategy: \""
            , "putStrLn (\"failed event index: \""
            , "putStrLn (\"inserted events: \""
            , "putStrLn (\"dropped events: \""
            , "putStrLn (\"repaired phase: \""
            , "if options.repairCliExecute"
            , "putStrLn \"dry-run: pass --execute to archive and rewrite events.jsonl\""
            ]
            replaySource
        )
    , assert
        "repair execute order archives, rewrites events, writes repair state, then removes stale block state"
        ( textNeedlesInOrder
            [ "archivePath <- archiveEventLog options.repairCliEventsPath"
            , "writeWatcherEventsFile options.repairCliEventsPath plan.repairRepairedEvents"
            , "writeRepairSummary options.repairCliStateDir archivePath plan"
            , "removeFileIfExists (options.repairCliStateDir </> \"block-state.json\")"
            ]
            replaySource
        )
    , assert
        "writeRepairSummary writes exactly repair-state.json with the current summary fields"
        ( all
            (`Text.isInfixOf` replaySource)
            [ "writeRepairSummary :: FilePath -> FilePath -> EventLogRepairPlan -> IO ()"
            , "(stateDir </> \"repair-state.json\")"
            , "\"repaired\" .= True"
            , "\"strategy\" .= plan.repairStrategy"
            , "\"archivePath\" .= archivePath"
            , "\"failedEventIndex\" .= plan.repairFailure.eventIndex"
            , "\"failedEventType\" .= eventName plan.repairFailure.event"
            , "\"failedReason\" .= plan.repairFailure.reason"
            , "\"insertedEvents\" .= fmap eventName plan.repairInsertedEvents"
            , "\"droppedEvents\" .= fmap eventName plan.repairDroppedEvents"
            , "\"finalDomain\" .= show (someDomain plan.repairReplayResult.replayState)"
            , "\"finalPhase\" .= show (somePhase plan.repairReplayResult.replayState)"
            ]
        )
    , assert
        "repair CLI no longer rewrites compatibility files from writeRepairSummary"
        ( "writeRepairSummary :: FilePath -> FilePath -> EventLogRepairPlan -> IO ()" `Text.isInfixOf` replaySource
            && "(stateDir </> \"repair-state.json\")" `Text.isInfixOf` replaySource
            && not ("writeCompatibilityFiles" `Text.isInfixOf` replaySource)
            && not ("compatibilityStateWrites stateDir state" `Text.isInfixOf` replaySource)
        )
    , assert
        "healthcheck remains a repair-state non-reader"
        ( "projectStateFiles" `Text.isInfixOf` healthcheckSource
            && "sharedStateFiles" `Text.isInfixOf` healthcheckSource
            && not ("repair-state.json" `Text.isInfixOf` healthcheckSource)
        )
    , assert
        "removed snapshot bridge, runtime, and automatic-loop sources remain repair-state non-readers"
        ( not snapshotSourceExists
            && all (not . ("repair-state.json" `Text.isInfixOf`)) (runtimeSources <> automaticLoopSources)
        )
    ]

runtimeOwnerSourceBoundaryTest :: IO Bool
runtimeOwnerSourceBoundaryTest = do
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  sequenceAnd
    [ assert
        "healthcheck keeps runtime-owner.json mapping and current runtimeOwner summary field path"
        ( all
            (`Text.isInfixOf` healthcheckSource)
            [ "SIssuePlanning ->\n    sharedStateFiles"
            , "SIssueImplement ->\n    sharedStateFiles"
            , "SPrReview ->\n    [ (\"watcherState\", \"watcher-state.json\")"
            , "(\"runtimeOwner\", \"runtime-owner.json\")"
            , "runtimeOwner' = config.runtimeOwner <|> lookupStateText [\"runtimeOwner\", \"owner\"] states"
            ]
            && not ("lookupStateText [\"runtimeOwner\", \"lease\", \"runtime\"]" `Text.isInfixOf` healthcheckSource)
        )
    , assert
        "restart-watcher keeps runtime-owner pid extraction, stop, and cleanup behavior"
        ( all
            (`Text.isInfixOf` restartSource)
            [ "read_runtime_owner_pid() {"
            , "local path=\"$state_dir/runtime-owner.json\""
            , "sed -n 's/.*\"pid\"[[:space:]]*:[[:space:]]*\"\\([0-9][0-9]*\\)\".*/\\1/p' \"$path\" | head -n 1"
            , "pid_from_owner=$(read_runtime_owner_pid)"
            , "stop_pid \"$pid_from_owner\""
            , "\"$state_dir/runtime-owner.json\""
            ]
        )
    ]

issueSnapshotSourceBoundaryTest :: IO Bool
issueSnapshotSourceBoundaryTest = do
  loopSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Domain" </> "IssuePlanning" </> "Loop.hs")
  turnOutputSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "TurnOutput.hs")
  promptTemplatesSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "PromptTemplates.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  restartSource <- TextIO.readFile ("scripts" </> "restart-watcher")
  snapshotSourceExists <- doesFileExist ("src" </> "CodexWatcher" </> "Snapshot.hs")
  sequenceAnd
    [ assert
        "execute planning writes issue-snapshot before starting the planner turn"
        ( textNeedlesInOrder
            [ "ExecuteActions -> do"
            , "snapshot <- ensureIssuePlanningSnapshot executor config plannerConfig"
            , "Right False ->"
            , "startPlannerTurn ops executor config events"
            ]
            loopSource
        )
    , assert
        "issuePlanningSnapshotPath keeps the live issue-snapshot.json runtime-state path"
        ( textNeedlesInOrder
            [ "issuePlanningSnapshotPath :: DaemonLoopConfig -> FilePath"
            , "runtimeStateDirFile config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir \"issue-snapshot.json\""
            ]
            loopSource
        )
    , assert
        "buildIssuePlanningSnapshot keeps the current top-level issue-snapshot keys"
        ( all
            (`Text.isInfixOf` loopSource)
            [ "\"repoFullName\" .= unRepoName plannerConfig.plannerRepo"
            , "\"scopeIssueNumbers\" .= fmap unIssueNumber plannerConfig.plannerScopeIssues"
            , "\"issues\" .= issueValues"
            ]
        )
    , assert
        "fetchScopedIssueSnapshot keeps parentIssueNumber and subIssues writer-added fields"
        ( all
            (`Text.isInfixOf` loopSource)
            [ "fetchScopedIssueSnapshot :: Monad m => ActionExecutor m -> RepoName -> IssueNumber -> m (Either Text Value)"
            , "Right (issueValue `withObjectField` (\"parentIssueNumber\", Null) `withObjectField` (\"subIssues\", arrayOrEmpty subIssueValue))"
            ]
        )
    , assert
        "planner developer instructions still render the current issue-snapshot path"
        ( "(\"issueSnapshotPath\", Text.pack (stateDir </> \"issue-snapshot.json\"))" `Text.isInfixOf` turnOutputSource
        )
    , assert
        "planner prompt still instructs planners to read the current issue snapshot"
        ( "Read the issue snapshot from {{issueSnapshotPath}}." `Text.isInfixOf` promptTemplatesSource
        )
    , assert
        "healthcheck, repair, removed snapshot bridge, and restart remain live issue-snapshot non-readers"
        ( not snapshotSourceExists
            && all
              (not . ("issue-snapshot.json" `Text.isInfixOf`))
              [healthcheckSource, replaySource, restartSource]
        )
    ]

localRuntimeFileCandidateDecisionTest :: IO Bool
localRuntimeFileCandidateDecisionTest = do
  decisionDoc <- TextIO.readFile ("docs" </> "agentic-workflow-framework" </> "local-runtime-file-candidates.md")
  effectInterpreterSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "EffectInterpreter.hs")
  compatibilitySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Runtime" </> "Compatibility.hs")
  repairSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  runtimeOwnerStoreSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Runtime" </> "Owner" </> "Store.hs")
  runtimeOwnerCliSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Runtime" </> "Owner" </> "Cli.hs")
  issuePlanningLoopSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Domain" </> "IssuePlanning" </> "Loop.hs")
  turnOutputSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "TurnOutput.hs")
  sequenceAnd
    [ assert
        "local runtime-file candidate decisions name all selected files and outcomes"
        ( all
            (`Text.isInfixOf` decisionDoc)
            [ "| `planning-state.json` | `removed` |"
            , "| `repair-state.json` | `keep-as-product` |"
            , "| `runtime-owner.json` | `keep-as-product` |"
            , "| `issue-snapshot.json` | `keep-as-product` |"
            ]
        )
    , assert
        "planning-state decision remains backed by removed graph writers and healthcheck non-reader tests"
        ( "RecordPlanningGraph _graph ->" `Text.isInfixOf` effectInterpreterSource
            && "unchanged []" `Text.isInfixOf` effectInterpreterSource
            && not ("\"planning-state.json\"" `Text.isInfixOf` effectInterpreterSource)
            && not ("write \"planning-state.json\"" `Text.isInfixOf` compatibilitySource)
            && "`removed`" `Text.isInfixOf` decisionDoc
        )
    , assert
        "repair-state decision remains backed by repair execute diagnostic writer"
        ( all
            (`Text.isInfixOf` repairSource)
            [ "writeRepairSummary options.repairCliStateDir archivePath plan"
            , "(stateDir </> \"repair-state.json\")"
            , "\"repaired\" .= True"
            ]
            && "`keep-as-product`" `Text.isInfixOf` decisionDoc
        )
    , assert
        "runtime-owner decision remains backed by store and CLI lease paths"
        ( "(stateDir </> \"runtime-owner.json\")" `Text.isInfixOf` runtimeOwnerStoreSource
            && "let path = stateDir </> \"runtime-owner.json\"" `Text.isInfixOf` runtimeOwnerCliSource
            && "live daemon lease contract" `Text.isInfixOf` decisionDoc
        )
    , assert
        "issue-snapshot decision remains backed by planner input write and prompt rendering"
        ( "runtimeStateDirFile config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir \"issue-snapshot.json\"" `Text.isInfixOf` issuePlanningLoopSource
            && "(\"issueSnapshotPath\", Text.pack (stateDir </> \"issue-snapshot.json\"))" `Text.isInfixOf` turnOutputSource
            && "live planner input" `Text.isInfixOf` decisionDoc
        )
    ]

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

loadDaemonFixtureValue :: FilePath -> IO (Either String Value)
loadDaemonFixtureValue relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (daemonFixtureRoot </> relativePath)

loadRepairStateFixtureValue :: FilePath -> IO (Either String Value)
loadRepairStateFixtureValue relativePath =
  eitherDecodeStrict' <$> ByteString.readFile (repairStateFixtureRoot </> relativePath)

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

singleArrayValue :: Value -> Maybe Value
singleArrayValue value =
  case fromJSON value :: Result [Value] of
    Success values ->
      case values of
        [singleValue] -> Just singleValue
        _ -> Nothing
    Error _ -> Nothing

showText :: Show a => a -> Text
showText =
  Text.pack . show

textNeedlesInOrder :: [Text] -> Text -> Bool
textNeedlesInOrder [] _ =
  True
textNeedlesInOrder (needle : restNeedles) haystack =
  let (_before, matchAndAfter) = Text.breakOn needle haystack
   in not (Text.null matchAndAfter)
        && textNeedlesInOrder restNeedles (Text.drop (Text.length needle) matchAndAfter)

repairSummaryValue :: FilePath -> EventLogRepairPlan -> Value
repairSummaryValue archivePath plan =
  object
    [ "repaired" .= True
    , "strategy" .= plan.repairStrategy
    , "archivePath" .= archivePath
    , "failedEventIndex" .= plan.repairFailure.eventIndex
    , "failedEventType" .= eventName plan.repairFailure.event
    , "failedReason" .= plan.repairFailure.reason
    , "insertedEvents" .= fmap eventName plan.repairInsertedEvents
    , "droppedEvents" .= fmap eventName plan.repairDroppedEvents
    , "finalDomain" .= showText (someDomain plan.repairReplayResult.replayState)
    , "finalPhase" .= showText (somePhase plan.repairReplayResult.replayState)
    ]

normalizeRepairArchivePath :: FilePath -> Value -> Maybe Value
normalizeRepairArchivePath eventsPath (Object objectValue) =
  case KeyMap.lookup (Key.fromText "archivePath") objectValue of
    Just (String archivePath)
      | Text.pack (eventsPath <> ".invalid-") `Text.isPrefixOf` archivePath ->
          Just
            ( Object
                (KeyMap.insert (Key.fromText "archivePath") (String (Text.pack repairStateFixtureArchivePath)) objectValue)
            )
    _ -> Nothing
normalizeRepairArchivePath _ _ =
  Nothing

writeWatcherEventsForTest :: FilePath -> [WatcherEvent] -> IO ()
writeWatcherEventsForTest eventsPath events = do
  createDirectoryIfMissing True (takeDirectory eventsPath)
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

resetDirectory :: FilePath -> IO ()
resetDirectory path = do
  cleanupDirectory path
  createDirectoryIfMissing True path

cleanupDirectory :: FilePath -> IO ()
cleanupDirectory path = do
  exists <- doesDirectoryExist path
  when exists (removePathForcibly path)

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

fixtureIssueSnapshotValue :: Value
fixtureIssueSnapshotValue =
  object
    [ "repoFullName" .= ("soulomoon/mlf2" :: Text)
    , "scopeIssueNumbers" .= ([12] :: [Int])
    , "issues" .= [issueSnapshotRootIssueValue]
    ]

issueSnapshotRootIssueCommandValue :: Value
issueSnapshotRootIssueCommandValue =
  object
    [ "number" .= (12 :: Int)
    , "title" .= ("Root issue" :: Text)
    , "state" .= ("OPEN" :: Text)
    , "closed" .= False
    , "body" .= ("Root body" :: Text)
    , "url" .= ("https://github.com/soulomoon/mlf2/issues/12" :: Text)
    , "labels" .= ([] :: [Value])
    , "assignees" .= ([] :: [Value])
    , "createdAt" .= ("2026-01-01T00:00:00Z" :: Text)
    , "updatedAt" .= ("2026-01-02T00:00:00Z" :: Text)
    ]

issueSnapshotRootIssueValue :: Value
issueSnapshotRootIssueValue =
  object
    [ "number" .= (12 :: Int)
    , "title" .= ("Root issue" :: Text)
    , "state" .= ("OPEN" :: Text)
    , "closed" .= False
    , "body" .= ("Root body" :: Text)
    , "url" .= ("https://github.com/soulomoon/mlf2/issues/12" :: Text)
    , "labels" .= ([] :: [Value])
    , "assignees" .= ([] :: [Value])
    , "createdAt" .= ("2026-01-01T00:00:00Z" :: Text)
    , "updatedAt" .= ("2026-01-02T00:00:00Z" :: Text)
    , "parentIssueNumber" .= Null
    , "subIssues" .= [issueSnapshotChildIssueValue]
    ]

issueSnapshotChildIssueValue :: Value
issueSnapshotChildIssueValue =
  object
    [ "number" .= (26 :: Int)
    , "title" .= ("Sub issue" :: Text)
    , "state" .= ("CLOSED" :: Text)
    , "closed" .= True
    , "body" .= ("Sub body" :: Text)
    , "url" .= ("https://github.com/soulomoon/mlf2/issues/26" :: Text)
    , "parentIssueNumber" .= (12 :: Int)
    ]

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

repairStateInvalidEvents :: [WatcherEvent]
repairStateInvalidEvents =
  [ IssueImplementInitialized repairStateIssueConfig (ThreadId "worker-thread")
  , IssuePullRequestCreatedEvent (PrNumber 7)
  , IssuePlanTurnStartedEvent (TurnId "turn-plan")
  , IssuePlanCompletedEvent "Implement the issue in small verified steps." Nothing
  , IssueImplementationCompletedEvent (PrNumber 7) Nothing
  ]

repairStateIssueConfig :: IssueConfig
repairStateIssueConfig =
  IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")

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

repairStateFixtureRoot :: FilePath
repairStateFixtureRoot =
  "golden" </> "runtime-compatibility" </> "repair-state"

runtimeOwnerFixtureRoot :: FilePath
runtimeOwnerFixtureRoot =
  "golden" </> "runtime-compatibility" </> "runtime-owner"

runtimeOwnerFixturePath :: FilePath
runtimeOwnerFixturePath =
  runtimeOwnerFixtureRoot </> "current-lease" </> "runtime-owner.json"

issueSnapshotFixtureRoot :: FilePath
issueSnapshotFixtureRoot =
  "golden" </> "runtime-compatibility" </> "issue-snapshot"

issueSnapshotFixturePath :: FilePath
issueSnapshotFixturePath =
  issueSnapshotFixtureRoot </> "scoped-open-with-closed-subissue" </> "issue-snapshot.json"

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

repairStateFixtureArchivePath :: FilePath
repairStateFixtureArchivePath =
  fixtureStateDir </> "events.jsonl.invalid-fixture"

fixtureRuntimeLease :: RuntimeLease
fixtureRuntimeLease =
  RuntimeLease
    { runtimeLeaseOwner = HaskellRuntime
    , runtimeLeasePid = "123456"
    , runtimeLeaseHost = "runtime-fixture-host"
    , runtimeLeaseClaimedAt = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 0)
    , runtimeLeaseExpiresAt = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 3600)
    , runtimeLeaseEventLogHeadHash = "fixture-head"
    }

jsonCommandReport :: Value -> CommandReport
jsonCommandReport value =
  CommandReport
    { ok = True
    , status = Just 0
    , stdout = TextEncoding.decodeUtf8 (LazyByteString.toStrict (encode value))
    , stderr = ""
    , errorMessage = Nothing
    }

runtimeSourceFiles :: [FilePath]
runtimeSourceFiles =
  [ "src" </> "CodexWatcher" </> "Runtime" </> "BlockedState.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Command" </> "Render.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Command" </> "Types.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Compatibility.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Defaults.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "File.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Interpreter.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Json.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Owner" </> "Cli.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Owner" </> "Store.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Owner" </> "Types.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Paths.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "Process.hs"
  , "src" </> "CodexWatcher" </> "Runtime" </> "WatcherPaths.hs"
  ]

automaticLoopSourceFiles :: [FilePath]
automaticLoopSourceFiles =
  [ "src" </> "CodexWatcher" </> "AutomaticLoop" </> "IssuePlanningFanout.hs"
  , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "Output.hs"
  , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "PrReviewHandoff.hs"
  , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "Runner.hs"
  , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "StartupThreads.hs"
  ]
