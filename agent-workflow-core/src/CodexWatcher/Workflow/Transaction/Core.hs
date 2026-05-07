{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Transaction.Core
  ( WorkflowObservedTransactionHooks (..)
  , WorkflowObservedTransactionResult (..)
  , runWorkflowObservedDryRunTransaction
  , runWorkflowObservedExecuteTransaction
  ) where

import CodexWatcher.Workflow.Audit (WorkflowTickAudit, workflowDryRunAudit, workflowSuccessAudit)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))

data WorkflowObservedTransactionHooks m spec compiled action report failure = WorkflowObservedTransactionHooks
  { workflowTransactionMapError :: WorkflowError spec -> failure
  , workflowTransactionCompileEffects :: WorkflowEffectPlan spec -> compiled
  , workflowTransactionPartitionActions :: compiled -> ([action], [action])
  , workflowTransactionDryRunActions :: [action] -> [report]
  , workflowTransactionExecuteActions :: [action] -> m (Either failure [report])
  , workflowTransactionCommitEvent :: WorkflowEvent spec -> m (Either failure ())
  , workflowTransactionAfterCommit :: WorkflowState spec -> m (Either failure ())
  }

data WorkflowObservedTransactionResult spec compiled report auditFailure = WorkflowObservedTransactionResult
  { workflowTransactionPriorReplay :: WorkflowReplayResult spec
  , workflowTransactionPlanned :: PlannedTransition spec
  , workflowTransactionFinalState :: WorkflowState spec
  , workflowTransactionCommittedEvents :: [WorkflowEvent spec]
  , workflowTransactionCompiledEffects :: compiled
  , workflowTransactionPreCommitReports :: [report]
  , workflowTransactionPostCommitReports :: [report]
  , workflowTransactionAudit :: WorkflowTickAudit spec auditFailure report
  }

runWorkflowObservedDryRunTransaction
  :: forall spec m compiled action report failure auditFailure.
     (WorkflowSpec spec, Semigroup (WorkflowEffectPlan spec))
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> [WorkflowEvent spec]
  -> WorkflowObservation spec
  -> Either failure (WorkflowObservedTransactionResult spec compiled report auditFailure)
runWorkflowObservedDryRunTransaction hooks events observation = do
  priorReplay <- mapWorkflowError (workflowReplayEvents @spec events)
  observed <- mapWorkflowError (workflowObserve @spec (workflowReplayState @spec priorReplay) observation)
  let planned = workflowObservedTransition @spec observed
      effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
  mapWorkflowError (workflowValidateEffects @spec (workflowReplayState @spec priorReplay) effects)
  let compiled = hooks.workflowTransactionCompileEffects effects
      (preActions, postActions) = hooks.workflowTransactionPartitionActions compiled
      preReports = hooks.workflowTransactionDryRunActions preActions
      postReports = hooks.workflowTransactionDryRunActions postActions
      finalState = workflowObservedState @spec observed
      audit =
        workflowDryRunAudit @spec
          (workflowReplayState @spec priorReplay)
          observation
          planned
          finalState
          preReports
          postReports
  pure
    WorkflowObservedTransactionResult
      { workflowTransactionPriorReplay = priorReplay
      , workflowTransactionPlanned = planned
      , workflowTransactionFinalState = finalState
      , workflowTransactionCommittedEvents = []
      , workflowTransactionCompiledEffects = compiled
      , workflowTransactionPreCommitReports = preReports
      , workflowTransactionPostCommitReports = postReports
      , workflowTransactionAudit = audit
      }
 where
  mapWorkflowError :: Either (WorkflowError spec) a -> Either failure a
  mapWorkflowError = mapTransactionError hooks.workflowTransactionMapError

runWorkflowObservedExecuteTransaction
  :: forall spec m compiled action report failure auditFailure.
     (Monad m, WorkflowSpec spec, Semigroup (WorkflowEffectPlan spec))
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> [WorkflowEvent spec]
  -> WorkflowObservation spec
  -> m (Either failure (WorkflowObservedTransactionResult spec compiled report auditFailure))
runWorkflowObservedExecuteTransaction hooks events observation =
  case prepare of
    Left failure ->
      pure (Left failure)
    Right (priorReplay, planned, compiled, preActions, postActions) -> do
      preReportsResult <- hooks.workflowTransactionExecuteActions preActions
      case preReportsResult of
        Left failure -> pure (Left failure)
        Right preReports -> do
          commitResult <- hooks.workflowTransactionCommitEvent planned.plannedEvent
          case commitResult of
            Left failure -> pure (Left failure)
            Right () -> do
              case workflowReplayEvents @spec (events <> [planned.plannedEvent]) of
                Left errorValue -> pure (Left (hooks.workflowTransactionMapError errorValue))
                Right finalReplay -> do
                  let finalState = workflowReplayState @spec finalReplay
                  afterCommitResult <- hooks.workflowTransactionAfterCommit finalState
                  case afterCommitResult of
                    Left failure -> pure (Left failure)
                    Right () -> do
                      postReportsResult <- hooks.workflowTransactionExecuteActions postActions
                      pure case postReportsResult of
                        Left failure -> Left failure
                        Right postReports ->
                          let audit =
                                workflowSuccessAudit @spec
                                  (workflowReplayState @spec priorReplay)
                                  observation
                                  planned
                                  finalState
                                  preReports
                                  postReports
                           in Right
                                WorkflowObservedTransactionResult
                                  { workflowTransactionPriorReplay = priorReplay
                                  , workflowTransactionPlanned = planned
                                  , workflowTransactionFinalState = finalState
                                  , workflowTransactionCommittedEvents = [planned.plannedEvent]
                                  , workflowTransactionCompiledEffects = compiled
                                  , workflowTransactionPreCommitReports = preReports
                                  , workflowTransactionPostCommitReports = postReports
                                  , workflowTransactionAudit = audit
                                  }
 where
  prepare = do
    priorReplay <- mapWorkflowError (workflowReplayEvents @spec events)
    observed <- mapWorkflowError (workflowObserve @spec (workflowReplayState @spec priorReplay) observation)
    let planned = workflowObservedTransition @spec observed
        effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
    mapWorkflowError (workflowValidateEffects @spec (workflowReplayState @spec priorReplay) effects)
    let compiled = hooks.workflowTransactionCompileEffects effects
        (preActions, postActions) = hooks.workflowTransactionPartitionActions compiled
    pure (priorReplay, planned, compiled, preActions, postActions)
  mapWorkflowError :: Either (WorkflowError spec) a -> Either failure a
  mapWorkflowError = mapTransactionError hooks.workflowTransactionMapError

mapTransactionError :: (errorValue -> failure) -> Either errorValue a -> Either failure a
mapTransactionError render =
  either (Left . render) Right
