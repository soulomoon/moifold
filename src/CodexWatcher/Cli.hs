{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli
  ( CliCommand (..)
  , GuardWatcherCli (..)
  , HealthcheckCli (..)
  , IssueFanoutCli (..)
  , LoopCli (..)
  , ObserveOnceCli (..)
  , RepairInvalidStateCli (..)
  , RenderServiceCli (..)
  , StopDaemonCli (..)
  , cliCommandParserInfo
  , cliDomainName
  , execCliCommandParser
  , parseCliCommand
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.Types
  ( CommitSha (..)
  , Domain (..)
  , IssueNumber (..)
  , MaxParallel
  , PollSeconds
  , PrNumber (..)
  , ReviewThreadId (..)
  , RepoName (..)
  , StaleSeconds
  , ThreadId (..)
  , TurnId (..)
  , mkMaxParallel
  , mkPollSeconds
  , mkStaleSeconds
  )
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Options.Applicative
import Text.Read (readMaybe)

data CliCommand
  = CliReplayEvents FilePath
  | CliHealthcheck HealthcheckCli
  | CliClearRuntimeLease FilePath
  | CliStopDaemon StopDaemonCli
  | CliRenderService RenderServiceCli
  | CliIssueFanout IssueFanoutCli
  | CliObserveOnce ObserveOnceCli
  | CliRunLoop LoopCli
  | CliGuardWatcher GuardWatcherCli
  | CliRepairInvalidState RepairInvalidStateCli
  deriving stock (Eq, Show, Generic)

data HealthcheckCli = HealthcheckCli
  { healthcheckCliStateRoot :: FilePath
  , healthcheckCliRepo :: Maybe RepoName
  , healthcheckCliEndpoint :: Maybe AppServerEndpoint
  }
  deriving stock (Eq, Show, Generic)

data StopDaemonCli = StopDaemonCli
  { stopDaemonCliPidFile :: Maybe FilePath
  , stopDaemonCliStateDir :: Maybe FilePath
  , stopDaemonCliDomain :: Maybe Domain
  }
  deriving stock (Eq, Show, Generic)

data RenderServiceCli = RenderServiceCli
  { renderServiceCliName :: Text
  , renderServiceCliDomain :: Domain
  , renderServiceCliEventsPath :: FilePath
  , renderServiceCliStateDir :: FilePath
  , renderServiceCliRepo :: RepoName
  , renderServiceCliWorkdir :: FilePath
  , renderServiceCliEndpoint :: AppServerEndpoint
  , renderServiceCliExecutable :: Maybe FilePath
  , renderServiceCliPlannerThread :: Maybe ThreadId
  , renderServiceCliPollSeconds :: PollSeconds
  , renderServiceCliLogDir :: Maybe FilePath
  , renderServiceCliRestartSeconds :: Int
  , renderServiceCliRotateCount :: Int
  , renderServiceCliImplementersRoot :: Maybe FilePath
  , renderServiceCliStartChildren :: Bool
  }
  deriving stock (Eq, Show, Generic)

data IssueFanoutCli = IssueFanoutCli
  { issueFanoutCliRepo :: RepoName
  , issueFanoutCliImplementersRoot :: FilePath
  , issueFanoutCliMaxParallel :: MaxParallel
  , issueFanoutCliOpenIssues :: Maybe [IssueNumber]
  , issueFanoutCliActiveIssues :: Maybe [IssueNumber]
  , issueFanoutCliExecute :: Bool
  , issueFanoutCliStartChildren :: Bool
  , issueFanoutCliEndpoint :: Maybe AppServerEndpoint
  , issueFanoutCliWorkdirRoot :: Maybe FilePath
  , issueFanoutCliBranchPrefix :: Text
  , issueFanoutCliThreadPrefix :: Text
  , issueFanoutCliPollSeconds :: Maybe PollSeconds
  , issueFanoutCliChildPollSeconds :: Maybe PollSeconds
  }
  deriving stock (Eq, Show, Generic)

data ObserveOnceCli = ObserveOnceCli
  { observeCliEventsPath :: FilePath
  , observeCliStateDir :: FilePath
  , observeCliRepo :: RepoName
  , observeCliWorkdir :: FilePath
  , observeCliDomain :: Domain
  , observeCliObservation :: String
  , observeCliExecute :: Bool
  , observeCliEndpoint :: Maybe AppServerEndpoint
  , observeCliThreadId :: Maybe ThreadId
  , observeCliTurnId :: Maybe TurnId
  , observeCliImplementationTurnId :: Maybe TurnId
  , observeCliPrNumber :: Maybe PrNumber
  , observeCliCommitSha :: Maybe CommitSha
  , observeCliMergeCommitSha :: Maybe CommitSha
  , observeCliReason :: Maybe Text
  , observeCliPlanMarkdown :: Maybe Text
  , observeCliReviewThreadIds :: [ReviewThreadId]
  , observeCliComment :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data RepairInvalidStateCli = RepairInvalidStateCli
  { repairCliEventsPath :: FilePath
  , repairCliStateDir :: FilePath
  , repairCliExecute :: Bool
  }
  deriving stock (Eq, Show, Generic)

data LoopCli = LoopCli
  { loopCliDomain :: Domain
  , loopCliEventsPath :: FilePath
  , loopCliStateDir :: FilePath
  , loopCliRepo :: RepoName
  , loopCliWorkdir :: FilePath
  , loopCliEndpoint :: AppServerEndpoint
  , loopCliPollSeconds :: PollSeconds
  , loopCliExecute :: Bool
  , loopCliLoop :: Bool
  , loopCliIterations :: Maybe Int
  , loopCliPidFile :: Maybe FilePath
  , loopCliPlannerThread :: Maybe ThreadId
  , loopCliScopeIssues :: [IssueNumber]
  , loopCliImplementersRoot :: Maybe FilePath
  , loopCliOpenIssues :: Maybe [IssueNumber]
  , loopCliActiveIssues :: Maybe [IssueNumber]
  , loopCliImplementerWorkdirRoot :: Maybe FilePath
  , loopCliWorkdirRoot :: Maybe FilePath
  , loopCliBranchPrefix :: Text
  , loopCliThreadPrefix :: Text
  , loopCliStartChildren :: Bool
  , loopCliChildPollSeconds :: Maybe PollSeconds
  }
  deriving stock (Eq, Show, Generic)

data GuardWatcherCli = GuardWatcherCli
  { guardCliLoop :: LoopCli
  , guardCliPidFile :: Maybe FilePath
  , guardCliPollSeconds :: PollSeconds
  , guardCliStaleSeconds :: StaleSeconds
  , guardCliRepairCwd :: Maybe FilePath
  }
  deriving stock (Eq, Show, Generic)

execCliCommandParser :: IO CliCommand
execCliCommandParser =
  customExecParser parserPrefs cliCommandParserInfo

parseCliCommand :: [String] -> Either String CliCommand
parseCliCommand args =
  case execParserPure parserPrefs cliCommandParserInfo args of
    Success parsedCommand -> Right parsedCommand
    Failure failure -> Left (fst (renderFailure failure "codex-watcher-hs"))
    CompletionInvoked completion -> Left (show completion)

cliCommandParserInfo :: ParserInfo CliCommand
cliCommandParserInfo =
  info
    (helper <*> cliCommandParser)
    ( fullDesc
        <> progDesc "Typed Haskell watcher runtime"
        <> header "codex-watcher-hs"
    )

parserPrefs :: ParserPrefs
parserPrefs =
  prefs showHelpOnEmpty

cliCommandParser :: Parser CliCommand
cliCommandParser =
  hsubparser
    ( command "replay-events" (info (CliReplayEvents <$> eventsPathArgument) (progDesc "Replay a canonical watcher events.jsonl file"))
        <> command "healthcheck" (info (CliHealthcheck <$> healthcheckParser) (progDesc "Run the read-only watcher healthcheck"))
        <> command "clear-runtime-lease" (info clearRuntimeLeaseParser (progDesc "Clear an inactive Haskell watcher runtime lease"))
        <> command "stop-daemon" (info (CliStopDaemon <$> stopDaemonParser) (progDesc "Send TERM to a Haskell watcher daemon"))
        <> command "render-service" (info (CliRenderService <$> renderServiceParser) (progDesc "Render a systemd unit and logrotate config"))
        <> command "issue-fanout" (info (CliIssueFanout <$> issueFanoutParser) (progDesc "Plan or create issue implementer child watcher state"))
        <> command "observe-once" (info (CliObserveOnce <$> observeOnceParser) (progDesc "Apply one explicit typed watcher observation"))
        <> command "run-pr-review" (info (CliRunLoop <$> loopParser PrReview) (progDesc "Run one or more PR review watcher loop iterations"))
        <> command "run-issue-implement" (info (CliRunLoop <$> loopParser IssueImplement) (progDesc "Run one or more issue implementation watcher loop iterations"))
        <> command "run-issue-planning" (info (CliRunLoop <$> loopParser IssuePlanning) (progDesc "Run one or more issue planning watcher loop iterations"))
        <> command "guard-issue-planning" (info (CliGuardWatcher <$> guardIssuePlanningParser) (progDesc "Guard an issue planning watcher and launch a repair thread on failure"))
        <> command "guard-issue-implement" (info (CliGuardWatcher <$> guardWatcherParser IssueImplement) (progDesc "Guard an issue implementer watcher and launch a repair thread on failure"))
        <> command "guard-pr-review" (info (CliGuardWatcher <$> guardWatcherParser PrReview) (progDesc "Guard a PR review watcher and launch a repair thread on failure"))
        <> command "repair-invalid-state" (info (CliRepairInvalidState <$> repairInvalidStateParser) (progDesc "Plan or apply a deterministic repair for an invalid watcher event log"))
    )

healthcheckParser :: Parser HealthcheckCli
healthcheckParser =
  HealthcheckCli
    <$> strOption
      ( long "state-root"
          <> metavar "PATH"
          <> value "/workspace/artifacts"
          <> showDefault
          <> help "Root containing watcher state directories"
      )
    <*> optional repoOption
    <*> optionalEndpointParser

clearRuntimeLeaseParser :: Parser CliCommand
clearRuntimeLeaseParser =
  CliClearRuntimeLease <$> stateDirOption

stopDaemonParser :: Parser StopDaemonCli
stopDaemonParser =
  StopDaemonCli
    <$> optional (strOption (long "pid-file" <> metavar "PATH" <> help "Explicit daemon pid file"))
    <*> optional stateDirOption
    <*> optional domainOption

renderServiceParser :: Parser RenderServiceCli
renderServiceParser =
  RenderServiceCli
    <$> textOption "name" "NAME" "Service name"
    <*> domainOption
    <*> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOption
    <*> requiredEndpointParser
    <*> optional (strOption (long "executable" <> metavar "PATH" <> help "Executable path to embed in the service"))
    <*> optional plannerThreadOption
    <*> pollSecondsOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> optional (strOption (long "log-dir" <> metavar "PATH" <> help "Directory for daemon logs"))
    <*> intOptionDefault "restart-seconds" 10 "SECONDS" "systemd restart delay"
    <*> intOptionDefault "rotate" 14 "COUNT" "logrotate retention count"
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> switch (long "start-children" <> help "Start issue implementer children after planning fanout")

issueFanoutParser :: Parser IssueFanoutCli
issueFanoutParser =
  IssueFanoutCli
    <$> repoOption
    <*> strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root")
    <*> maxParallelOption "max-parallel" "N" "Maximum concurrent implementers"
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active"))
    <*> switch (long "execute" <> help "Write child watcher state instead of printing it")
    <*> switch (long "start-children" <> help "Print or start child watcher loop commands")
    <*> optionalEndpointParser
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for child workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Child branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Child app-server thread prefix"
    <*> optional (pollSecondsOption "poll-seconds" "SECONDS" "Child polling interval")
    <*> optional (pollSecondsOption "child-poll-seconds" "SECONDS" "Child polling interval override")

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

repairInvalidStateParser :: Parser RepairInvalidStateCli
repairInvalidStateParser =
  RepairInvalidStateCli
    <$> eventsPathOption
    <*> stateDirOption
    <*> switch (long "execute" <> help "Archive and rewrite events.jsonl plus compatibility state files")

loopParser :: Domain -> Parser LoopCli
loopParser domain =
  LoopCli
    <$> pure domain
    <*> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOptionDefault
    <*> requiredEndpointParser
    <*> pollSecondsOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> switch (long "execute" <> help "Append observed events and execute compiled effects")
    <*> switch (long "loop" <> help "Continue polling until stopped")
    <*> optional (intOption "iterations" "N" "Maximum loop iterations")
    <*> optional (strOption (long "pid-file" <> metavar "PATH" <> help "Override daemon pid file"))
    <*> optional plannerThreadOption
    <*> scopeIssuesParser
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider during planning fanout"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active during planning fanout"))
    <*> optional (strOption (long "implementer-workdir-root" <> metavar "PATH" <> help "Root for issue implementer child workdirs"))
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for generated workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Issue implementer branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Issue implementer thread prefix"
    <*> switch (long "start-children" <> help "Print or start child watcher loop commands after planning fanout")
    <*> optional (pollSecondsOption "child-poll-seconds" "SECONDS" "Child polling interval override")

guardIssuePlanningParser :: Parser GuardWatcherCli
guardIssuePlanningParser =
  guardWatcherParser IssuePlanning

guardWatcherParser :: Domain -> Parser GuardWatcherCli
guardWatcherParser domain =
  GuardWatcherCli
    <$> loopParser domain
    <*> optional (strOption (long "guard-pid-file" <> metavar "PATH" <> help "Runner guard pid file"))
    <*> pollSecondsOptionDefault "guard-poll-seconds" 60 "SECONDS" "Runner guard polling interval"
    <*> staleSecondsOptionDefault "stale-seconds" 1800 "SECONDS" "Maximum event-log idle time before guard triggers repair"
    <*> optional (strOption (long "repair-cwd" <> metavar "PATH" <> help "Repository cwd for the repair thread"))

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

cliDomainName :: Domain -> String
cliDomainName = \case
  PrReview -> "pr-review"
  IssueImplement -> "issue-implement"
  IssuePlanning -> "issue-planning"
