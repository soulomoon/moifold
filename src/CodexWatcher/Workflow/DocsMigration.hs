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
  , docsMigrationDaemonCoreTickResult
  , docsMigrationEffectMetadata
  , docsMigrationEventCodecContract
  , docsMigrationEventLogFixture
  , docsMigrationEventLogFixtureContract
  , dryRunDocsMigrationCompiledEffectPlan
  , executeDocsMigrationCompiledEffectPlan
  , runDocsMigrationObservedDryRun
  , runDocsMigrationObservedExecute
  , replayDocsMigrationEvents
  ) where

import CodexWatcher.AppServerClient (AppServerTurn (..))
import CodexWatcher.Core.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , AgentSideEffectScope (..)
  , ClassifiedAgentOutput (..)
  , TurnRef (..)
  , defaultAgentRetryPolicy
  )
import CodexWatcher.Workflow.Codec
  ( WorkflowCodecContract (..)
  , WorkflowDecodeError (..)
  , WorkflowEventTypeLabel (..)
  , WorkflowMetadataLabel (..)
  , WorkflowSchemaVersion (..)
  )
import CodexWatcher.Workflow.Daemon.Core qualified as WorkflowDaemon
import CodexWatcher.Workflow.EventLog
  ( EventLogFixtureContract (..)
  , WorkflowReplaySummary (..)
  , WorkflowTickAudit
  , formatWorkflowReplayFailure
  , replayWorkflowEventLogDetailed
  , workflowAuditPostCommitReports
  , workflowAuditPreCommitReports
  )
import CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter (..))
import CodexWatcher.Workflow.Execution
  ( ActionExecutionMode (..)
  , EffectCommitOrder (..)
  , EffectIdempotency (..)
  , WorkflowCapability (..)
  , WorkflowCompiledEffectPlanOf
  , WorkflowEffectMetadata (..)
  , WorkflowPlannedActionOf (..)
  , compileWorkflowGenericEffectPlan
  , dryRunWorkflowGenericCompiledEffectPlan
  , executeWorkflowGenericCompiledEffectPlan
  , partitionWorkflowGenericActions
  )
import CodexWatcher.Workflow.Failure (FailureClassification)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import CodexWatcher.Workflow.Transaction.Core
  ( WorkflowObservedTransactionHooks (..)
  , WorkflowObservedTransactionResult (..)
  , runWorkflowObservedDryRunTransaction
  , runWorkflowObservedExecuteTransaction
  )
