{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Permission.Core
  ( WorkflowEffectPermissionCheck (..)
  , WorkflowPermissionValidationError (..)
  , formatWorkflowPermissionValidationError
  , validateWorkflowEffectPlanCore
  , workflowEffectPermissionChecks
  ) where

import CodexWatcher.Workflow.Spec (WorkflowSpec (..))
import Data.Text (Text)

data WorkflowEffectPermissionCheck spec = WorkflowEffectPermissionCheck
  { workflowPermissionCheckStateLabel :: Text
  , workflowPermissionCheckEffect :: WorkflowEffect spec
  , workflowPermissionCheckEffectLabel :: Text
  , workflowPermissionCheckResult :: Either Text ()
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
  fmap
    ( \effect ->
        WorkflowEffectPermissionCheck
          { workflowPermissionCheckStateLabel = workflowStateLabel @spec state
          , workflowPermissionCheckEffect = effect
          , workflowPermissionCheckEffectLabel = workflowEffectLabel @spec effect
          , workflowPermissionCheckResult = workflowEffectAllowed @spec state effect
          }
    )
    (workflowEffectPlanEffects @spec effects)

validateWorkflowEffectPlanCore
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowEffectPlan spec
  -> Either (WorkflowPermissionValidationError spec) ()
validateWorkflowEffectPlanCore state effects =
  case filter denied (workflowEffectPermissionChecks @spec state effects) of
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

formatWorkflowPermissionValidationError :: WorkflowPermissionValidationError spec -> Text
formatWorkflowPermissionValidationError errorValue =
  errorValue.workflowPermissionReason
    <> " (state="
    <> errorValue.workflowPermissionStateLabel
    <> ", effect="
    <> errorValue.workflowPermissionEffectLabel
    <> ")"
