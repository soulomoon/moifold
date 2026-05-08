{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Reusable permission policies and per-effect validation reports over a
-- workflow spec. Permission checks run before interpretation; concrete effect
-- authority stays with the workflow and runtime adapter.
module CodexWatcher.Workflow.Permission.Core
  ( WorkflowEffectPermissionCheck (..)
  , WorkflowPermissionPolicy (..)
  , WorkflowPermissionValidationError (..)
  , formatWorkflowPermissionValidationError
  , validateWorkflowEffectPlanCore
  , validateWorkflowEffectPlanWithPolicy
  , workflowEffectPermissionChecks
  , workflowEffectPermissionChecksWithPolicy
  , workflowSpecPermissionPolicy
  ) where

import CodexWatcher.Workflow.Spec (WorkflowSpec (..))
import Data.Text (Text)

data WorkflowEffectPermissionCheck spec = WorkflowEffectPermissionCheck
  { workflowPermissionCheckStateLabel :: Text
  , workflowPermissionCheckEffect :: WorkflowEffect spec
  , workflowPermissionCheckEffectLabel :: Text
  , workflowPermissionCheckResult :: Either Text ()
  }

data WorkflowPermissionPolicy spec = WorkflowPermissionPolicy
  { workflowPermissionPolicyStateLabel :: WorkflowState spec -> Text
  , workflowPermissionPolicyEffectLabel :: WorkflowEffect spec -> Text
  , workflowPermissionPolicyEffectPlanEffects :: WorkflowEffectPlan spec -> [WorkflowEffect spec]
  , workflowPermissionPolicyEffectAllowed :: WorkflowState spec -> WorkflowEffect spec -> Either Text ()
  }

data WorkflowPermissionValidationError spec = WorkflowPermissionValidationError
  { workflowPermissionStateLabel :: Text
  , workflowPermissionEffect :: WorkflowEffect spec
  , workflowPermissionEffectLabel :: Text
  , workflowPermissionReason :: Text
  }

workflowEffectPermissionChecks
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowEffectPlan spec
  -> [WorkflowEffectPermissionCheck spec]
workflowEffectPermissionChecks state effects =
  workflowEffectPermissionChecksWithPolicy (workflowSpecPermissionPolicy @spec) state effects

workflowEffectPermissionChecksWithPolicy
  :: forall spec.
     WorkflowPermissionPolicy spec
  -> WorkflowState spec
  -> WorkflowEffectPlan spec
  -> [WorkflowEffectPermissionCheck spec]
workflowEffectPermissionChecksWithPolicy policy state effects =
  fmap
    ( \effect ->
        WorkflowEffectPermissionCheck
          { workflowPermissionCheckStateLabel = policy.workflowPermissionPolicyStateLabel state
          , workflowPermissionCheckEffect = effect
          , workflowPermissionCheckEffectLabel = policy.workflowPermissionPolicyEffectLabel effect
          , workflowPermissionCheckResult = policy.workflowPermissionPolicyEffectAllowed state effect
          }
    )
    (policy.workflowPermissionPolicyEffectPlanEffects effects)

validateWorkflowEffectPlanCore
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowEffectPlan spec
  -> Either (WorkflowPermissionValidationError spec) ()
validateWorkflowEffectPlanCore state effects =
  case workflowValidateEffects @spec state effects of
    Right () ->
      validateWorkflowEffectPlanWithPolicy policy state effects
    Left _reason ->
      case policy.workflowPermissionPolicyEffectPlanEffects effects of
        effect : _ ->
          Left
            WorkflowPermissionValidationError
              { workflowPermissionStateLabel = policy.workflowPermissionPolicyStateLabel state
              , workflowPermissionEffect = effect
              , workflowPermissionEffectLabel = policy.workflowPermissionPolicyEffectLabel effect
              , workflowPermissionReason =
                  case policy.workflowPermissionPolicyEffectAllowed state effect of
                    Left effectReason -> effectReason
                    Right () -> "workflow effect plan is invalid"
              }
        [] ->
          validateWorkflowEffectPlanWithPolicy policy state effects
 where
  policy = workflowSpecPermissionPolicy @spec

validateWorkflowEffectPlanWithPolicy
  :: forall spec.
     WorkflowPermissionPolicy spec
  -> WorkflowState spec
  -> WorkflowEffectPlan spec
  -> Either (WorkflowPermissionValidationError spec) ()
validateWorkflowEffectPlanWithPolicy policy state effects =
  case filter denied (workflowEffectPermissionChecksWithPolicy policy state effects) of
    [] -> Right ()
    check : _ ->
      Left
        WorkflowPermissionValidationError
          { workflowPermissionStateLabel = check.workflowPermissionCheckStateLabel
          , workflowPermissionEffect = check.workflowPermissionCheckEffect
          , workflowPermissionEffectLabel = check.workflowPermissionCheckEffectLabel
          , workflowPermissionReason =
              case check.workflowPermissionCheckResult of
                Left reason -> reason
                Right () -> "effect is allowed"
          }
 where
  denied check =
    case check.workflowPermissionCheckResult of
      Left _ -> True
      Right () -> False

workflowSpecPermissionPolicy :: forall spec. WorkflowSpec spec => WorkflowPermissionPolicy spec
workflowSpecPermissionPolicy =
  WorkflowPermissionPolicy
    { workflowPermissionPolicyStateLabel = workflowStateLabel @spec
    , workflowPermissionPolicyEffectLabel = workflowEffectLabel @spec
    , workflowPermissionPolicyEffectPlanEffects = workflowEffectPlanEffects @spec
    , workflowPermissionPolicyEffectAllowed = workflowEffectAllowed @spec
    }

formatWorkflowPermissionValidationError :: WorkflowPermissionValidationError spec -> Text
formatWorkflowPermissionValidationError errorValue =
  errorValue.workflowPermissionReason
    <> " (state="
    <> errorValue.workflowPermissionStateLabel
    <> ", effect="
    <> errorValue.workflowPermissionEffectLabel
    <> ")"
