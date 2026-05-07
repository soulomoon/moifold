{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Workflow.Execution.Core
  ( EffectCommitOrder (..)
  , EffectIdempotency (..)
  , WorkflowCompiledEffectPlanOf (..)
  , WorkflowEffectMetadata (..)
  , WorkflowPlannedActionOf (..)
  , compileWorkflowGenericEffectPlan
  , dryRunWorkflowGenericCompiledEffectPlan
  , executeWorkflowGenericActions
  , executeWorkflowGenericCompiledEffectPlan
  , partitionWorkflowGenericActionReports
  , partitionWorkflowGenericActions
  ) where

import Data.List (partition)

data EffectCommitOrder
  = PreCommit
  | PostCommit
  deriving stock (Eq, Show)

data EffectIdempotency
  = Idempotent
  | CheckThenAct
  | AtMostOnce
  | DerivedWrite
  deriving stock (Eq, Show)

data WorkflowEffectMetadata = WorkflowEffectMetadata
  { workflowEffectCommitOrder :: EffectCommitOrder
  , workflowEffectIdempotency :: EffectIdempotency
  }
  deriving stock (Eq, Show)

data WorkflowPlannedActionOf effect action = WorkflowPlannedActionOf
  { workflowGenericPlannedEffect :: effect
  , workflowGenericPlannedAction :: action
  , workflowGenericPlannedMetadata :: WorkflowEffectMetadata
  }
  deriving stock (Eq, Show)

data WorkflowCompiledEffectPlanOf effect action = WorkflowCompiledEffectPlanOf
  { workflowGenericCompiledActions :: [WorkflowPlannedActionOf effect action]
  }
  deriving stock (Eq, Show)

compileWorkflowGenericEffectPlan
  :: (effect -> WorkflowEffectMetadata)
  -> (effect -> [action])
  -> [effect]
  -> WorkflowCompiledEffectPlanOf effect action
compileWorkflowGenericEffectPlan metadataFor compileEffectActions effects =
  WorkflowCompiledEffectPlanOf
    { workflowGenericCompiledActions =
        concatMap
          ( \effect ->
              let metadata = metadataFor effect
               in fmap
                    ( \action ->
                        WorkflowPlannedActionOf
                          { workflowGenericPlannedEffect = effect
                          , workflowGenericPlannedAction = action
                          , workflowGenericPlannedMetadata = metadata
                          }
                    )
                    (compileEffectActions effect)
          )
          effects
    }

dryRunWorkflowGenericCompiledEffectPlan
  :: (action -> report)
  -> WorkflowCompiledEffectPlanOf effect action
  -> [report]
dryRunWorkflowGenericCompiledEffectPlan dryRunAction =
  fmap (dryRunAction . workflowGenericPlannedAction) . workflowGenericCompiledActions

executeWorkflowGenericCompiledEffectPlan
  :: Monad m
  => (mode -> action -> m report)
  -> mode
  -> WorkflowCompiledEffectPlanOf effect action
  -> m [report]
executeWorkflowGenericCompiledEffectPlan executeAction mode =
  executeWorkflowGenericActions executeAction mode . workflowGenericCompiledActions

executeWorkflowGenericActions
  :: Monad m
  => (mode -> action -> m report)
  -> mode
  -> [WorkflowPlannedActionOf effect action]
  -> m [report]
executeWorkflowGenericActions executeAction mode =
  traverse (executeAction mode . workflowGenericPlannedAction)

partitionWorkflowGenericActions
  :: WorkflowCompiledEffectPlanOf effect action
  -> ([WorkflowPlannedActionOf effect action], [WorkflowPlannedActionOf effect action])
partitionWorkflowGenericActions =
  partition genericActionRunsBeforeEventCommit . workflowGenericCompiledActions

partitionWorkflowGenericActionReports
  :: WorkflowCompiledEffectPlanOf effect action
  -> [report]
  -> ([report], [report])
partitionWorkflowGenericActionReports plan reports =
  let actionReports = zip (workflowGenericCompiledActions plan) reports
      (preCommitReports, postCommitReports) = partition (genericActionRunsBeforeEventCommit . fst) actionReports
   in (fmap snd preCommitReports, fmap snd postCommitReports)

genericActionRunsBeforeEventCommit :: WorkflowPlannedActionOf effect action -> Bool
genericActionRunsBeforeEventCommit action =
  workflowEffectCommitOrder (workflowGenericPlannedMetadata action) == PreCommit
