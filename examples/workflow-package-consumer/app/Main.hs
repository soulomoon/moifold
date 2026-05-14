{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module Main (main) where

import CodexWatcher.AppServerProtocol
  ( AppServerRequest (..)
  , planCollaborationMode
  )
import CodexWatcher.Workflow.Agent.Codex.Protocol
  ( agentThreadReadRequest
  , agentThreadStartRequest
  , agentTurnStartRequest
  )
import CodexWatcher.Workflow.Agent.Ids
  ( RequestId (..)
  , ThreadId (..)
  , TurnId (..)
  )
import CodexWatcher.Workflow.Agent.Types
  ( AgentRoleId (..)
  , AgentThreadPlan (..)
  , AgentTurnPlan (..)
  , AgentTurnStart (..)
  , TurnRef (..)
  , agentTurnStartRef
  )
import CodexWatcher.Workflow.DSL
  ( advance
  , emit
  , transitionEffects
  , transitionEvent
  )
import CodexWatcher.Workflow.GitHub.Command
  ( GitHubCommandSpec (..)
  , ghPrListByHeadCommand
  , ghPrViewCommand
  , ghPrViewRemoteFields
  , gitPushDryRunCommand
  )
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , PrNumber (..)
  , RepoName (..)
  )
import CodexWatcher.Workflow.Spec
  ( PlannedTransition (..)
  , WorkflowSpec (..)
  , workflowPlanObservation
  )
import Data.Aeson (encode)
import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text

data ConsumerSpec

data ConsumerState
  = WaitingForReview
  | ReviewComplete
  deriving (Eq, Show)

data ConsumerEvent
  = ReviewRequested
  | ReviewAccepted
  deriving (Eq, Show)

data ConsumerObservation
  = ReviewerAccepted
  deriving (Eq, Show)

data ConsumerObservedTick = ConsumerObservedTick
  { observedState :: ConsumerState
  , observedTransition :: PlannedTransition ConsumerSpec
  }

data ConsumerEffect
  = NotifyReviewer
  | RecordDecision
  deriving (Eq, Show)

instance WorkflowSpec ConsumerSpec where
  type WorkflowState ConsumerSpec = ConsumerState
  type WorkflowEvent ConsumerSpec = ConsumerEvent
  type WorkflowObservation ConsumerSpec = ConsumerObservation
  type WorkflowObservedTick ConsumerSpec = ConsumerObservedTick
  type WorkflowEffect ConsumerSpec = ConsumerEffect
  type WorkflowEffectPlan ConsumerSpec = [ConsumerEffect]
  type WorkflowReplayResult ConsumerSpec = ConsumerState
  type WorkflowError ConsumerSpec = Text

  workflowInitialEvent ReviewRequested =
    Right (WaitingForReview, [NotifyReviewer])
  workflowInitialEvent ReviewAccepted =
    Left "review cannot be accepted before it is requested"

  workflowApplyEvent WaitingForReview ReviewAccepted =
    Right (ReviewComplete, [RecordDecision])
  workflowApplyEvent _ event =
    Left ("event is not valid in the current state: " <> workflowEventLabel @ConsumerSpec event)

  workflowObserve WaitingForReview ReviewerAccepted =
    Right
      ConsumerObservedTick
        { observedState = ReviewComplete
        , observedTransition = workflowPlanTransition @ConsumerSpec ReviewAccepted [RecordDecision]
        }
  workflowObserve ReviewComplete ReviewerAccepted =
    Left "review is already complete"

  workflowObservedTransition =
    observedTransition

  workflowObservedState =
    observedState

  workflowPlanTransition event effects =
    PlannedTransition
      { plannedEvent = event
      , plannedPreCommitEffects = effects
      , plannedPostCommitEffects = []
      }

  workflowReplayEvents [] =
    Left "expected at least the initial event"
  workflowReplayEvents (firstEvent : rest) = do
    (initialState, _) <- workflowInitialEvent @ConsumerSpec firstEvent
    foldl apply (Right initialState) rest
   where
    apply result event = do
      state <- result
      fst <$> workflowApplyEvent @ConsumerSpec state event

  workflowReplayState =
    id

  workflowValidateEffects _ _ =
    Right ()

  workflowEffectPlanEffects =
    id

  workflowEffectAllowed _ _ =
    Right ()

  workflowIsTerminal ReviewComplete =
    True
  workflowIsTerminal WaitingForReview =
    False

  workflowStateLabel WaitingForReview =
    "waiting-for-review"
  workflowStateLabel ReviewComplete =
    "review-complete"

  workflowEventLabel ReviewRequested =
    "review-requested"
  workflowEventLabel ReviewAccepted =
    "review-accepted"

  workflowObservationLabel ReviewerAccepted =
    "reviewer-accepted"

  workflowEffectLabel NotifyReviewer =
    "notify-reviewer"
  workflowEffectLabel RecordDecision =
    "record-decision"

