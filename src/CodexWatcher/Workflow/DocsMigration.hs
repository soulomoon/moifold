{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.DocsMigration
  ( DocsMigrationConfig (..)
  , DocsMigrationEffect (..)
  , DocsMigrationEvent (..)
  , DocsMigrationObservation (..)
  , DocsMigrationOutput (..)
  , DocsMigrationReplayResult (..)
  , DocsMigrationSpec
  , DocsMigrationState (..)
  , DocsMigrationTick (..)
  , replayDocsMigrationEvents
  ) where

import CodexWatcher.Core.Ids (ThreadId, TurnId)
import CodexWatcher.Workflow.Agent (AgentOutputClass (..), ClassifiedAgentOutput (..), TurnRef (..))
import CodexWatcher.Workflow.Types (WorkflowSpec (..))
import Data.Text (Text)

data DocsMigrationSpec

data DocsMigrationConfig = DocsMigrationConfig
  { docsMigrationSource :: FilePath
  , docsMigrationTarget :: FilePath
  , docsMigrationGoal :: Text
  }
  deriving stock (Eq, Show)

data DocsMigrationOutput = DocsMigrationOutput
  { docsMigrationOutputDraft :: Text
  , docsMigrationOutputSummary :: Text
  }
  deriving stock (Eq, Show)

data DocsMigrationState
  = DocsMigrationReady DocsMigrationConfig
  | DocsMigrationTurnActive DocsMigrationConfig (TurnRef () DocsMigrationOutput)
  | DocsMigrationDraftReady DocsMigrationConfig Text
  | DocsMigrationValidated DocsMigrationConfig Text
  | DocsMigrationComplete Text
  | DocsMigrationBlocked Text
  deriving stock (Eq, Show)

data DocsMigrationEvent
  = DocsMigrationInitialized DocsMigrationConfig
  | DocsMigrationTurnStarted ThreadId TurnId
  | DocsMigrationDraftProduced Text Text
  | DocsMigrationValidationPassed Text
  | DocsMigrationWorkflowBlocked Text
  | DocsMigrationWorkflowCompleted Text
  deriving stock (Eq, Show)

data DocsMigrationObservation
  = DocsMigrationAgentReturned (ClassifiedAgentOutput DocsMigrationOutput)
  | DocsMigrationValidationReturned Bool Text
  deriving stock (Eq, Show)

data DocsMigrationEffect
  = StartDocsMigrationTurn DocsMigrationConfig
  | WriteDocsMigrationDraft FilePath Text
  | RunDocsMigrationValidation FilePath
  | StopDocsMigrationDaemon
  deriving stock (Eq, Show)

data DocsMigrationTick = DocsMigrationTick
  { docsMigrationTickEvent :: DocsMigrationEvent
  , docsMigrationTickState :: DocsMigrationState
  , docsMigrationTickEffects :: [DocsMigrationEffect]
  }
  deriving stock (Eq, Show)

data DocsMigrationReplayResult = DocsMigrationReplayResult
  { docsMigrationReplayState :: DocsMigrationState
  , docsMigrationReplayEffects :: [[DocsMigrationEffect]]
  }
  deriving stock (Eq, Show)

instance WorkflowSpec DocsMigrationSpec where
  type WorkflowState DocsMigrationSpec = DocsMigrationState
  type WorkflowEvent DocsMigrationSpec = DocsMigrationEvent
  type WorkflowObservation DocsMigrationSpec = DocsMigrationObservation
  type WorkflowObservedTick DocsMigrationSpec = DocsMigrationTick
  type WorkflowEffect DocsMigrationSpec = DocsMigrationEffect
  type WorkflowEffectPlan DocsMigrationSpec = [DocsMigrationEffect]
  type WorkflowReplayResult DocsMigrationSpec = DocsMigrationReplayResult
  type WorkflowError DocsMigrationSpec = Text

  workflowInitialEvent = initialDocsMigrationEvent
  workflowApplyEvent = applyDocsMigrationEvent
  workflowObserve = observeDocsMigration
  workflowReplayEvents = replayDocsMigrationEvents
  workflowValidateEffects _state _effects = Right ()
  workflowIsTerminal = \case
    DocsMigrationComplete {} -> True
    DocsMigrationBlocked {} -> True
    _ -> False
  workflowStateLabel = docsMigrationStateLabel
  workflowEventLabel = docsMigrationEventLabel

replayDocsMigrationEvents :: [DocsMigrationEvent] -> Either Text DocsMigrationReplayResult
replayDocsMigrationEvents [] =
  Left "docs migration event log is empty"
replayDocsMigrationEvents (firstEvent : restEvents) = do
  (initialState, initialEffects) <- initialDocsMigrationEvent firstEvent
  go initialState [initialEffects] restEvents
 where
  go state effects [] =
    Right DocsMigrationReplayResult {docsMigrationReplayState = state, docsMigrationReplayEffects = reverse effects}
  go state effects (event : rest) = do
    (state', newEffects) <- applyDocsMigrationEvent state event
    go state' (newEffects : effects) rest

initialDocsMigrationEvent :: DocsMigrationEvent -> Either Text (DocsMigrationState, [DocsMigrationEffect])
initialDocsMigrationEvent = \case
  DocsMigrationInitialized config ->
    Right (DocsMigrationReady config, [StartDocsMigrationTurn config])
  event ->
    Left ("first docs migration event must initialize workflow, got " <> docsMigrationEventLabel event)

applyDocsMigrationEvent :: DocsMigrationState -> DocsMigrationEvent -> Either Text (DocsMigrationState, [DocsMigrationEffect])
applyDocsMigrationEvent (DocsMigrationReady config) (DocsMigrationTurnStarted threadId turnId) =
  Right (DocsMigrationTurnActive config (TurnRef threadId turnId), [])
applyDocsMigrationEvent (DocsMigrationTurnActive config _turn) (DocsMigrationDraftProduced draft _summary) =
  Right
    ( DocsMigrationDraftReady config draft
    , [ WriteDocsMigrationDraft config.docsMigrationTarget draft
      , RunDocsMigrationValidation config.docsMigrationTarget
      ]
    )
applyDocsMigrationEvent (DocsMigrationDraftReady config _draft) (DocsMigrationValidationPassed summary) =
  Right (DocsMigrationValidated config summary, [StopDocsMigrationDaemon])
applyDocsMigrationEvent (DocsMigrationValidated _config summary) (DocsMigrationWorkflowCompleted doneSummary) =
  Right (DocsMigrationComplete (nonEmpty doneSummary summary), [])
applyDocsMigrationEvent _state (DocsMigrationWorkflowBlocked reason) =
  Right (DocsMigrationBlocked reason, [StopDocsMigrationDaemon])
applyDocsMigrationEvent state event =
  Left ("docs migration event " <> docsMigrationEventLabel event <> " is invalid in " <> docsMigrationStateLabel state)

observeDocsMigration :: DocsMigrationState -> DocsMigrationObservation -> Either Text DocsMigrationTick
observeDocsMigration state@(DocsMigrationTurnActive _config _turn) (DocsMigrationAgentReturned classified) =
  case classified.classifiedOutputClass of
    AgentComplete ->
      let payload = classified.classifiedOutputPayload
          event = DocsMigrationDraftProduced payload.docsMigrationOutputDraft payload.docsMigrationOutputSummary
       in tickFromApply state event
    AgentBlocked ->
      tickFromApply state (DocsMigrationWorkflowBlocked classified.classifiedOutputPayload.docsMigrationOutputSummary)
    AgentIncomplete ->
      tickFromApply state (DocsMigrationWorkflowBlocked classified.classifiedOutputPayload.docsMigrationOutputSummary)
    AgentMalformed ->
      tickFromApply state (DocsMigrationWorkflowBlocked "docs migration agent output was malformed")
    AgentProblems ->
      tickFromApply state (DocsMigrationWorkflowBlocked classified.classifiedOutputPayload.docsMigrationOutputSummary)
    AgentClean ->
      tickFromApply state (DocsMigrationWorkflowBlocked "docs migration agent returned clean without a draft")
    AgentNoop ->
      tickFromApply state (DocsMigrationWorkflowBlocked "docs migration agent returned noop")
observeDocsMigration state@(DocsMigrationDraftReady _config _draft) (DocsMigrationValidationReturned True summary) =
  tickFromApply state (DocsMigrationValidationPassed summary)
observeDocsMigration state@(DocsMigrationDraftReady _config _draft) (DocsMigrationValidationReturned False summary) =
  tickFromApply state (DocsMigrationWorkflowBlocked summary)
observeDocsMigration state observation =
  Left ("docs migration observation " <> docsMigrationObservationLabel observation <> " is invalid in " <> docsMigrationStateLabel state)

tickFromApply :: DocsMigrationState -> DocsMigrationEvent -> Either Text DocsMigrationTick
tickFromApply state event = do
  (state', effects) <- applyDocsMigrationEvent state event
  Right DocsMigrationTick {docsMigrationTickEvent = event, docsMigrationTickState = state', docsMigrationTickEffects = effects}

docsMigrationStateLabel :: DocsMigrationState -> Text
docsMigrationStateLabel = \case
  DocsMigrationReady {} -> "ready"
  DocsMigrationTurnActive {} -> "turn-active"
  DocsMigrationDraftReady {} -> "draft-ready"
  DocsMigrationValidated {} -> "validated"
  DocsMigrationComplete {} -> "complete"
  DocsMigrationBlocked {} -> "blocked"

docsMigrationEventLabel :: DocsMigrationEvent -> Text
docsMigrationEventLabel = \case
  DocsMigrationInitialized {} -> "docs-migration-initialized"
  DocsMigrationTurnStarted {} -> "docs-migration-turn-started"
  DocsMigrationDraftProduced {} -> "docs-migration-draft-produced"
  DocsMigrationValidationPassed {} -> "docs-migration-validation-passed"
  DocsMigrationWorkflowBlocked {} -> "docs-migration-blocked"
  DocsMigrationWorkflowCompleted {} -> "docs-migration-completed"

docsMigrationObservationLabel :: DocsMigrationObservation -> Text
docsMigrationObservationLabel = \case
  DocsMigrationAgentReturned {} -> "docs-migration-agent-returned"
  DocsMigrationValidationReturned {} -> "docs-migration-validation-returned"

nonEmpty :: Text -> Text -> Text
nonEmpty candidate fallback =
  if candidate == "" then fallback else candidate
