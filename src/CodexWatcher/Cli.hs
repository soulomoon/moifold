{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli
  ( CliCommand (..)
  , CliDomain (..)
  , GuardIssuePlanningCli (..)
  , HealthcheckCli (..)
  , IssueFanoutCli (..)
  , LoopCli (..)
  , ObserveOnceCli (..)
  , RehearsalCli (..)
  , RenderServiceCli (..)
  , StopDaemonCli (..)
  , ValidateMigrationCli (..)
  , cliCommandParserInfo
  , cliDomainName
  , cliDomainToDomain
  , execCliCommandParser
  , parseCliCommand
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.Migration (RuntimeOwner, parseRuntimeOwner)
import CodexWatcher.Types
  ( CommitSha (..)
  , Domain (..)
  , IssueNumber (..)
  , PrNumber (..)
  , ReviewThreadId (..)
  , RepoName (..)
  , ThreadId (..)
  , TurnId (..)
  )
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Options.Applicative
import Text.Read (readMaybe)

data CliDomain
  = CliPrReview
  | CliIssueImplement
  | CliIssuePlanning
  deriving stock (Eq, Show, Generic)

data CliCommand
  = CliReplay FilePath
  | CliReplayPrReview FilePath
  | CliReplayIssueImplement FilePath
  | CliReplayEvents FilePath
  | CliHealthcheck HealthcheckCli
  | CliMarkRuntimeOwner FilePath RuntimeOwner
  | CliStopDaemon StopDaemonCli
  | CliRenderService RenderServiceCli
  | CliRehearseMigration RehearsalCli
  | CliValidateMigration ValidateMigrationCli
  | CliIssueFanout IssueFanoutCli
  | CliObserveOnce ObserveOnceCli
  | CliRunLoop LoopCli
  | CliGuardIssuePlanning GuardIssuePlanningCli
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
  , stopDaemonCliDomain :: Maybe CliDomain
  }
  deriving stock (Eq, Show, Generic)

data RenderServiceCli = RenderServiceCli
  { renderServiceCliName :: Text
  , renderServiceCliDomain :: CliDomain
  , renderServiceCliEventsPath :: FilePath
  , renderServiceCliStateDir :: FilePath
  , renderServiceCliRepo :: RepoName
  , renderServiceCliWorkdir :: FilePath
  , renderServiceCliEndpoint :: AppServerEndpoint
  , renderServiceCliExecutable :: Maybe FilePath
  , renderServiceCliPlannerThread :: Maybe ThreadId
  , renderServiceCliPollSeconds :: Int
  , renderServiceCliLogDir :: Maybe FilePath
  , renderServiceCliRestartSeconds :: Int
  , renderServiceCliRotateCount :: Int
  , renderServiceCliImplementersRoot :: Maybe FilePath
  , renderServiceCliStartChildren :: Bool
  }
  deriving stock (Eq, Show, Generic)

data RehearsalCli = RehearsalCli
  { rehearsalCliSourceStateDir :: FilePath
  , rehearsalCliRehearsalRoot :: Maybe FilePath
  , rehearsalCliTargetStateDir :: Maybe FilePath
  , rehearsalCliDomain :: CliDomain
  , rehearsalCliEventsPath :: Maybe FilePath
  , rehearsalCliName :: Maybe Text
  , rehearsalCliRepo :: RepoName
  , rehearsalCliWorkdir :: FilePath
  , rehearsalCliEndpoint :: AppServerEndpoint
  , rehearsalCliExecutable :: Maybe FilePath
  , rehearsalCliPlannerThread :: Maybe ThreadId
  , rehearsalCliPollSeconds :: Int
  , rehearsalCliLogDir :: Maybe FilePath
  , rehearsalCliRestartSeconds :: Int
  , rehearsalCliRotateCount :: Int
  , rehearsalCliImplementersRoot :: Maybe FilePath
  , rehearsalCliStartChildren :: Bool
  , rehearsalCliExecute :: Bool
  }
  deriving stock (Eq, Show, Generic)

data ValidateMigrationCli = ValidateMigrationCli
  { validateMigrationCliSourceStateDir :: FilePath
  , validateMigrationCliTargetStateDir :: FilePath
  , validateMigrationCliDomain :: CliDomain
  , validateMigrationCliEventsPath :: Maybe FilePath
  }
  deriving stock (Eq, Show, Generic)

data IssueFanoutCli = IssueFanoutCli
  { issueFanoutCliRepo :: RepoName
  , issueFanoutCliImplementersRoot :: FilePath
  , issueFanoutCliMaxParallel :: Int
  , issueFanoutCliOpenIssues :: Maybe [IssueNumber]
  , issueFanoutCliActiveIssues :: Maybe [IssueNumber]
  , issueFanoutCliExecute :: Bool
  , issueFanoutCliStartChildren :: Bool
  , issueFanoutCliEndpoint :: Maybe AppServerEndpoint
  , issueFanoutCliWorkdirRoot :: Maybe FilePath
  , issueFanoutCliBranchPrefix :: Text
  , issueFanoutCliThreadPrefix :: Text
  , issueFanoutCliPollSeconds :: Maybe Int
  , issueFanoutCliChildPollSeconds :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)

data ObserveOnceCli = ObserveOnceCli
  { observeCliEventsPath :: FilePath
  , observeCliStateDir :: FilePath
  , observeCliRepo :: RepoName
  , observeCliWorkdir :: FilePath
  , observeCliDomain :: CliDomain
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
  , observeCliReviewThreadIds :: [ReviewThreadId]
  , observeCliComment :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data LoopCli = LoopCli
  { loopCliDomain :: CliDomain
  , loopCliEventsPath :: FilePath
  , loopCliStateDir :: FilePath
  , loopCliRepo :: RepoName
  , loopCliWorkdir :: FilePath
  , loopCliEndpoint :: AppServerEndpoint
  , loopCliPollSeconds :: Int
  , loopCliExecute :: Bool
  , loopCliLoop :: Bool
  , loopCliIterations :: Maybe Int
  , loopCliPidFile :: Maybe FilePath
  , loopCliPlannerThread :: Maybe ThreadId
  , loopCliScopeIssue :: Maybe IssueNumber
  , loopCliImplementersRoot :: Maybe FilePath
  , loopCliOpenIssues :: Maybe [IssueNumber]
  , loopCliActiveIssues :: Maybe [IssueNumber]
  , loopCliImplementerWorkdirRoot :: Maybe FilePath
  , loopCliWorkdirRoot :: Maybe FilePath
  , loopCliBranchPrefix :: Text
  , loopCliThreadPrefix :: Text
  , loopCliStartChildren :: Bool
  , loopCliChildPollSeconds :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)

data GuardIssuePlanningCli = GuardIssuePlanningCli
  { guardCliLoop :: LoopCli
  , guardCliPidFile :: Maybe FilePath
  , guardCliPollSeconds :: Int
  , guardCliStaleSeconds :: Int
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
        <> progDesc "Typed Haskell watcher migration runtime"
        <> header "codex-watcher-hs"
    )

parserPrefs :: ParserPrefs
parserPrefs =
  prefs showHelpOnEmpty

cliCommandParser :: Parser CliCommand
cliCommandParser =
  hsubparser
    ( command "replay" (info (CliReplay <$> stateDirArgument "NODE_WATCHER_STATE_DIR") (progDesc "Replay a legacy Node watcher state directory"))
        <> command "replay-pr-review" (info (CliReplayPrReview <$> stateDirArgument "NODE_PR_REVIEW_STATE_DIR") (progDesc "Replay a legacy Node PR review watcher state directory"))
        <> command "replay-issue-implement" (info (CliReplayIssueImplement <$> stateDirArgument "NODE_ISSUE_IMPLEMENT_STATE_DIR") (progDesc "Replay a legacy Node issue implementer state directory"))
        <> command "replay-events" (info (CliReplayEvents <$> eventsPathArgument) (progDesc "Replay a canonical watcher events.jsonl file"))
        <> command "healthcheck" (info (CliHealthcheck <$> healthcheckParser) (progDesc "Run the read-only watcher healthcheck"))
        <> command "mark-runtime-owner" (info markRuntimeOwnerParser (progDesc "Write runtime-owner.json for a watcher state directory"))
        <> command "stop-daemon" (info (CliStopDaemon <$> stopDaemonParser) (progDesc "Send TERM to a Haskell watcher daemon"))
        <> command "render-service" (info (CliRenderService <$> renderServiceParser) (progDesc "Render a systemd unit and logrotate config"))
        <> command "rehearse-migration" (info (CliRehearseMigration <$> rehearsalParser) (progDesc "Prepare and render a side-by-side Haskell migration rehearsal"))
        <> command "validate-migration" (info (CliValidateMigration <$> validateMigrationParser) (progDesc "Validate copied watcher state before migration cutover"))
        <> command "issue-fanout" (info (CliIssueFanout <$> issueFanoutParser) (progDesc "Plan or create issue implementer child watcher state"))
        <> command "observe-once" (info (CliObserveOnce <$> observeOnceParser) (progDesc "Apply one explicit typed watcher observation"))
        <> command "run-pr-review" (info (CliRunLoop <$> loopParser CliPrReview) (progDesc "Run one or more PR review watcher loop iterations"))
        <> command "run-issue-implement" (info (CliRunLoop <$> loopParser CliIssueImplement) (progDesc "Run one or more issue implementation watcher loop iterations"))
        <> command "run-issue-planning" (info (CliRunLoop <$> loopParser CliIssuePlanning) (progDesc "Run one or more issue planning watcher loop iterations"))
        <> command "guard-issue-planning" (info (CliGuardIssuePlanning <$> guardIssuePlanningParser) (progDesc "Guard an issue planning watcher and launch a repair thread on failure"))
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

markRuntimeOwnerParser :: Parser CliCommand
markRuntimeOwnerParser =
  CliMarkRuntimeOwner
    <$> stateDirOption
    <*> option runtimeOwnerReader (long "owner" <> metavar "node|haskell" <> help "Runtime owner to write")

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
    <*> intOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> optional (strOption (long "log-dir" <> metavar "PATH" <> help "Directory for daemon logs"))
    <*> intOptionDefault "restart-seconds" 10 "SECONDS" "systemd restart delay"
    <*> intOptionDefault "rotate" 14 "COUNT" "logrotate retention count"
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> switch (long "start-children" <> help "Start issue implementer children after planning fanout")

rehearsalParser :: Parser RehearsalCli
rehearsalParser =
  RehearsalCli
    <$> strOption (long "source-state-dir" <> metavar "PATH" <> help "Existing watcher state directory to rehearse from")
    <*> optional (strOption (long "rehearsal-root" <> metavar "PATH" <> help "Root for copied rehearsal state"))
    <*> optional (strOption (long "target-state-dir" <> metavar "PATH" <> help "Exact copied rehearsal state directory"))
    <*> domainOption
    <*> optional eventsPathOption
    <*> optional (textOption "name" "NAME" "Service name for rendered rehearsal service")
    <*> repoOption
    <*> workdirOption
    <*> requiredEndpointParser
    <*> optional (strOption (long "executable" <> metavar "PATH" <> help "Executable path to embed in the service"))
    <*> optional plannerThreadOption
    <*> intOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> optional (strOption (long "log-dir" <> metavar "PATH" <> help "Directory for daemon logs"))
    <*> intOptionDefault "restart-seconds" 10 "SECONDS" "systemd restart delay"
    <*> intOptionDefault "rotate" 14 "COUNT" "logrotate retention count"
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> switch (long "start-children" <> help "Start issue implementer children after planning fanout")
    <*> switch (long "execute" <> help "Copy source watcher state and mark the copy Haskell-owned")

validateMigrationParser :: Parser ValidateMigrationCli
validateMigrationParser =
  ValidateMigrationCli
    <$> strOption (long "source-state-dir" <> metavar "PATH" <> help "Original watcher state directory")
    <*> strOption (long "target-state-dir" <> metavar "PATH" <> help "Copied Haskell rehearsal state directory")
    <*> domainOption
    <*> optional eventsPathOption

issueFanoutParser :: Parser IssueFanoutCli
issueFanoutParser =
  IssueFanoutCli
    <$> repoOption
    <*> strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root")
    <*> intOption "max-parallel" "N" "Maximum concurrent implementers"
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active"))
    <*> switch (long "execute" <> help "Write child watcher state instead of printing it")
    <*> switch (long "start-children" <> help "Print or start child watcher loop commands")
    <*> optionalEndpointParser
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for child workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Child branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Child app-server thread prefix"
    <*> optional (intOption "poll-seconds" "SECONDS" "Child polling interval")
    <*> optional (intOption "child-poll-seconds" "SECONDS" "Child polling interval override")

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
    <*> fmap (maybe [] id) (optional (option reviewThreadIdsReader (long "review-thread-ids" <> metavar "ID,ID" <> help "Unresolved review thread ids")))
    <*> optional (textOption "comment" "TEXT" "Clean review comment")

loopParser :: CliDomain -> Parser LoopCli
loopParser domain =
  LoopCli
    <$> pure domain
    <*> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOptionDefault
    <*> requiredEndpointParser
    <*> intOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> switch (long "execute" <> help "Append observed events and execute compiled effects")
    <*> switch (long "loop" <> help "Continue polling until stopped")
    <*> optional (intOption "iterations" "N" "Maximum loop iterations")
    <*> optional (strOption (long "pid-file" <> metavar "PATH" <> help "Override daemon pid file"))
    <*> optional plannerThreadOption
    <*> optional (IssueNumber <$> intOption "scope-issue" "NUMBER" "Restrict issue planning to this issue and its sub-issues")
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider during planning fanout"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active during planning fanout"))
    <*> optional (strOption (long "implementer-workdir-root" <> metavar "PATH" <> help "Root for issue implementer child workdirs"))
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for generated workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Issue implementer branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Issue implementer thread prefix"
    <*> switch (long "start-children" <> help "Print or start child watcher loop commands after planning fanout")
    <*> optional (intOption "child-poll-seconds" "SECONDS" "Child polling interval override")

guardIssuePlanningParser :: Parser GuardIssuePlanningCli
guardIssuePlanningParser =
  GuardIssuePlanningCli
    <$> loopParser CliIssuePlanning
    <*> optional (strOption (long "guard-pid-file" <> metavar "PATH" <> help "Runner guard pid file"))
    <*> intOptionDefault "guard-poll-seconds" 60 "SECONDS" "Runner guard polling interval"
    <*> intOptionDefault "stale-seconds" 1800 "SECONDS" "Maximum event-log idle time before guard triggers repair"
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

domainOption :: Parser CliDomain
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

stateDirArgument :: String -> Parser FilePath
stateDirArgument metavarName =
  argument str (metavar metavarName)

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

domainReader :: ReadM CliDomain
domainReader =
  eitherReader \case
    "pr-review" -> Right CliPrReview
    "issue-implement" -> Right CliIssueImplement
    "issue-planning" -> Right CliIssuePlanning
    other -> Left ("unsupported watcher domain: " <> other)

runtimeOwnerReader :: ReadM RuntimeOwner
runtimeOwnerReader =
  eitherReader \input ->
    case parseRuntimeOwner (Text.pack input) of
      Right owner -> Right owner
      Left errorMessage -> Left (Text.unpack errorMessage)

intReader :: ReadM Int
intReader =
  eitherReader \input ->
    case readMaybe input of
      Just parsed -> Right parsed
      Nothing -> Left ("invalid integer: " <> input)

issueNumbersReader :: String -> ReadM [IssueNumber]
issueNumbersReader flagName =
  eitherReader \input ->
    case parseIssueNumbersText flagName (Text.pack input) of
      Right issueNumbers -> Right issueNumbers
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

cliDomainName :: CliDomain -> String
cliDomainName = \case
  CliPrReview -> "pr-review"
  CliIssueImplement -> "issue-implement"
  CliIssuePlanning -> "issue-planning"

cliDomainToDomain :: CliDomain -> Domain
cliDomainToDomain = \case
  CliPrReview -> PrReview
  CliIssueImplement -> IssueImplement
  CliIssuePlanning -> IssuePlanning
