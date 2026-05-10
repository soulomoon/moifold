{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module FacadeImportPolicySpec
  ( workflowFacadeImportPolicyTests
  ) where

import BoundaryPolicySpec (coreBoundaryForbiddenImportModules)
import CodexWatcher.Core.Ids
import CodexWatcher.Core.Kinds
import CodexWatcher.Core.Limits (MaxParallel, mkMaxParallel)
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..), PlanningGraph (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..))
import CodexWatcher.Effects (Effect (..), SomeEffect (..))
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), ReplayFailure, WatcherEvent (..))
import CodexWatcher.StateMachine (formatPhaseActionValidationError, validatePhaseActionPlan)
import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
import CodexWatcher.Workflow.Permission qualified as WorkflowPermission
import CodexWatcher.Workflow.Types (MoifoldSpec, workflowEffectLabel, workflowStateLabel)
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))
import TestSupport.SourceScan (assertNoTextMatches, sourceImportViolationsIn)

workflowFacadeImportPolicyTests :: IO Bool
workflowFacadeImportPolicyTests = do
  results <-
    sequence
      [ workflowFacadeReplayMatchesEventLog
      , workflowSpecModuleKeepsCoreBoundary
      , workflowIndexedSpecModuleKeepsCoreBoundary
      , workflowSpecIndexedBridgeSourceScans
      , workflowSpecInventoryCoversCurrentSpecSurfaces
      , workflowFacadeInitialApplyMatchesReplay
      , workflowPermissionFacadeMatchesStateMachine
      , workflowPermissionCoreChecksMatchMoifoldPermission
      , workflowPermissionPolicyMatchesMoifoldPermission
      ]
  pure (and results)

assert :: String -> Bool -> IO Bool
assert assertionName condition = do
  if condition
    then putStrLn ("PASS " <> assertionName)
    else putStrLn ("FAIL " <> assertionName)
  pure condition

maxParallelForTest :: Int -> MaxParallel
maxParallelForTest value =
  case mkMaxParallel value of
    Just parsed -> parsed
    Nothing -> error ("invalid test maxParallel: " <> show value)

workflowSpecModuleKeepsCoreBoundary :: IO Bool
workflowSpecModuleKeepsCoreBoundary = do
  let specPath =
        "agent-workflow-core"
          </> "src"
          </> "CodexWatcher"
          </> "Workflow"
          </> "Spec.hs"
  source <- Text.pack <$> readFile specPath
  let forbiddenImports =
        sourceImportViolationsIn specPath coreBoundaryForbiddenImportModules source
      keepsCoreDefinitions =
        "data PlannedTransition spec" `Text.isInfixOf` source
          && "class WorkflowSpec spec where" `Text.isInfixOf` source
          && "workflowPlanObservation" `Text.isInfixOf` source
  importsOk <-
    assertNoTextMatches
      "workflow spec module has no moifold-specific imports"
      forbiddenImports
  definitionsOk <-
    assert
      "workflow spec module keeps generic core definitions"
      keepsCoreDefinitions
  pure (importsOk && definitionsOk)

workflowIndexedSpecModuleKeepsCoreBoundary :: IO Bool
workflowIndexedSpecModuleKeepsCoreBoundary = do
  let specPath =
        "agent-workflow-core"
          </> "src"
          </> "CodexWatcher"
          </> "Workflow"
          </> "Indexed"
          </> "Spec.hs"
  source <- Text.pack <$> readFile specPath
  let forbiddenImports =
        sourceImportViolationsIn specPath coreBoundaryForbiddenImportModules source
      keepsCoreDefinitions =
        "type family WorkflowIndex spec :: Type" `Text.isInfixOf` source
          && "class IndexedWorkflowSpec spec where" `Text.isInfixOf` source
          && "data IndexedPlannedTransition" `Text.isInfixOf` source
          && "SomeIndexedWorkflowState" `Text.isInfixOf` source
          && "SomeIndexedWorkflowEvent" `Text.isInfixOf` source
          && "SomeIndexedWorkflowObservation" `Text.isInfixOf` source
          && "SomeIndexedWorkflowEffectPlan" `Text.isInfixOf` source
          && "SomeIndexedPlannedTransition" `Text.isInfixOf` source
          && "data WorkflowSpecIndexedBridge" `Text.isInfixOf` source
          && "workflowSpecBridgeReplayEvents" `Text.isInfixOf` source
          && "workflowSpecBridgeEffectAllowed" `Text.isInfixOf` source
          && "indexedWorkflowPlanObservation" `Text.isInfixOf` source
  importsOk <-
    assertNoTextMatches
      "indexed workflow spec module has no moifold-specific imports"
      forbiddenImports
  definitionsOk <-
    assert
      "indexed workflow spec module exposes indexed class, transitions, and existentials"
      keepsCoreDefinitions
  pure (importsOk && definitionsOk)

