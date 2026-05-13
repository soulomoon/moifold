{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Observe
  ( observeOnceParser
  ) where

import CodexWatcher.Cli.Parser.Common
  ( domainOption
  , eventsPathOption
  , intOption
  , optionalEndpointParser
  , repoOption
  , reviewThreadIdsReader
  , stateDirOption
  , textOption
  , threadIdOption
  , turnIdOption
  , workdirOptionDefault
  )
import CodexWatcher.Cli.Types (ObserveOnceCli (..))
import CodexWatcher.Workflow.Agent.Ids (TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber (..))
import Options.Applicative

observeOnceParser :: Parser ObserveOnceCli
observeOnceParser =
  ObserveOnceCli
    <$> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOptionDefault
    <*> domainOption
    <*> strOption (long "observation" <> metavar "NAME" <> help "Observation name for the selected domain")
    <*> switch (long "execute" <> help "Append event and execute compiled effects")
    <*> optionalEndpointParser
    <*> optional threadIdOption
    <*> optional turnIdOption
    <*> optional (TurnId <$> textOption "implementation-turn-id" "TURN_ID" "Implementation turn id emitted by plan completion")
    <*> optional (PrNumber <$> intOption "pr-number" "NUMBER" "Pull request number")
    <*> optional (CommitSha <$> textOption "commit-sha" "SHA" "Commit SHA")
    <*> optional (CommitSha <$> textOption "merge-commit-sha" "SHA" "Merge commit SHA")
    <*> optional (textOption "reason" "TEXT" "Blocked or incomplete reason")
    <*> optional (textOption "plan-markdown" "MARKDOWN" "Issue implementation plan markdown")
    <*> fmap (maybe [] id) (optional (option reviewThreadIdsReader (long "review-thread-ids" <> metavar "ID,ID" <> help "Unresolved review thread ids")))
    <*> optional (textOption "comment" "TEXT" "Clean review comment")