main :: IO ()
main = do
  Text.putStrLn "agent-workflow-core"
  runCoreExample
  Text.putStrLn ""
  Text.putStrLn "agent-workflow-codex"
  runCodexExample
  Text.putStrLn ""
  Text.putStrLn "agent-workflow-github"
  runGitHubExample

runCoreExample :: IO ()
runCoreExample = do
  let plannedObservation =
        workflowPlanObservation @ConsumerSpec WaitingForReview ReviewerAccepted
      dslTransition =
        advance @ConsumerSpec ReviewAccepted do
          emit @ConsumerSpec [RecordDecision]
          pure ("transitioned" :: Text)
  case plannedObservation of
    Left err ->
      Text.putStrLn ("observation failed: " <> err)
    Right planned ->
      Text.putStrLn
        ( "observation -> event="
            <> workflowEventLabel @ConsumerSpec planned.plannedEvent
            <> ", effects="
            <> labels (workflowEffectLabel @ConsumerSpec) planned.plannedPreCommitEffects
        )
  case dslTransition of
    Left err ->
      Text.putStrLn ("dsl failed: " <> err)
    Right transition ->
      Text.putStrLn
        ( "dsl -> event="
            <> workflowEventLabel @ConsumerSpec (transitionEvent transition)
            <> ", effects="
            <> labels (workflowEffectLabel @ConsumerSpec) (transitionEffects transition)
        )

runCodexExample :: IO ()
runCodexExample = do
  let examplePlannerRoleId = AgentRoleId "consumer-example-planner"
      threadPlan =
        AgentThreadPlan
          { agentThreadPlanRoleId = examplePlannerRoleId
          , agentThreadPlanCwd = "/workspace/example"
          , agentThreadPlanApprovalPolicy = "never"
          , agentThreadPlanSandbox = "read-only"
          , agentThreadPlanModel = "gpt-5"
          , agentThreadPlanDeveloperInstructions = "Return one short package-consumer note."
          }
      turnPlan =
        AgentTurnPlan
          { agentTurnPlanRoleId = AgentRoleId "consumer-example"
          , agentTurnPlanThreadId = ThreadId "thread-example"
          , agentTurnPlanCwd = "/workspace/example"
          , agentTurnPlanEffort = "low"
          , agentTurnPlanModel = "gpt-5"
          , agentTurnPlanApprovalPolicy = "never"
          , agentTurnPlanSandboxPolicy = "read-only"
          , agentTurnPlanInput = "Summarize the workflow package boundary."
          , agentTurnPlanOutputSchema = Nothing
          , agentTurnPlanCollaborationMode =
              Just (planCollaborationMode "Stay within package-facing APIs." "gpt-5" "low")
          }
      turnRef =
        agentTurnStartRef
          AgentTurnStart
            { agentTurnStartRoleId = AgentRoleId "consumer-example"
            , agentTurnStartThreadId = ThreadId "thread-example"
            , agentTurnStartTurnId = TurnId "turn-example"
            }
  printRequestSummary (agentThreadStartRequest (RequestId 1) threadPlan)
  printRequestSummary (agentTurnStartRequest (RequestId 2) turnPlan)
  printRequestSummary (agentThreadReadRequest (RequestId 3) (turnRef :: TurnRef () ()))

runGitHubExample :: IO ()
runGitHubExample = do
  let repo = RepoName "soulomoon/moifold"
      branch = BranchName "codex/example-consumer"
      workdir = "/workspace/example"
  printCommandSummary (ghPrListByHeadCommand repo branch "open")
  printCommandSummary (ghPrViewCommand repo (PrNumber 47) ghPrViewRemoteFields)
  printCommandSummary (gitPushDryRunCommand workdir branch)

printRequestSummary :: AppServerRequest -> IO ()
printRequestSummary request = do
  Text.putStrLn
    ( "request id="
        <> Text.pack (show request.requestId)
        <> ", method="
        <> request.requestMethod
    )
  LBS.putStrLn (encode request)

printCommandSummary :: GitHubCommandSpec -> IO ()
printCommandSummary command =
  Text.putStrLn
    ( Text.pack command.githubCommand
        <> " "
        <> Text.pack (unwords command.githubCommandArgs)
        <> " cwd="
        <> maybe "<none>" Text.pack command.githubCommandCwd
        <> " stdin-bytes="
        <> Text.pack (show (Text.length command.githubCommandStdin))
    )

labels :: (a -> Text) -> [a] -> Text
labels label =
  Text.intercalate "," . fmap label
