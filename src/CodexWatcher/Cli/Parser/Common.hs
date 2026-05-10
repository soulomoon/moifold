{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Common
  ( domainOption
  , domainReader
  , eventsPathArgument
  , eventsPathOption
  , intOption
  , intOptionDefault
  , intReader
  , issueNumberReader
  , issueNumbersReader
  , maxParallelOption
  , maxParallelReader
  , optionalEndpointParser
  , parseIssueNumbersText
  , plannerThreadOption
  , pollSecondsDefault
  , pollSecondsOption
  , pollSecondsOptionDefault
  , pollSecondsReader
  , repoOption
  , requiredEndpointParser
  , reviewThreadIdsReader
  , scopeIssuesParser
  , staleSecondsDefault
  , staleSecondsOptionDefault
  , staleSecondsReader
  , stateDirOption
  , textOption
  , textOptionDefault
  , threadIdOption
  , turnIdOption
  , workdirOption
  , workdirOptionDefault
  ) where

import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))
import CodexWatcher.Core.Ids
  ( IssueNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  , ThreadId (..)
  , TurnId (..)
  )
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.Limits
  ( MaxParallel
  , PollSeconds
  , StaleSeconds
  , mkMaxParallel
  , mkPollSeconds
  , mkStaleSeconds
  )
import Data.Text (Text)
import Data.Text qualified as Text
import Options.Applicative
import Text.Read (readMaybe)

requiredEndpointParser :: Parser AppServerEndpoint
requiredEndpointParser =
  AppServerEndpoint
    <$> strOption (long "app-server-host" <> metavar "HOST" <> help "Codex app-server host")
    <*> intOption "app-server-port" "PORT" "Codex app-server port"
    <*> strOption (long "app-server-path" <> metavar "PATH" <> value "/" <> showDefault <> help "Codex app-server WebSocket path")

optionalEndpointParser :: Parser (Maybe AppServerEndpoint)
optionalEndpointParser =
  optional requiredEndpointParser

domainOption :: Parser Domain
domainOption =
  option domainReader (long "domain" <> metavar "pr-review|issue-implement|issue-planning" <> help "Watcher domain")

repoOption :: Parser RepoName
repoOption =
  RepoName <$> textOption "repo" "owner/name" "GitHub repository"

eventsPathOption :: Parser FilePath
eventsPathOption =
  strOption (long "events" <> metavar "events.jsonl" <> help "Canonical event log path")

eventsPathArgument :: Parser FilePath
eventsPathArgument =
  argument str (metavar "events.jsonl")

stateDirOption :: Parser FilePath
stateDirOption =
  strOption (long "state-dir" <> metavar "PATH" <> help "Watcher state directory")

workdirOption :: Parser FilePath
workdirOption =
  strOption (long "workdir" <> metavar "PATH" <> help "Repository checkout working directory")

workdirOptionDefault :: Parser FilePath
workdirOptionDefault =
  strOption (long "workdir" <> metavar "PATH" <> value "." <> showDefault <> help "Repository checkout working directory")

threadIdOption :: Parser ThreadId
threadIdOption =
  ThreadId <$> textOption "thread-id" "THREAD_ID" "App-server thread id"

plannerThreadOption :: Parser ThreadId
plannerThreadOption =
  ThreadId <$> strOption (long "planner-thread-id" <> long "thread-id" <> metavar "THREAD_ID" <> help "Planner app-server thread id")

scopeIssuesParser :: Parser [IssueNumber]
scopeIssuesParser =
  combineScopes
    <$> optional (option (issueNumberReader "--scope-issue") (long "scope-issue" <> metavar "NUMBER" <> help "Restrict issue planning to this issue and its sub-issues"))
    <*> optional (option (issueNumbersReader "--scope-issues") (long "scope-issues" <> metavar "1,2" <> help "Restrict issue planning to these issues and their sub-issues"))
 where
  combineScopes maybeSingle maybeMany =
    maybe [] (: []) maybeSingle <> maybe [] id maybeMany

turnIdOption :: Parser TurnId
turnIdOption =
  TurnId <$> textOption "turn-id" "TURN_ID" "App-server turn id"

textOption :: String -> String -> String -> Parser Text
textOption optionName metavarName helpText =
  Text.pack <$> strOption (long optionName <> metavar metavarName <> help helpText)

textOptionDefault :: String -> Text -> String -> String -> Parser Text
textOptionDefault optionName defaultValue metavarName helpText =
  Text.pack
    <$> strOption
      ( long optionName
          <> metavar metavarName
          <> value (Text.unpack defaultValue)
          <> showDefault
          <> help helpText
      )

