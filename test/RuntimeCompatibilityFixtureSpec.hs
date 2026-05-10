{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module RuntimeCompatibilityFixtureSpec
  ( runtimeCompatibilityFixtureTests
  ) where

import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..), TurnId (..))
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
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.Runtime.Paths (runtimeStateDirFile)
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
    , compatibilityProjectionFixtureTests
    , recordPlanningGraphFixtureTest
    , healthcheckPlannerReaderBoundaryTest
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

fixtureStateDir :: FilePath
fixtureStateDir =
  "/tmp/runtime-compatibility-fixtures"

fixturePlannerPath :: FilePath
fixturePlannerPath =
  fixtureStateDir </> "planner-state.json"

fixturePlanningPath :: FilePath
fixturePlanningPath =
  fixtureStateDir </> "planning-state.json"
