{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Moifold.PrReview.Agent
  ( prReviewReviewerAgentRole
  , prReviewWorkerAgentRole
  ) where

import CodexWatcher.AppServerClient (AppServerTurn)
import CodexWatcher.Domain.PrReview.Protocol (ReviewerOutcome (..), WorkerOutcome (..))
import CodexWatcher.Domain.PrReview.TurnClassifier
  ( classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  )
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation (..))
import CodexWatcher.Turn.Classifier.Common (TurnCompletion (..), classifyTurnCompletion)
import CodexWatcher.TurnOutput
  ( prReviewWorkerTurnOutputSchema
  , reviewerTurnOutputSchema
  )
import CodexWatcher.Core.Ids (CommitSha)
import CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , ClassifiedAgentOutput (..)
  )
import Data.Text (Text)
import Data.Text qualified as Text

prReviewWorkerAgentRole :: AgentRole Text PrReviewObservation
prReviewWorkerAgentRole =
  AgentRole
    { agentRoleName = "pr-review-worker"
    , renderAgentInput = \input -> input
    , agentOutputSchema = Just prReviewWorkerTurnOutputSchema
    , agentClassifyTurn = classifyPrReviewWorkerAgentTurn
    }

prReviewReviewerAgentRole :: CommitSha -> AgentRole Text PrReviewObservation
prReviewReviewerAgentRole commit =
  AgentRole
    { agentRoleName = "pr-reviewer"
    , renderAgentInput = \input -> input
    , agentOutputSchema = Just reviewerTurnOutputSchema
    , agentClassifyTurn = classifyPrReviewReviewerAgentTurn commit
    }

classifyPrReviewWorkerAgentTurn :: AppServerTurn -> Either Text (ClassifiedAgentOutput PrReviewObservation)
classifyPrReviewWorkerAgentTurn turn =
  case classifyPrReviewWorkerTurn turn of
    Nothing ->
      Left "turn still running"
    Just observation@(ObservedWorkerOutcome outcome) ->
      Right (ClassifiedAgentOutput (workerOutputClass turn outcome) observation)
    Just observation ->
      Right (ClassifiedAgentOutput AgentComplete observation)

classifyPrReviewReviewerAgentTurn :: CommitSha -> AppServerTurn -> Either Text (ClassifiedAgentOutput PrReviewObservation)
classifyPrReviewReviewerAgentTurn commit turn =
  case classifyPrReviewReviewerTurn commit turn of
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