workflowSpecIndexedBridgeSourceScans :: IO Bool
workflowSpecIndexedBridgeSourceScans = do
  indexedSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Indexed"
            </> "Spec.hs"
        )
  docsMigrationSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "DocsMigration.hs")
  prReviewCheckingSource <-
    Text.pack
      <$> readFile
        ( "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Moifold"
            </> "PrReview"
            </> "Checking"
            </> "Indexed.hs"
        )
  let forbiddenImports =
        sourceImportViolationsIn
          ("agent-workflow-core" </> "src" </> "CodexWatcher" </> "Workflow" </> "Indexed" </> "Spec.hs")
          coreBoundaryForbiddenImportModules
          indexedSpecSource
  importsOk <-
    assertNoTextMatches
      "workflow indexed bridge keeps generic core imports"
      forbiddenImports
  results <-
    sequence
      [ assert "workflow indexed bridge exposes generic delegate hooks" $
          all
            (`Text.isInfixOf` indexedSpecSource)
            [ "WorkflowSpecIndexedBridge"
            , "workflowSpecBridgeInitialEvent"
            , "workflowSpecBridgeApplyEvent"
            , "workflowSpecBridgeObserve"
            , "workflowSpecBridgeObservedTransition"
            , "workflowSpecBridgePlanTransition"
            , "workflowSpecBridgeReplayEvents"
            , "workflowSpecBridgeValidateEffects"
            , "workflowSpecBridgeEffectAllowed"
            , "workflowSpecBridgeEffectLabel"
            ]
      , assert "workflow indexed bridge migrates DocsMigration indexed hooks" $
          all
            (`Text.isInfixOf` docsMigrationSource)
            [ "docsMigrationIndexedBridge"
            , "workflowSpecBridgePlanTransition docsMigrationIndexedBridge"
            , "workflowSpecBridgeReplayEvents docsMigrationIndexedBridge"
            , "workflowSpecBridgeValidateEffects docsMigrationIndexedBridge"
            , "workflowSpecBridgeEffectAllowed docsMigrationIndexedBridge"
            ]
      , assert "workflow indexed bridge migrates representative moifold PR-review checking adapter" $
          all
            (`Text.isInfixOf` prReviewCheckingSource)
            [ "prReviewCheckingIndexedBridge"
            , "WorkflowSpecIndexedBridge MoifoldSpec PrReviewCheckingIndexedSpec"
            , "workflowSpecBridgePlanTransition prReviewCheckingIndexedBridge"
            , "workflowSpecBridgeReplayEvents prReviewCheckingIndexedBridge"
            , "workflowSpecBridgeEffectAllowed prReviewCheckingIndexedBridge"
            ]
      ]
  pure (importsOk && and results)

