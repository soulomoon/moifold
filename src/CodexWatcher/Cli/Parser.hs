module CodexWatcher.Cli.Parser
  ( cliCommandParserInfo
  , execCliCommandParser
  , parseCliCommand
  ) where

import CodexWatcher.Cli.Parser.Common (eventsPathArgument, stateDirOption)
import CodexWatcher.Cli.Parser.AppServerProbe (appServerProbeParser)
import CodexWatcher.Cli.Parser.Fanout (issueFanoutParser)
import CodexWatcher.Cli.Parser.Guard (guardIssuePlanningParser, guardWatcherParser)
import CodexWatcher.Cli.Parser.Healthcheck (healthcheckParser)
import CodexWatcher.Cli.Parser.Loop (loopParser)
import CodexWatcher.Cli.Parser.Observe (observeOnceParser)
import CodexWatcher.Cli.Parser.Repair (repairInvalidStateParser)
import CodexWatcher.Cli.Parser.Service (renderServiceParser, stopDaemonParser)
import CodexWatcher.Cli.Types (CliCommand (..))
import CodexWatcher.Core.Kinds (Domain (..))
import Options.Applicative

execCliCommandParser :: IO CliCommand
execCliCommandParser =
  customExecParser parserPrefs cliCommandParserInfo

parseCliCommand :: [String] -> Either String CliCommand
parseCliCommand args =
  case execParserPure parserPrefs cliCommandParserInfo args of
    Success parsedCommand -> Right parsedCommand
    Failure failure -> Left (fst (renderFailure failure "moifold"))
    CompletionInvoked completion -> Left (show completion)

cliCommandParserInfo :: ParserInfo CliCommand
cliCommandParserInfo =
  info
    (helper <*> cliCommandParser)
    ( fullDesc
        <> progDesc "Typed Haskell watcher runtime"
        <> header "moifold"
    )

parserPrefs :: ParserPrefs
parserPrefs =
  prefs showHelpOnEmpty

cliCommandParser :: Parser CliCommand
cliCommandParser =
  hsubparser
    ( command "replay-events" (info (CliReplayEvents <$> eventsPathArgument) (progDesc "Replay a canonical watcher events.jsonl file"))
        <> command "probe-app-server" (info (CliProbeAppServer <$> appServerProbeParser) (progDesc "Probe Codex app-server WebSocket and optional thread/turn methods"))
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

clearRuntimeLeaseParser :: Parser CliCommand
clearRuntimeLeaseParser =
  CliClearRuntimeLease <$> stateDirOption
