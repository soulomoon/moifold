{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.DocsMigration
  ( DocsMigrationAction (..)
  , DocsMigrationActionReport (..)
  , DocsMigrationConfig (..)
  , DocsMigrationDaemonTickResult (..)
  , DocsMigrationEffect (..)
  , DocsMigrationEvent (..)
  , DocsMigrationInterpreter (..)
  , DocsMigrationObservation (..)
  , DocsMigrationOutput (..)
  , DocsMigrationReplayResult (..)
  , DocsMigrationSpec
  , DocsMigrationState (..)
  , DocsMigrationTick (..)
  , classifyDocsMigrationTurn
  , compileDocsMigrationEffectPlan
  , docsMigrationAgentRole
  , docsMigrationEffectMetadata
  , dryRunDocsMigrationCompiledEffectPlan
  , executeDocsMigrationCompiledEffectPlan
  , runDocsMigrationObservedDryRun
  , runDocsMigrationObservedExecute
  , replayDocsMigrationEvents
  ) where

import CodexWatcher.AppServerClient (AppServerTurn (..))
import CodexWatcher.Core.Ids (ThreadId, TurnId)
import CodexWatcher.Workflow.Agent (AgentOutputClass (..), AgentRole (..), ClassifiedAgentOutput (..), TurnRef (..))
import CodexWatcher.Workflow.EventLog (WorkflowTickAudit, workflowDryRunAudit, workflowSuccessAudit)
import CodexWatcher.Workflow.Execution
  ( ActionExecutionMode (..)
  , EffectCommitOrder (..)
  , EffectIdempotency (..)
  , WorkflowCompiledEffectPlanOf
  , WorkflowEffectMetadata (..)
  , compileWorkflowGenericEffectPlan
  , dryRunWorkflowGenericCompiledEffectPlan
  , executeWorkflowGenericActions
  , executeWorkflowGenericCompiledEffectPlan
  , partitionWorkflowGenericActionReports
  , partitionWorkflowGenericActions
  )
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Aeson (FromJSON (..), eitherDecodeStrict', (.:), (.:?), (.!=), withObject)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

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

instance FromJSON DocsMigrationOutput where
  parseJSON =
    withObject "DocsMigrationOutput" $ \objectValue ->
      DocsMigrationOutput
        <$> objectValue .: "draft_markdown"
        <*> objectValue .:? "summary" .!= "docs migration draft produced"

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

data DocsMigrationAction
  = StartDocsMigrationTurnAction DocsMigrationConfig
  | WriteDocsMigrationDraftAction FilePath Text
  | RunDocsMigrationValidationAction FilePath
  | StopDocsMigrationDaemonAction
  deriving stock (Eq, Show)

data DocsMigrationActionReport = DocsMigrationActionReport
  { docsMigrationActionReportMode :: ActionExecutionMode
  , docsMigrationActionReportAction :: DocsMigrationAction
  , docsMigrationActionReportExecuted :: Bool
  }
  deriving stock (Eq, Show)

data DocsMigrationInterpreter m = DocsMigrationInterpreter
  { docsMigrationStartTurn :: DocsMigrationConfig -> m ()
  , docsMigrationWriteDraft :: FilePath -> Text -> m ()
  , docsMigrationRunValidation :: FilePath -> m ()
  , docsMigrationStopDaemon :: m ()
  }

data DocsMigrationDaemonTickResult = DocsMigrationDaemonTickResult
  { docsMigrationDaemonPriorReplay :: DocsMigrationReplayResult
  , docsMigrationDaemonEvent :: DocsMigrationEvent
  , docsMigrationDaemonState :: DocsMigrationState
  , docsMigrationDaemonCommittedEvents :: [DocsMigrationEvent]
  , docsMigrationDaemonCompiledEffects :: WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction
  , docsMigrationDaemonActionReports :: [DocsMigrationActionReport]
  , docsMigrationDaemonAudit :: WorkflowTickAudit DocsMigrationSpec DocsMigrationActionReport
  }
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
  workflowObservedTransition = docsMigrationObservedTransition
  workflowPlanTransition = docsMigrationPlannedTransitionFromEffects
  workflowReplayEvents = replayDocsMigrationEvents
  workflowValidateEffects _state _effects = Right ()
  workflowIsTerminal = \case
    DocsMigrationComplete {} -> True
    DocsMigrationBlocked {} -> True
    _ -> False
  workflowStateLabel = docsMigrationStateLabel
  workflowEventLabel = docsMigrationEventLabel
  workflowObservationLabel = docsMigrationObservationLabel

docsMigrationAgentRole :: AgentRole DocsMigrationConfig DocsMigrationOutput
docsMigrationAgentRole =
  AgentRole
    { agentRoleName = "docs-migration"
    , renderAgentInput =
        \config ->
          Text.unlines
            [ "Migrate documentation."
            , "Source: " <> Text.pack config.docsMigrationSource
            , "Target: " <> Text.pack config.docsMigrationTarget
            , "Goal: " <> config.docsMigrationGoal
            ]
    , agentOutputSchema = Nothing
    , agentClassifyTurn = classifyDocsMigrationTurn
    }

classifyDocsMigrationTurn :: AppServerTurn -> Either Text (ClassifiedAgentOutput DocsMigrationOutput)
classifyDocsMigrationTurn turn
  | turn.appServerTurnStatus /= "completed" =
      Right (classified AgentNoop ("docs migration turn is " <> turn.appServerTurnStatus))
  | otherwise =
      case turn.appServerTurnOutput of
        Nothing ->
          Right (classified AgentMalformed "docs migration turn completed without output")
        Just output
          | Text.strip output == "" ->
              Right (classified AgentMalformed "docs migration turn completed without output")
          | otherwise ->
              case eitherDecodeStrict' (Text.Encoding.encodeUtf8 output) of
                Right payload ->
                  Right (ClassifiedAgentOutput AgentComplete payload)
                Left reason ->
                  Right (classified AgentMalformed ("docs migration output was malformed: " <> Text.pack reason))
 where
  classified outputClass summary =
    ClassifiedAgentOutput outputClass (DocsMigrationOutput "" summary)

docsMigrationEffectMetadata :: DocsMigrationEffect -> WorkflowEffectMetadata
docsMigrationEffectMetadata = \case
  StartDocsMigrationTurn {} ->
    postCommit AtMostOnce
  WriteDocsMigrationDraft {} ->
    postCommit DerivedWrite
  RunDocsMigrationValidation {} ->
    postCommit CheckThenAct
  StopDocsMigrationDaemon ->
    postCommit Idempotent
 where
  postCommit idempotency =
    WorkflowEffectMetadata
      { workflowEffectCommitOrder = PostCommit
      , workflowEffectIdempotency = idempotency
      }

compileDocsMigrationEffectPlan :: [DocsMigrationEffect] -> WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction
compileDocsMigrationEffectPlan =
  compileWorkflowGenericEffectPlan docsMigrationEffectMetadata compileDocsMigrationEffect

compileDocsMigrationEffect :: DocsMigrationEffect -> [DocsMigrationAction]
compileDocsMigrationEffect = \case
  StartDocsMigrationTurn config ->
    [StartDocsMigrationTurnAction config]
  WriteDocsMigrationDraft path draft ->
    [WriteDocsMigrationDraftAction path draft]
  RunDocsMigrationValidation path ->
    [RunDocsMigrationValidationAction path]
  StopDocsMigrationDaemon ->
    [StopDocsMigrationDaemonAction]

dryRunDocsMigrationCompiledEffectPlan
  :: WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction
  -> [DocsMigrationActionReport]
dryRunDocsMigrationCompiledEffectPlan =
  dryRunWorkflowGenericCompiledEffectPlan (docsMigrationActionReport DryRunActions False)

executeDocsMigrationCompiledEffectPlan
  :: Monad m
  => DocsMigrationInterpreter m
  -> ActionExecutionMode
  -> WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction
  -> m [DocsMigrationActionReport]
executeDocsMigrationCompiledEffectPlan interpreter =
  executeWorkflowGenericCompiledEffectPlan (executeDocsMigrationAction interpreter)

executeDocsMigrationAction
  :: Monad m
  => DocsMigrationInterpreter m
  -> ActionExecutionMode
  -> DocsMigrationAction
  -> m DocsMigrationActionReport
executeDocsMigrationAction _ DryRunActions action =
  pure (docsMigrationActionReport DryRunActions False action)
executeDocsMigrationAction interpreter ExecuteActions action = do
  case action of
    StartDocsMigrationTurnAction config ->
      interpreter.docsMigrationStartTurn config
    WriteDocsMigrationDraftAction path draft ->
      interpreter.docsMigrationWriteDraft path draft
    RunDocsMigrationValidationAction path ->
      interpreter.docsMigrationRunValidation path
    StopDocsMigrationDaemonAction ->
      interpreter.docsMigrationStopDaemon
  pure (docsMigrationActionReport ExecuteActions True action)

docsMigrationActionReport :: ActionExecutionMode -> Bool -> DocsMigrationAction -> DocsMigrationActionReport
docsMigrationActionReport mode executed action =
  DocsMigrationActionReport
    { docsMigrationActionReportMode = mode
    , docsMigrationActionReportAction = action
    , docsMigrationActionReportExecuted = executed
    }

runDocsMigrationObservedDryRun
  :: [DocsMigrationEvent]
  -> DocsMigrationObservation
  -> Either Text DocsMigrationDaemonTickResult
runDocsMigrationObservedDryRun events observation = do
  priorReplay <- replayDocsMigrationEvents events
  observed <- observeDocsMigration priorReplay.docsMigrationReplayState observation
  let planned = docsMigrationObservedTransition observed
      effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
      compiled = compileDocsMigrationEffectPlan effects
      reports = dryRunDocsMigrationCompiledEffectPlan compiled
      (preReports, postReports) = partitionWorkflowGenericActionReports compiled reports
      audit =
        workflowDryRunAudit @DocsMigrationSpec
          priorReplay.docsMigrationReplayState
          observation
          planned
          observed.docsMigrationTickState
          preReports
          postReports
  Right
    DocsMigrationDaemonTickResult
      { docsMigrationDaemonPriorReplay = priorReplay
      , docsMigrationDaemonEvent = planned.plannedEvent
      , docsMigrationDaemonState = observed.docsMigrationTickState
      , docsMigrationDaemonCommittedEvents = []
      , docsMigrationDaemonCompiledEffects = compiled
      , docsMigrationDaemonActionReports = reports
      , docsMigrationDaemonAudit = audit
      }

runDocsMigrationObservedExecute
  :: Monad m
  => DocsMigrationInterpreter m
  -> [DocsMigrationEvent]
  -> DocsMigrationObservation
  -> m (Either Text DocsMigrationDaemonTickResult)
runDocsMigrationObservedExecute interpreter events observation =
  case replayDocsMigrationEvents events of
    Left reason ->
      pure (Left reason)
    Right priorReplay ->
      case observeDocsMigration priorReplay.docsMigrationReplayState observation of
        Left reason ->
          pure (Left reason)
        Right observed -> do
          let planned = docsMigrationObservedTransition observed
              effects = planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
              compiled = compileDocsMigrationEffectPlan effects
              (preActions, postActions) = partitionWorkflowGenericActions compiled
          preReports <- executeWorkflowGenericActions (executeDocsMigrationAction interpreter) ExecuteActions preActions
          let committedEvents = [planned.plannedEvent]
          case replayDocsMigrationEvents (events <> committedEvents) of
            Left reason ->
              pure (Left reason)
            Right finalReplay -> do
              postReports <- executeWorkflowGenericActions (executeDocsMigrationAction interpreter) ExecuteActions postActions
              let reports = preReports <> postReports
                  audit =
                    workflowSuccessAudit @DocsMigrationSpec
                      priorReplay.docsMigrationReplayState
                      observation
                      planned
                      finalReplay.docsMigrationReplayState
                      preReports
                      postReports
              pure
                ( Right
                    DocsMigrationDaemonTickResult
                      { docsMigrationDaemonPriorReplay = priorReplay
                      , docsMigrationDaemonEvent = planned.plannedEvent
                      , docsMigrationDaemonState = finalReplay.docsMigrationReplayState
                      , docsMigrationDaemonCommittedEvents = committedEvents
                      , docsMigrationDaemonCompiledEffects = compiled
                      , docsMigrationDaemonActionReports = reports
                      , docsMigrationDaemonAudit = audit
                      }
                )

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

docsMigrationObservedTransition :: DocsMigrationTick -> PlannedTransition DocsMigrationSpec
docsMigrationObservedTransition tick =
  docsMigrationPlannedTransitionFromEffects tick.docsMigrationTickEvent tick.docsMigrationTickEffects

docsMigrationPlannedTransitionFromEffects :: DocsMigrationEvent -> [DocsMigrationEffect] -> PlannedTransition DocsMigrationSpec
docsMigrationPlannedTransitionFromEffects event effects =
  PlannedTransition
    { plannedEvent = event
    , plannedPreCommitEffects = effects
    , plannedPostCommitEffects = []
    }

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