import Data.Aeson (FromJSON (..), Value (..), eitherDecodeStrict', object, (.:), (.:?), (.=), (.!=), withObject)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Pair, Parser, parseEither)
import Data.List qualified as List
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
  workflowObservedState = docsMigrationTickState
  workflowPlanTransition = docsMigrationPlannedTransitionFromEffects
  workflowReplayEvents = replayDocsMigrationEvents
  workflowReplayState = docsMigrationReplayState
  workflowValidateEffects = validateDocsMigrationEffectPlan
  workflowEffectPlanEffects = id
  workflowEffectAllowed = docsMigrationEffectAllowed
  workflowIsTerminal = \case
    DocsMigrationComplete {} -> True
    DocsMigrationBlocked {} -> True
    _ -> False
  workflowStateLabel = docsMigrationStateLabel
  workflowEventLabel = docsMigrationEventLabel
  workflowObservationLabel = docsMigrationObservationLabel
  workflowEffectLabel = docsMigrationEffectLabel

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
    , agentRetryPolicy = defaultAgentRetryPolicy
    , agentSideEffectScope = AgentReadOnly
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
    postCommit StartAgent AtMostOnce
  WriteDocsMigrationDraft {} ->
    postCommit WriteLocal DerivedWrite
  RunDocsMigrationValidation {} ->
    postCommit ReadWorld CheckThenAct
  StopDocsMigrationDaemon ->
    postCommit Stop Idempotent
 where
  postCommit capability idempotency =
    WorkflowEffectMetadata
      { workflowEffectCapability = capability
      , workflowEffectCommitOrder = PostCommit
      , workflowEffectIdempotency = idempotency
      }

docsMigrationEventCodecContract :: WorkflowCodecContract DocsMigrationEvent Value
docsMigrationEventCodecContract =
  WorkflowCodecContract
    { workflowCodecEventTypeLabel = WorkflowEventTypeLabel . docsMigrationEventLabel
    , workflowCodecSchemaVersion = const (WorkflowSchemaVersion 1)
    , workflowCodecMetadataLabels =
        fmap
          WorkflowMetadataLabel
          [ "workflowId"
          , "actor"
          , "source"
          , "correlationId"
          ]
    , workflowCodecEncode = encodeDocsMigrationEvent
    , workflowCodecEncodedEventTypeLabel = docsMigrationEventTypeLabelFromValue
    , workflowCodecDecode =
        \value ->
          case parseEither parseDocsMigrationEvent value of
            Right event -> Right event
            Left reason ->
              Left
                WorkflowDecodeError
                  { workflowDecodeErrorTypeLabel = docsMigrationEventTypeLabelFromValue value
                  , workflowDecodeErrorSchemaVersion = docsMigrationSchemaVersionFromValue value
                  , workflowDecodeErrorReason = Text.pack reason
                  }
    }

docsMigrationEventLogFixture :: [DocsMigrationEvent]
docsMigrationEventLogFixture =
  [ DocsMigrationInitialized docsMigrationFixtureConfig
  , DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
  , DocsMigrationDraftProduced "draft markdown" "draft ready"
  , DocsMigrationValidationPassed "validation passed"
  , DocsMigrationWorkflowCompleted "done"
  ]

docsMigrationEventLogFixtureContract :: EventLogFixtureContract DocsMigrationSpec
docsMigrationEventLogFixtureContract =
  EventLogFixtureContract
    { fixtureExpectedStateLabel = "complete"
    , fixtureExpectedEventCount = Just (length docsMigrationEventLogFixture)
    }

docsMigrationFixtureConfig :: DocsMigrationConfig
docsMigrationFixtureConfig =
  DocsMigrationConfig
    { docsMigrationSource = "docs/source.md"
    , docsMigrationTarget = "docs/target.md"
    , docsMigrationGoal = "migrate framework notes"
    }

encodeDocsMigrationEvent :: DocsMigrationEvent -> Value
encodeDocsMigrationEvent event =
  object (baseFields <> eventFields)
 where
  baseFields =
    [ "type" .= docsMigrationEventLabel event
    , "schemaVersion" .= (1 :: Int)
    ]
  eventFields :: [Pair]
  eventFields =
    case event of
      DocsMigrationInitialized config ->
        [ "source" .= config.docsMigrationSource
        , "target" .= config.docsMigrationTarget
        , "goal" .= config.docsMigrationGoal
        ]
      DocsMigrationTurnStarted threadId turnId ->
        [ "threadId" .= unThreadId threadId
        , "turnId" .= unTurnId turnId
        ]
      DocsMigrationDraftProduced draft summary ->
        [ "draft" .= draft
        , "summary" .= summary
        ]
      DocsMigrationValidationPassed summary ->
        ["summary" .= summary]
      DocsMigrationWorkflowBlocked reason ->
        ["reason" .= reason]
      DocsMigrationWorkflowCompleted summary ->
        ["summary" .= summary]

parseDocsMigrationEvent :: Value -> Parser DocsMigrationEvent
parseDocsMigrationEvent =
  withObject "DocsMigrationEvent" $ \objectValue -> do
    schemaVersion <- objectValue .:? "schemaVersion" .!= (1 :: Int)
    if schemaVersion /= 1
      then fail ("unsupported docs migration schema version " <> show schemaVersion)
      else do
        eventType <- objectValue .: "type"
        case eventType of
          "docs-migration-initialized" ->
            DocsMigrationInitialized
              <$> ( DocsMigrationConfig
                      <$> objectValue .: "source"
                      <*> objectValue .: "target"
                      <*> objectValue .: "goal"
                  )
          "docs-migration-turn-started" ->
            DocsMigrationTurnStarted
              <$> (ThreadId <$> objectValue .: "threadId")
              <*> (TurnId <$> objectValue .: "turnId")
          "docs-migration-draft-produced" ->
            DocsMigrationDraftProduced
              <$> objectValue .: "draft"
              <*> objectValue .: "summary"
          "docs-migration-validation-passed" ->
            DocsMigrationValidationPassed <$> objectValue .: "summary"
          "docs-migration-blocked" ->
            DocsMigrationWorkflowBlocked <$> objectValue .: "reason"
          "docs-migration-completed" ->
            DocsMigrationWorkflowCompleted <$> objectValue .: "summary"
          other ->
            fail ("unknown docs migration event type " <> Text.unpack other)

docsMigrationEventTypeLabelFromValue :: Value -> Maybe WorkflowEventTypeLabel
docsMigrationEventTypeLabelFromValue (Object objectValue) =
  case KeyMap.lookup "type" objectValue of
    Just (String label) -> Just (WorkflowEventTypeLabel label)
    _ -> Nothing
docsMigrationEventTypeLabelFromValue _ =
  Nothing

docsMigrationSchemaVersionFromValue :: Value -> Maybe WorkflowSchemaVersion
docsMigrationSchemaVersionFromValue value =
  case parseEither (withObject "DocsMigrationEvent" (.: "schemaVersion")) value of
    Right version -> Just (WorkflowSchemaVersion version)
    Left _reason -> Nothing

validateDocsMigrationEffectPlan :: DocsMigrationState -> [DocsMigrationEffect] -> Either Text ()
validateDocsMigrationEffectPlan _state [] =
  Right ()
validateDocsMigrationEffectPlan state effects =
  case (state, effects) of
    (DocsMigrationReady expectedConfig, [StartDocsMigrationTurn actualConfig])
      | actualConfig == expectedConfig -> Right ()
      | otherwise -> Left "docs migration can only start the configured migration turn"
    (DocsMigrationTurnActive config _turn, [WriteDocsMigrationDraft writePath draft, RunDocsMigrationValidation validationPath])
      | Text.null draft -> Left "docs migration draft write requires a non-empty draft"
      | writePath /= config.docsMigrationTarget -> Left "docs migration draft write must target the configured target path"
      | validationPath /= config.docsMigrationTarget -> Left "docs migration validation must read the configured target path"
      | otherwise -> Right ()
    (_state, [StopDocsMigrationDaemon])
      | docsMigrationCanStop state -> Right ()
    _ ->
      case traverse (docsMigrationEffectAllowed state) effects of
        Left reason -> Left reason
        Right _ ->
          Left
            ( "docs migration effect plan "
                <> Text.pack (show (fmap docsMigrationEffectLabel effects))
                <> " is not allowed in "
                <> docsMigrationStateLabel state
            )

docsMigrationEffectAllowed :: DocsMigrationState -> DocsMigrationEffect -> Either Text ()
docsMigrationEffectAllowed state effect =
  case effect of
    StartDocsMigrationTurn actualConfig ->
      case state of
        DocsMigrationReady expectedConfig
          | actualConfig == expectedConfig -> Right ()
          | otherwise -> Left "docs migration can only start the configured migration turn"
        _ -> Left ("start-docs-migration-turn is not allowed in " <> docsMigrationStateLabel state)
    WriteDocsMigrationDraft path draft ->
      case state of
        DocsMigrationTurnActive config _turn
          | Text.null draft -> Left "docs migration draft write requires a non-empty draft"
          | path == config.docsMigrationTarget -> Right ()
          | otherwise -> Left "docs migration draft write must target the configured target path"
        _ -> Left ("write-docs-migration-draft is not allowed in " <> docsMigrationStateLabel state)
    RunDocsMigrationValidation path ->
      case state of
        DocsMigrationTurnActive config _turn
          | path == config.docsMigrationTarget -> Right ()
          | otherwise -> Left "docs migration validation must read the configured target path"
        _ -> Left ("run-docs-migration-validation is not allowed in " <> docsMigrationStateLabel state)
    StopDocsMigrationDaemon
      | docsMigrationCanStop state -> Right ()
      | otherwise -> Left ("stop-docs-migration-daemon is not allowed in " <> docsMigrationStateLabel state)

docsMigrationCanStop :: DocsMigrationState -> Bool
docsMigrationCanStop = \case
  DocsMigrationReady {} -> True
  DocsMigrationTurnActive {} -> True
  DocsMigrationDraftReady {} -> True
  DocsMigrationValidated {} -> True
  DocsMigrationComplete {} -> False
  DocsMigrationBlocked {} -> False

docsMigrationCanBlock :: DocsMigrationState -> Bool
docsMigrationCanBlock = \case
  DocsMigrationReady {} -> True
  DocsMigrationTurnActive {} -> True
  DocsMigrationDraftReady {} -> True
  DocsMigrationValidated {} -> True
  DocsMigrationComplete {} -> False
  DocsMigrationBlocked {} -> False

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
runDocsMigrationObservedDryRun events observation =
  docsMigrationDaemonTickResult
    <$> runWorkflowObservedDryRunTransaction @DocsMigrationSpec docsMigrationDryRunTransactionHooks events observation

runDocsMigrationObservedExecute
  :: Monad m
  => DocsMigrationInterpreter m
  -> [DocsMigrationEvent]
  -> DocsMigrationObservation
  -> m (Either Text DocsMigrationDaemonTickResult)
runDocsMigrationObservedExecute interpreter events observation =
  fmap docsMigrationDaemonTickResult
    <$> runWorkflowObservedExecuteTransaction @DocsMigrationSpec (docsMigrationTransactionHooksForInterpreter interpreter) events observation

docsMigrationDryRunTransactionHooks
  :: WorkflowObservedTransactionHooks
       (Either Text)
       DocsMigrationSpec
       (WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction)
       (WorkflowPlannedActionOf DocsMigrationEffect DocsMigrationAction)
       DocsMigrationActionReport
       Text
docsMigrationDryRunTransactionHooks =
  WorkflowObservedTransactionHooks
    { workflowTransactionMapError = id
    , workflowTransactionCompileEffects = compileDocsMigrationEffectPlan
    , workflowTransactionPartitionActions = partitionWorkflowGenericActions
    , workflowTransactionDryRunActions = fmap (docsMigrationActionReport DryRunActions False . workflowGenericPlannedAction)
    , workflowTransactionExecuteActions = \_actions -> Left "docs migration dry-run hooks cannot execute actions"
    , workflowTransactionCommitEvent =
        WorkflowEventCommitter (\_event -> Left "docs migration dry-run hooks cannot commit events")
    , workflowTransactionAfterCommit = \_state -> Left "docs migration dry-run hooks cannot run post-commit callbacks"
    , workflowTransactionFailureIsRetryable = const False
    }

docsMigrationTransactionHooksForInterpreter
  :: Monad m
  => DocsMigrationInterpreter m
  -> WorkflowObservedTransactionHooks
       m
       DocsMigrationSpec
       (WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction)
       (WorkflowPlannedActionOf DocsMigrationEffect DocsMigrationAction)
       DocsMigrationActionReport
       Text
docsMigrationTransactionHooksForInterpreter interpreter =
  WorkflowObservedTransactionHooks
    { workflowTransactionMapError = id
    , workflowTransactionCompileEffects = compileDocsMigrationEffectPlan
    , workflowTransactionPartitionActions = partitionWorkflowGenericActions
    , workflowTransactionDryRunActions = fmap (docsMigrationActionReport DryRunActions False . workflowGenericPlannedAction)
    , workflowTransactionExecuteActions =
        fmap Right . traverse (executeDocsMigrationAction interpreter ExecuteActions . workflowGenericPlannedAction)
    , workflowTransactionCommitEvent = WorkflowEventCommitter (\_event -> pure (Right ()))
    , workflowTransactionAfterCommit = \_state -> pure (Right ())
    , workflowTransactionFailureIsRetryable = const False
    }

docsMigrationDaemonTickResult
  :: WorkflowObservedTransactionResult
       DocsMigrationSpec
       (WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction)
       DocsMigrationActionReport
       FailureClassification
  -> DocsMigrationDaemonTickResult
docsMigrationDaemonTickResult result =
  let coreTick = WorkflowDaemon.workflowObservedDaemonTickResult result
   in
  DocsMigrationDaemonTickResult
    { docsMigrationDaemonPriorReplay = coreTick.workflowObservedDaemonPriorReplay
    , docsMigrationDaemonEvent = coreTick.workflowObservedDaemonEvent
    , docsMigrationDaemonState = coreTick.workflowObservedDaemonState
    , docsMigrationDaemonCommittedEvents = coreTick.workflowObservedDaemonCommittedEvents
    , docsMigrationDaemonCompiledEffects = coreTick.workflowObservedDaemonCompiledEffects
    , docsMigrationDaemonActionReports = coreTick.workflowObservedDaemonActionReports
    , docsMigrationDaemonAudit = coreTick.workflowObservedDaemonAudit
    }

docsMigrationDaemonCoreTickResult
  :: DocsMigrationDaemonTickResult
  -> WorkflowDaemon.WorkflowObservedDaemonTickResult
       DocsMigrationSpec
       (WorkflowCompiledEffectPlanOf DocsMigrationEffect DocsMigrationAction)
       DocsMigrationActionReport
       FailureClassification
docsMigrationDaemonCoreTickResult tick =
  WorkflowDaemon.WorkflowObservedDaemonTickResult
    { WorkflowDaemon.workflowObservedDaemonPriorReplay = tick.docsMigrationDaemonPriorReplay
    , WorkflowDaemon.workflowObservedDaemonEvent = tick.docsMigrationDaemonEvent
    , WorkflowDaemon.workflowObservedDaemonState = tick.docsMigrationDaemonState
    , WorkflowDaemon.workflowObservedDaemonCommittedEvents = tick.docsMigrationDaemonCommittedEvents
    , WorkflowDaemon.workflowObservedDaemonCompiledEffects = tick.docsMigrationDaemonCompiledEffects
    , WorkflowDaemon.workflowObservedDaemonPreCommitReports =
        workflowAuditPreCommitReports tick.docsMigrationDaemonAudit
    , WorkflowDaemon.workflowObservedDaemonPostCommitReports =
        workflowAuditPostCommitReports tick.docsMigrationDaemonAudit
    , WorkflowDaemon.workflowObservedDaemonActionReports = tick.docsMigrationDaemonActionReports
    , WorkflowDaemon.workflowObservedDaemonAudit = tick.docsMigrationDaemonAudit
    }

replayDocsMigrationEvents :: [DocsMigrationEvent] -> Either Text DocsMigrationReplayResult
replayDocsMigrationEvents events =
  case replayWorkflowEventLogDetailed @DocsMigrationSpec id events of
    Left failure ->
      Left (formatWorkflowReplayFailure failure)
    Right summary ->
      Right
        DocsMigrationReplayResult
          { docsMigrationReplayState = summary.workflowReplaySummaryState
          , docsMigrationReplayEffects = summary.workflowReplaySummaryEffects
          }

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
applyDocsMigrationEvent state (DocsMigrationWorkflowBlocked reason)
  | docsMigrationCanBlock state =
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
  let (preCommitEffects, postCommitEffects) =
        List.partition
          ((== PreCommit) . workflowEffectCommitOrder . docsMigrationEffectMetadata)
          effects
   in
  PlannedTransition
    { plannedEvent = event
    , plannedPreCommitEffects = preCommitEffects
    , plannedPostCommitEffects = postCommitEffects
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

docsMigrationEffectLabel :: DocsMigrationEffect -> Text
docsMigrationEffectLabel = \case
  StartDocsMigrationTurn {} -> "start-docs-migration-turn"
  WriteDocsMigrationDraft {} -> "write-docs-migration-draft"
  RunDocsMigrationValidation {} -> "run-docs-migration-validation"
  StopDocsMigrationDaemon -> "stop-docs-migration-daemon"

nonEmpty :: Text -> Text -> Text
nonEmpty candidate fallback =
  if candidate == "" then fallback else candidate