intOption :: String -> String -> String -> Parser Int
intOption optionName metavarName helpText =
  option intReader (long optionName <> metavar metavarName <> help helpText)

intOptionDefault :: String -> Int -> String -> String -> Parser Int
intOptionDefault optionName defaultValue metavarName helpText =
  option intReader (long optionName <> metavar metavarName <> value defaultValue <> showDefault <> help helpText)

maxParallelOption :: String -> String -> String -> Parser MaxParallel
maxParallelOption optionName metavarName helpText =
  option maxParallelReader (long optionName <> metavar metavarName <> help helpText)

pollSecondsOption :: String -> String -> String -> Parser PollSeconds
pollSecondsOption optionName metavarName helpText =
  option pollSecondsReader (long optionName <> metavar metavarName <> help helpText)

pollSecondsOptionDefault :: String -> Int -> String -> String -> Parser PollSeconds
pollSecondsOptionDefault optionName defaultValue metavarName helpText =
  option pollSecondsReader (long optionName <> metavar metavarName <> value (pollSecondsDefault defaultValue) <> showDefaultWith show <> help helpText)

staleSecondsOptionDefault :: String -> Int -> String -> String -> Parser StaleSeconds
staleSecondsOptionDefault optionName defaultValue metavarName helpText =
  option staleSecondsReader (long optionName <> metavar metavarName <> value (staleSecondsDefault defaultValue) <> showDefaultWith show <> help helpText)

domainReader :: ReadM Domain
domainReader =
  eitherReader \case
    "pr-review" -> Right PrReview
    "issue-implement" -> Right IssueImplement
    "issue-planning" -> Right IssuePlanning
    other -> Left ("unsupported watcher domain: " <> other)

intReader :: ReadM Int
intReader =
  eitherReader \input ->
    case readMaybe input of
      Just parsed -> Right parsed
      Nothing -> Left ("invalid integer: " <> input)

maxParallelReader :: ReadM MaxParallel
maxParallelReader =
  eitherReader \input ->
    case readMaybe input >>= mkMaxParallel of
      Just parsed -> Right parsed
      Nothing -> Left ("max-parallel must be a positive integer: " <> input)

pollSecondsReader :: ReadM PollSeconds
pollSecondsReader =
  eitherReader \input ->
    case readMaybe input >>= mkPollSeconds of
      Just parsed -> Right parsed
      Nothing -> Left ("poll seconds must be a positive integer: " <> input)

staleSecondsReader :: ReadM StaleSeconds
staleSecondsReader =
  eitherReader \input ->
    case readMaybe input >>= mkStaleSeconds of
      Just parsed -> Right parsed
      Nothing -> Left ("stale seconds must be a positive integer: " <> input)

pollSecondsDefault :: Int -> PollSeconds
pollSecondsDefault seconds =
  case mkPollSeconds seconds of
    Just parsed -> parsed
    Nothing -> error ("invalid default poll seconds: " <> show seconds)

staleSecondsDefault :: Int -> StaleSeconds
staleSecondsDefault seconds =
  case mkStaleSeconds seconds of
    Just parsed -> parsed
    Nothing -> error ("invalid default stale seconds: " <> show seconds)

issueNumbersReader :: String -> ReadM [IssueNumber]
issueNumbersReader flagName =
  eitherReader \input ->
    case parseIssueNumbersText flagName (Text.pack input) of
      Right issueNumbers -> Right issueNumbers
      Left errorMessage -> Left (Text.unpack errorMessage)

issueNumberReader :: String -> ReadM IssueNumber
issueNumberReader flagName =
  eitherReader \input ->
    case parseIssueNumbersText flagName (Text.pack input) of
      Right [issueNumber'] -> Right issueNumber'
      Right _ -> Left ("expected one issue number for " <> flagName)
      Left errorMessage -> Left (Text.unpack errorMessage)

reviewThreadIdsReader :: ReadM [ReviewThreadId]
reviewThreadIdsReader =
  eitherReader \input ->
    Right (ReviewThreadId . Text.strip . Text.pack <$> filter (not . null) (splitComma input))

parseIssueNumbersText :: String -> Text -> Either Text [IssueNumber]
parseIssueNumbersText flagName text =
  traverse parsePart (filter (not . Text.null) (Text.strip <$> Text.splitOn "," text))
 where
  parsePart part =
    case readMaybe (Text.unpack part) of
      Just parsedNumber | parsedNumber > 0 -> Right (IssueNumber parsedNumber)
      _ -> Left ("invalid issue number for " <> Text.pack flagName <> ": " <> part)

splitComma :: String -> [String]
splitComma [] = []
splitComma text =
  case break (== ',') text of
    (part, []) -> [part]
    (part, _comma : rest) -> part : splitComma rest
