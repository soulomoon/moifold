{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Observed and prepared workflow transaction runners with explicit replay,
-- validation, pre-commit action, event commit, post-commit replay, callback,
-- and post-commit action stages.
module CodexWatcher.Workflow.Transaction.Core
  ( WorkflowObservedTransactionHooks (..)
  , WorkflowObservedTransactionFailure (..)
  , WorkflowObservedTransactionResult (..)
  , WorkflowTransactionFailureStage (..)
  , runWorkflowPreparedDryRunTransaction
  , runWorkflowPreparedExecuteTransactionDetailed
  , runWorkflowObservedDryRunTransaction
  , runWorkflowObservedExecuteTransaction
  , runWorkflowObservedExecuteTransactionDetailed
  ) where

import CodexWatcher.Workflow.Audit (WorkflowTickAudit, workflowDryRunAudit, workflowFailureAudit, workflowSuccessAudit)
import CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter, commitWorkflowEvent)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))

data WorkflowObservedTransactionHooks m spec compiled action report failure = WorkflowObservedTransactionHooks
  { workflowTransactionMapError :: WorkflowError spec -> failure
  , workflowTransactionCompileEffects :: WorkflowEffectPlan spec -> compiled
  , workflowTransactionPartitionActions :: compiled -> ([action], [action])
  , workflowTransactionDryRunActions :: [action] -> [report]
  , workflowTransactionExecuteActions :: [action] -> m (Either failure [report])
  , workflowTransactionCommitEvent :: WorkflowEventCommitter m (WorkflowEvent spec) failure
  , workflowTransactionAfterCommit :: WorkflowState spec -> m (Either failure ())
  , workflowTransactionFailureIsRetryable :: failure -> Bool
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

data WorkflowTransactionFailureStage
  = WorkflowTransactionPrepareFailure
  | WorkflowTransactionPreCommitActionFailure
  | WorkflowTransactionEventCommitFailure
  | WorkflowTransactionPostCommitReplayFailure
  | WorkflowTransactionPostCommitCallbackFailure
  | WorkflowTransactionPostCommitActionFailure
  deriving stock (Eq, Show)

data WorkflowObservedTransactionFailure spec compiled report failure = WorkflowObservedTransactionFailure
  { workflowTransactionFailureStage :: WorkflowTransactionFailureStage
  , workflowTransactionFailureReason :: failure
  , workflowTransactionFailurePriorReplay :: Maybe (WorkflowReplayResult spec)
  , workflowTransactionFailurePlanned :: Maybe (PlannedTransition spec)
  , workflowTransactionFailureFinalState :: Maybe (WorkflowState spec)
  , workflowTransactionFailureCommittedEvents :: [WorkflowEvent spec]
  , workflowTransactionFailureCompiledEffects :: Maybe compiled
  , workflowTransactionFailurePreCommitReports :: [report]
  , workflowTransactionFailurePostCommitReports :: [report]
  , workflowTransactionFailureAudit :: Maybe (WorkflowTickAudit spec failure report)
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
      finalState = workflowObservedState @spec observed
  runWorkflowPreparedDryRunTransaction hooks priorReplay observation planned finalState
 where
  mapWorkflowError :: Either (WorkflowError spec) a -> Either failure a
  mapWorkflowError = mapTransactionError hooks.workflowTransactionMapError

runWorkflowPreparedDryRunTransaction
  :: forall spec m compiled action report failure auditFailure.
     (WorkflowSpec spec, Semigroup (WorkflowEffectPlan spec))
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> WorkflowReplayResult spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> Either failure (WorkflowObservedTransactionResult spec compiled report auditFailure)
runWorkflowPreparedDryRunTransaction hooks priorReplay observation planned finalState = do
  let effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
  mapWorkflowError (workflowValidateEffects @spec (workflowReplayState @spec priorReplay) effects)
  let compiled = hooks.workflowTransactionCompileEffects effects
      (preActions, postActions) = hooks.workflowTransactionPartitionActions compiled
      preReports = hooks.workflowTransactionDryRunActions preActions
      postReports = hooks.workflowTransactionDryRunActions postActions
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
          commitResult <- commitWorkflowEvent hooks.workflowTransactionCommitEvent planned.plannedEvent
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

runWorkflowObservedExecuteTransactionDetailed
  :: forall spec m compiled action report failure.
     (Monad m, WorkflowSpec spec, Semigroup (WorkflowEffectPlan spec))
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> [WorkflowEvent spec]
  -> WorkflowObservation spec
  -> m (Either (WorkflowObservedTransactionFailure spec compiled report failure) (WorkflowObservedTransactionResult spec compiled report failure))
runWorkflowObservedExecuteTransactionDetailed hooks events observation =
  case prepareDetailed of
    Left failure ->
      pure (Left failure)
    Right (priorReplay, planned, compiled, preActions, postActions) -> do
      runPreparedExecuteAfterValidation hooks events observation priorReplay planned compiled preActions postActions
 where
  prepareDetailed = do
    priorReplay <- mapPrepareError Nothing (workflowReplayEvents @spec events)
    observed <- mapPrepareError (Just priorReplay) (workflowObserve @spec (workflowReplayState @spec priorReplay) observation)
    let planned = workflowObservedTransition @spec observed
        effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
    mapPrepareError (Just priorReplay) (workflowValidateEffects @spec (workflowReplayState @spec priorReplay) effects)
    let compiled = hooks.workflowTransactionCompileEffects effects
        (preActions, postActions) = hooks.workflowTransactionPartitionActions compiled
    pure (priorReplay, planned, compiled, preActions, postActions)
  mapPrepareError
    :: Maybe (WorkflowReplayResult spec)
    -> Either (WorkflowError spec) a
    -> Either (WorkflowObservedTransactionFailure spec compiled report failure) a
  mapPrepareError maybeReplay =
    either
      ( Left
          . prepareFailure hooks maybeReplay observation
          . hooks.workflowTransactionMapError
      )
      Right

runWorkflowPreparedExecuteTransactionDetailed
  :: forall spec m compiled action report failure.
     (Monad m, WorkflowSpec spec, Semigroup (WorkflowEffectPlan spec))
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> [WorkflowEvent spec]
  -> WorkflowReplayResult spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> m (Either (WorkflowObservedTransactionFailure spec compiled report failure) (WorkflowObservedTransactionResult spec compiled report failure))
runWorkflowPreparedExecuteTransactionDetailed hooks events priorReplay observation planned =
  case prepareDetailed of
    Left failure -> pure (Left failure)
    Right (compiled, preActions, postActions) ->
      runPreparedExecuteAfterValidation hooks events observation priorReplay planned compiled preActions postActions
 where
  prepareDetailed = do
    let effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
    mapPrepareError (workflowValidateEffects @spec (workflowReplayState @spec priorReplay) effects)
    let compiled = hooks.workflowTransactionCompileEffects effects
        (preActions, postActions) = hooks.workflowTransactionPartitionActions compiled
    pure (compiled, preActions, postActions)
  mapPrepareError
    :: Either (WorkflowError spec) a
    -> Either (WorkflowObservedTransactionFailure spec compiled report failure) a
  mapPrepareError =
    either
      ( Left
          . prepareFailure hooks (Just priorReplay) observation
          . hooks.workflowTransactionMapError
      )
      Right

runPreparedExecuteAfterValidation
  :: forall spec m compiled action report failure.
     (Monad m, WorkflowSpec spec)
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> [WorkflowEvent spec]
  -> WorkflowObservation spec
  -> WorkflowReplayResult spec
  -> PlannedTransition spec
  -> compiled
  -> [action]
  -> [action]
  -> m (Either (WorkflowObservedTransactionFailure spec compiled report failure) (WorkflowObservedTransactionResult spec compiled report failure))
runPreparedExecuteAfterValidation hooks events observation priorReplay planned compiled preActions postActions = do
  preReportsResult <- hooks.workflowTransactionExecuteActions preActions
  case preReportsResult of
    Left failure ->
      pure $
        Left $
          transactionFailure
            hooks
            WorkflowTransactionPreCommitActionFailure
            failure
            priorReplay
            observation
            (Just planned)
            Nothing
            []
            (Just compiled)
            []
            []
    Right preReports -> do
      commitResult <- commitWorkflowEvent hooks.workflowTransactionCommitEvent planned.plannedEvent
      case commitResult of
        Left failure ->
          pure $
            Left $
              transactionFailure
                hooks
                WorkflowTransactionEventCommitFailure
                failure
                priorReplay
                observation
                (Just planned)
                Nothing
                []
                (Just compiled)
                preReports
                []
        Right () ->
          case workflowReplayEvents @spec (events <> [planned.plannedEvent]) of
            Left errorValue -> do
              let failure = hooks.workflowTransactionMapError errorValue
              pure $
                Left $
                  transactionFailure
                    hooks
                    WorkflowTransactionPostCommitReplayFailure
                    failure
                    priorReplay
                    observation
                    (Just planned)
                    Nothing
                    [planned.plannedEvent]
                    (Just compiled)
                    preReports
                    []
            Right finalReplay -> do
              let finalState = workflowReplayState @spec finalReplay
              afterCommitResult <- hooks.workflowTransactionAfterCommit finalState
              case afterCommitResult of
                Left failure ->
                  pure $
                    Left $
                      transactionFailure
                        hooks
                        WorkflowTransactionPostCommitCallbackFailure
                        failure
                        priorReplay
                        observation
                        (Just planned)
                        (Just finalState)
                        [planned.plannedEvent]
                        (Just compiled)
                        preReports
                        []
                Right () -> do
                  postReportsResult <- hooks.workflowTransactionExecuteActions postActions
                  pure case postReportsResult of
                    Left failure ->
                      Left $
                        transactionFailure
                          hooks
                          WorkflowTransactionPostCommitActionFailure
                          failure
                          priorReplay
                          observation
                          (Just planned)
                          (Just finalState)
                          [planned.plannedEvent]
                          (Just compiled)
                          preReports
                          []
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

transactionFailure
  :: forall spec m compiled action report failure.
     WorkflowSpec spec
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> WorkflowTransactionFailureStage
  -> failure
  -> WorkflowReplayResult spec
  -> WorkflowObservation spec
  -> Maybe (PlannedTransition spec)
  -> Maybe (WorkflowState spec)
  -> [WorkflowEvent spec]
  -> Maybe compiled
  -> [report]
  -> [report]
  -> WorkflowObservedTransactionFailure spec compiled report failure
transactionFailure hooks stage failure priorReplay observation maybePlanned maybeFinalState committedEvents maybeCompiled preReports postReports =
  WorkflowObservedTransactionFailure
    { workflowTransactionFailureStage = stage
    , workflowTransactionFailureReason = failure
    , workflowTransactionFailurePriorReplay = Just priorReplay
    , workflowTransactionFailurePlanned = maybePlanned
    , workflowTransactionFailureFinalState = maybeFinalState
    , workflowTransactionFailureCommittedEvents = committedEvents
    , workflowTransactionFailureCompiledEffects = maybeCompiled
    , workflowTransactionFailurePreCommitReports = preReports
    , workflowTransactionFailurePostCommitReports = postReports
    , workflowTransactionFailureAudit =
        Just
          ( workflowFailureAudit @spec
              hooks.workflowTransactionFailureIsRetryable
              (workflowReplayState @spec priorReplay)
              (Just observation)
              (plannedEvent <$> maybePlannedForAudit)
              maybeFinalState
              preReports
              postReports
              failure
          )
    }
 where
  maybePlannedForAudit =
    case committedEvents of
      [] -> Nothing
      _ -> maybePlanned

prepareFailure
  :: forall spec m compiled action report failure.
     WorkflowSpec spec
  => WorkflowObservedTransactionHooks m spec compiled action report failure
  -> Maybe (WorkflowReplayResult spec)
  -> WorkflowObservation spec
  -> failure
  -> WorkflowObservedTransactionFailure spec compiled report failure
prepareFailure hooks maybeReplay observation failure =
  WorkflowObservedTransactionFailure
    { workflowTransactionFailureStage = WorkflowTransactionPrepareFailure
    , workflowTransactionFailureReason = failure
    , workflowTransactionFailurePriorReplay = maybeReplay
    , workflowTransactionFailurePlanned = Nothing
    , workflowTransactionFailureFinalState = Nothing
    , workflowTransactionFailureCommittedEvents = []
    , workflowTransactionFailureCompiledEffects = Nothing
    , workflowTransactionFailurePreCommitReports = []
    , workflowTransactionFailurePostCommitReports = []
    , workflowTransactionFailureAudit =
        ( \priorReplay ->
            workflowFailureAudit @spec
              hooks.workflowTransactionFailureIsRetryable
              (workflowReplayState @spec priorReplay)
              (Just observation)
              Nothing
              Nothing
              []
              []
              failure
        )
          <$> maybeReplay
    }

mapTransactionError :: (errorValue -> failure) -> Either errorValue a -> Either failure a
mapTransactionError render =
  either (Left . render) Right
