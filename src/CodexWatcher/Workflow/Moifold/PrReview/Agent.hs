{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Moifold.PrReview.Agent
  ( prReviewReviewerAgentRole
  , prReviewWorkerAgentRole
  ) where

import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
import CodexWatcher.Domain.PrReview.Protocol (ReviewerOutcome (..), WorkerOutcome (..))
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation (..))
import CodexWatcher.Turn.Classifier.Common (TurnCompletion (..), classifyTurnCompletion)
import CodexWatcher.TurnOutput
  ( TurnOutputContract
  , prReviewWorkerTurnOutputContract
  , reviewerTurnOutputContract
  , turnOutputContractClassify
  , turnOutputContractSchema
  )
import CodexWatcher.Workflow.GitHub.Ids (CommitSha)
import CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , AgentSideEffectScope (..)
  , ClassifiedAgentOutput (..)
  , defaultAgentRetryPolicy
  )
import Data.Text (Text)
import Data.Text qualified as Text

prReviewWorkerAgentRole :: AgentRole Text PrReviewObservation
prReviewWorkerAgentRole =
  let contract = prReviewWorkerTurnOutputContract
   in
  AgentRole
    { agentRoleName = "pr-review-worker"
    , renderAgentInput = \input -> input
    , agentOutputSchema = Just (turnOutputContractSchema contract)
    , agentRetryPolicy = defaultAgentRetryPolicy
    , agentSideEffectScope = AgentWritesWorktree
    , agentClassifyTurn = classifyPrReviewWorkerAgentTurn contract
    }

prReviewReviewerAgentRole :: CommitSha -> AgentRole Text PrReviewObservation
prReviewReviewerAgentRole commit =
  let contract = reviewerTurnOutputContract commit
   in
  AgentRole
    { agentRoleName = "pr-reviewer"
    , renderAgentInput = \input -> input
    , agentOutputSchema = Just (turnOutputContractSchema contract)
    , agentRetryPolicy = defaultAgentRetryPolicy
    , agentSideEffectScope = AgentReadOnly
    , agentClassifyTurn = classifyPrReviewReviewerAgentTurn contract
    }

classifyPrReviewWorkerAgentTurn :: TurnOutputContract PrReviewObservation -> AppServerTurn -> Either Text (ClassifiedAgentOutput PrReviewObservation)
classifyPrReviewWorkerAgentTurn contract turn =
  case turnOutputContractClassify contract turn of
    Nothing ->
      Left "turn still running"
    Just observation@(ObservedWorkerOutcome outcome) ->
      Right (ClassifiedAgentOutput (workerOutputClass turn outcome) observation)
    Just observation ->
      Right (ClassifiedAgentOutput AgentComplete observation)

classifyPrReviewReviewerAgentTurn :: TurnOutputContract PrReviewObservation -> AppServerTurn -> Either Text (ClassifiedAgentOutput PrReviewObservation)
classifyPrReviewReviewerAgentTurn contract turn =
  case turnOutputContractClassify contract turn of
    Nothing ->
      Left "turn still running"
    Just observation@(ObservedReviewerOutcome outcome) ->
      Right (ClassifiedAgentOutput (reviewerOutputClass outcome) observation)
    Just observation ->
      Right (ClassifiedAgentOutput AgentComplete observation)

workerOutputClass :: AppServerTurn -> WorkerOutcome -> AgentOutputClass
workerOutputClass turn = \case
  WorkerCompleted ->
    AgentComplete
  WorkerIncomplete reason
    | completedWithUnstructuredOutput turn
        || "without structured outcome" `Text.isInfixOf` reason ->
        AgentMalformed
    | otherwise ->
        AgentIncomplete
  WorkerBlocked {} ->
    AgentBlocked

reviewerOutputClass :: ReviewerOutcome -> AgentOutputClass
reviewerOutputClass = \case
  ReviewerClean {} ->
    AgentClean
  ReviewerProblemsAdded {} ->
    AgentProblems
  ReviewerIncomplete reason
    | "reviewer-state JSON" `Text.isInfixOf` reason
        || "missing required fields" `Text.isInfixOf` reason ->
        AgentMalformed
    | otherwise ->
        AgentIncomplete
  ReviewerBlocked {} ->
    AgentBlocked

completedWithUnstructuredOutput :: AppServerTurn -> Bool
completedWithUnstructuredOutput turn =
  case classifyTurnCompletion turn of
    TurnCompleted (Just output) ->
      not (Text.null (Text.strip output))
        && not ("\"outcome\"" `Text.isInfixOf` output)
    _ ->
      False