workflowSpecInventoryCoversCurrentSpecSurfaces :: IO Bool
workflowSpecInventoryCoversCurrentSpecSurfaces = do
  workflowSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Spec.hs"
        )
  indexedSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Indexed"
            </> "Spec.hs"
        )
  moifoldSpecSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "Types.hs")
  docsMigrationSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "DocsMigration.hs")
  indexedAdapterSources <-
    traverse
      ( \(path, needles) -> do
          source <- Text.pack <$> readFile path
          pure (source, needles)
      )
      [ ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "IssuePlanning" </> "Indexed.hs"
        , ["data IssuePlanningIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec IssuePlanningIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "IssueImplement" </> "Indexed.hs"
        , ["data IssueImplementIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec IssueImplementIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Checking" </> "Indexed.hs"
        , ["data PrReviewCheckingIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewCheckingIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Worker" </> "Indexed.hs"
        , ["data PrReviewWorkerIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewWorkerIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Reviewer" </> "Indexed.hs"
        , ["data PrReviewReviewerIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewReviewerIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Mergeability" </> "Indexed.hs"
        , ["data PrReviewMergeabilityIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewMergeabilityIndexedSpec"]
        )
      ]
  results <-
    sequence
      [ assert "workflow spec inventory covers unindexed hooks" $
          all
            (`Text.isInfixOf` workflowSpecSource)
            [ "type WorkflowState spec"
            , "type WorkflowEvent spec"
            , "type WorkflowObservation spec"
            , "type WorkflowObservedTick spec"
            , "type WorkflowEffect spec"
            , "type WorkflowEffectPlan spec"
            , "type WorkflowReplayResult spec"
            , "workflowReplayEvents"
            , "workflowValidateEffects"
            , "workflowEffectPlanEffects"
            , "workflowEffectAllowed"
            , "workflowIsTerminal"
            , "workflowStateLabel"
            , "workflowEventLabel"
            , "workflowObservationLabel"
            , "workflowEffectLabel"
            ]
      , assert "workflow spec inventory covers indexed hooks and existential helpers" $
          all
            (`Text.isInfixOf` indexedSpecSource)
            [ "type IndexedWorkflowState spec state"
            , "type IndexedWorkflowEvent spec source target"
            , "type IndexedWorkflowObservation spec source target"
            , "type IndexedWorkflowObservedTick spec source target"
            , "type IndexedWorkflowEffect spec source target"
            , "type IndexedWorkflowEffectPlan spec source target"
            , "type IndexedWorkflowReplayResult spec state"
            , "indexedWorkflowReplayEvents"
            , "indexedWorkflowReplayState"
            , "indexedWorkflowValidateEffects"
            , "indexedWorkflowEffectAllowed"
            , "indexedWorkflowIsTerminal"
            , "indexedWorkflowEventSourceLabel"
            , "indexedWorkflowEventTargetLabel"
            , "indexedWorkflowObservationSourceLabel"
            , "indexedWorkflowObservationTargetLabel"
            , "SomeIndexedWorkflowState"
            , "SomeIndexedWorkflowEvent"
            , "SomeIndexedWorkflowObservation"
            , "SomeIndexedWorkflowEffect"
            , "SomeIndexedWorkflowEffectPlan"
            , "SomeIndexedWorkflowReplayResult"
            , "someIndexedWorkflowReplayStateLabel"
            , "withSomeIndexedPlannedTransition"
            , "WorkflowSpecIndexedBridge"
            , "workflowSpecBridgePlanTransition"
            ]
      , assert "workflow spec inventory covers moifold and docs-migration instances" $
          all
            (`Text.isInfixOf` moifoldSpecSource)
            [ "data MoifoldSpec"
            , "instance WorkflowSpec MoifoldSpec"
            , "workflowReplayEvents events"
            , "workflowValidateEffects state effects"
            , "workflowEffectAllowed state effect"
            , "workflowIsTerminal = isTerminalState"
            ]
            && all
              (`Text.isInfixOf` docsMigrationSource)
              [ "data DocsMigrationSpec"
              , "instance WorkflowSpec DocsMigrationSpec"
              , "instance IndexedWorkflow.IndexedWorkflowSpec DocsMigrationSpec"
              , "docsMigrationIndexedBridge"
              , "docsMigrationIndexedSomeReplayResult"
              , "workflowSpecBridgeReplayEvents docsMigrationIndexedBridge"
              , "workflowSpecBridgeEffectAllowed docsMigrationIndexedBridge"
              , "indexedWorkflowEventSourceLabel"
              , "indexedWorkflowObservationTargetLabel"
              ]
      , assert "workflow spec inventory covers current moifold indexed adapters" $
          all
            ( \(source, needles) ->
                all (`Text.isInfixOf` source) (needles <> indexedAdapterNeedles)
            )
            indexedAdapterSources
      ]
  pure (and results)
 where
  indexedAdapterNeedles =
    [ "indexedWorkflowReplayEvents"
    , "indexedWorkflowValidateEffects"
    , "indexedWorkflowEffectAllowed"
    , "indexedWorkflowIsTerminal"
    , "indexedWorkflowEventSourceLabel"
    , "indexedWorkflowEventTargetLabel"
    , "indexedWorkflowObservationSourceLabel"
    , "indexedWorkflowObservationTargetLabel"
    ]

workflowFacadeReplayMatchesEventLog :: IO Bool
workflowFacadeReplayMatchesEventLog = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      events =
        [ PrReviewInitialized prConfig workerThread reviewerThread
        , PrReviewNoUnresolvedFound commit (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
      direct = replayEventLog events
      specialized = WorkflowEventLog.replayMoifoldWorkflowEvents events
      generic = WorkflowEventLog.replayWorkflowEventLog @MoifoldSpec events
  results <-
    sequence
      [ assert "workflow replay facade preserves direct replay result" (sameReplay direct specialized)
      , assert "workflow spec replay facade preserves direct replay result" (sameReplayText direct generic)
      ]
  pure (and results)

workflowFacadeInitialApplyMatchesReplay :: IO Bool
workflowFacadeInitialApplyMatchesReplay = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      firstEvent = PrReviewInitialized prConfig workerThread reviewerThread
      secondEvent = PrReviewNoUnresolvedFound commit (TurnId "reviewer-turn")
      direct = replayEventLog [firstEvent, secondEvent]
      stepped = do
        (state0, _effects0) <- WorkflowEventLog.initializeMoifoldWorkflow firstEvent
        (state1, effects1) <- WorkflowEventLog.applyMoifoldWorkflowEvent state0 secondEvent
        pure (state1, effects1)
  results <-
    sequence
      [ assert "workflow event-log facade initializes and applies to replay state" $
          case (direct, stepped) of
            (Right replay, Right (state1, _effects1)) ->
              someDomain replay.replayState == someDomain state1
                && somePhase replay.replayState == somePhase state1
            _ -> False
      , assert "workflow event-log facade exposes transition effects" $
          case stepped of
            Right (_state1, effects1) ->
              any ((== "StartReviewerTurn") . workflowEffectLabel @MoifoldSpec) effects1
            Left _ -> False
      ]
  pure (and results)

workflowPermissionFacadeMatchesStateMachine :: IO Bool
workflowPermissionFacadeMatchesStateMachine = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      state = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      effects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      direct = validatePhaseActionPlan state effects
      facade = WorkflowPermission.validateMoifoldEffectPlan state effects
  assert "workflow permission facade matches state-machine validation" (direct == facade)

workflowPermissionCoreChecksMatchMoifoldPermission :: IO Bool
workflowPermissionCoreChecksMatchMoifoldPermission = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      state = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      effects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      direct = validatePhaseActionPlan state effects
      core = WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec state effects
      checks = WorkflowPermission.workflowEffectPermissionChecks @MoifoldSpec state effects
  assert "workflow permission core checks match moifold validation" $
    case (direct, core, checks) of
      (Left directError, Left coreError, [check]) ->
        coreError.workflowPermissionStateLabel == directError.phaseActionState
          && coreError.workflowPermissionEffectLabel == directError.phaseActionEffect
          && coreError.workflowPermissionReason == formatPhaseActionValidationError directError
          && check.workflowPermissionCheckEffectLabel == directError.phaseActionEffect
          && check.workflowPermissionCheckResult == Left (formatPhaseActionValidationError directError)
      _ -> False

workflowPermissionPolicyMatchesMoifoldPermission :: IO Bool
workflowPermissionPolicyMatchesMoifoldPermission = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      deniedState = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      deniedEffects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      allowedState = SomeWatcherState (PlanningReady plannerConfig :: WatcherState 'IssuePlanning 'Initialized)
      allowedEffects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      deniedDirect = validatePhaseActionPlan deniedState deniedEffects
      deniedPolicy =
        WorkflowPermission.validateWorkflowEffectPlanWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          deniedState
          deniedEffects
      allowedPolicy =
        WorkflowPermission.validateWorkflowEffectPlanWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          allowedState
          allowedEffects
      allowedChecks =
        WorkflowPermission.workflowEffectPermissionChecksWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          allowedState
          allowedEffects
      deniedChecks =
        WorkflowPermission.workflowEffectPermissionChecksWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          deniedState
          deniedEffects
  results <-
    sequence
      [ assert "workflow permission policy accepts allowed moifold effects" $
          case (allowedPolicy, allowedChecks) of
            (Right (), [check]) ->
              check.workflowPermissionCheckStateLabel == workflowStateLabel @MoifoldSpec allowedState
                && check.workflowPermissionCheckEffectLabel == "StartPlannerTurn"
                && check.workflowPermissionCheckResult == Right ()
            _ -> False
      , assert "workflow permission policy rejects denied moifold effects like state machine" $
          case (deniedDirect, deniedPolicy, deniedChecks) of
            (Left directError, Left policyError, [check]) ->
              policyError.workflowPermissionStateLabel == directError.phaseActionState
                && policyError.workflowPermissionEffectLabel == directError.phaseActionEffect
                && policyError.workflowPermissionReason == formatPhaseActionValidationError directError
                && check.workflowPermissionCheckEffectLabel == directError.phaseActionEffect
                && check.workflowPermissionCheckResult == Left (formatPhaseActionValidationError directError)
            _ -> False
      ]
  pure (and results)

sameReplay :: Either ReplayFailure EventReplayResult -> Either ReplayFailure EventReplayResult -> Bool
sameReplay (Right left) (Right right) =
  someDomain left.replayState == someDomain right.replayState
    && somePhase left.replayState == somePhase right.replayState
    && left.replayEffects == right.replayEffects
sameReplay (Left left) (Left right) =
  left == right
sameReplay _ _ =
  False

sameReplayText :: Either ReplayFailure EventReplayResult -> Either Text EventReplayResult -> Bool
sameReplayText (Right left) (Right right) =
  someDomain left.replayState == someDomain right.replayState
    && somePhase left.replayState == somePhase right.replayState
    && left.replayEffects == right.replayEffects
sameReplayText (Left _) (Left _) =
  True
sameReplayText _ _ =
  False
