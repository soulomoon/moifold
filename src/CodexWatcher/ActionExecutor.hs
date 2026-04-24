{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.ActionExecutor
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , AppServerInterpreter (..)
  , dryRunCompiledEffectPlan
  , executeCompiledEffectPlan
  , executePlannedAction
  , ioActionExecutor
  , ioActionExecutorWithLogger
  ) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.EffectInterpreter
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..), ioRuntimeInterpreter)
import Data.Aeson (Value (..), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Pair)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data ActionExecutionMode
  = ExecuteActions
  | DryRunActions
  deriving stock (Eq, Show, Generic)

data AppServerInterpreter m = AppServerInterpreter
  { appServerSendRequest :: AppServerRequest -> m Value
  }

data ActionExecutor m = ActionExecutor
  { actionRuntime :: RuntimeInterpreter m
  , actionAppServer :: AppServerInterpreter m
  , actionSleepUntilNextPoll :: m ()
  , actionStopDaemon :: m ()
  , actionLogger :: Log.WatcherLogger m
  }

data ActionExecutionResult
  = CommandActionResult CommandReport
  | AppServerActionResult Value
  | WriteJsonActionResult FilePath
  | WriteTextActionResult FilePath
  | SleepActionResult
  | StopDaemonActionResult
  | DryRunActionResult
  deriving stock (Eq, Show, Generic)

data ActionExecutionReport = ActionExecutionReport
  { actionExecutionMode :: ActionExecutionMode
  , actionExecutionAction :: PlannedAction
  , actionExecutionResult :: ActionExecutionResult
  }
  deriving stock (Eq, Show, Generic)

ioActionExecutor :: AppServerInterpreter IO -> IO () -> IO () -> ActionExecutor IO
ioActionExecutor appServerInterpreter sleepUntilNextPoll stopDaemon =
  ioActionExecutorWithLogger Log.noopWatcherLogger appServerInterpreter sleepUntilNextPoll stopDaemon

ioActionExecutorWithLogger :: Log.WatcherLogger IO -> AppServerInterpreter IO -> IO () -> IO () -> ActionExecutor IO
ioActionExecutorWithLogger logger appServerInterpreter sleepUntilNextPoll stopDaemon =
  ActionExecutor
    { actionRuntime = ioRuntimeInterpreter
    , actionAppServer = appServerInterpreter
    , actionSleepUntilNextPoll = sleepUntilNextPoll
    , actionStopDaemon = stopDaemon
    , actionLogger = logger
    }

dryRunCompiledEffectPlan :: CompiledEffectPlan -> [ActionExecutionReport]
dryRunCompiledEffectPlan plan =
  fmap dryRunAction plan.compiledActions

executeCompiledEffectPlan :: Monad m => ActionExecutor m -> ActionExecutionMode -> CompiledEffectPlan -> m [ActionExecutionReport]
executeCompiledEffectPlan executor mode plan =
  traverse (executePlannedAction executor mode) plan.compiledActions

executePlannedAction :: Monad m => ActionExecutor m -> ActionExecutionMode -> PlannedAction -> m ActionExecutionReport
executePlannedAction executor DryRunActions action = do
  let report = dryRunAction action
  logActionReport executor Log.Debug "action_dry_run" "planned action skipped in dry-run mode" report
  pure report
executePlannedAction executor ExecuteActions action =
  case action of
    PlannedCommand command -> do
      logPlannedAction executor action
      report <- executor.actionRuntime.runtimeRunCommand command
      let result = executed action (CommandActionResult report)
      logActionReport executor (actionReportLevel result) "action_finished" "planned command action finished" result
      pure result
    PlannedAppServerRequest request -> do
      logPlannedAction executor action
      response <- executor.actionAppServer.appServerSendRequest request
      let result = executed action (AppServerActionResult response)
      logActionReport executor Log.Info "action_finished" "planned app-server action finished" result
      pure result
    PlannedWriteJson path value -> do
      logPlannedAction executor action
      executor.actionRuntime.runtimeWriteJsonValue path value
      let result = executed action (WriteJsonActionResult path)
      logActionReport executor Log.Info "action_finished" "planned write-json action finished" result
      pure result
    PlannedWriteText path content -> do
      logPlannedAction executor action
      executor.actionRuntime.runtimeWriteTextFile path content
      let result = executed action (WriteTextActionResult path)
      logActionReport executor Log.Info "action_finished" "planned write-text action finished" result
      pure result
    PlannedSleepUntilNextPoll -> do
      logPlannedAction executor action
      executor.actionSleepUntilNextPoll
      let result = executed action SleepActionResult
      logActionReport executor Log.Debug "action_finished" "planned sleep action finished" result
      pure result
    PlannedStopDaemon -> do
      logPlannedAction executor action
      executor.actionStopDaemon
      let result = executed action StopDaemonActionResult
      logActionReport executor Log.Info "action_finished" "planned stop action finished" result
      pure result

dryRunAction :: PlannedAction -> ActionExecutionReport
dryRunAction action =
  ActionExecutionReport
    { actionExecutionMode = DryRunActions
    , actionExecutionAction = action
    , actionExecutionResult = DryRunActionResult
    }

executed :: PlannedAction -> ActionExecutionResult -> ActionExecutionReport
executed action result =
  ActionExecutionReport
    { actionExecutionMode = ExecuteActions
    , actionExecutionAction = action
    , actionExecutionResult = result
    }

logPlannedAction :: ActionExecutor m -> PlannedAction -> m ()
logPlannedAction executor action =
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Debug
        "action_started"
        "planned action started"
        (plannedActionContext action)
    )

logActionReport :: ActionExecutor m -> Log.WatcherLogLevel -> Text -> Text -> ActionExecutionReport -> m ()
logActionReport executor level event message report =
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        level
        event
        message
        ( plannedActionContext report.actionExecutionAction
            <> actionResultContext report.actionExecutionResult
            <> ["mode" .= Text.pack (show report.actionExecutionMode)]
        )
    )

actionReportLevel :: ActionExecutionReport -> Log.WatcherLogLevel
actionReportLevel report =
  case report.actionExecutionResult of
    CommandActionResult commandReport
      | commandReport.ok -> Log.Info
      | otherwise -> Log.Error
    _ -> Log.Info

plannedActionContext :: PlannedAction -> [Pair]
plannedActionContext = \case
  PlannedCommand command ->
    [ "actionKind" .= ("command" :: Text)
    , "runtimeCommand" .= runtimeCommandName command
    ]
  PlannedAppServerRequest request ->
    [ "actionKind" .= ("app_server_request" :: Text)
    , "requestId" .= request.requestId
    , "requestMethod" .= request.requestMethod
    ]
      <> maybe [] (\threadId -> ["threadId" .= threadId]) (requestThreadId request)
  PlannedWriteJson path _value ->
    [ "actionKind" .= ("write_json" :: Text)
    , "path" .= path
    ]
  PlannedWriteText path _content ->
    [ "actionKind" .= ("write_text" :: Text)
    , "path" .= path
    ]
  PlannedSleepUntilNextPoll ->
    ["actionKind" .= ("sleep" :: Text)]
  PlannedStopDaemon ->
    ["actionKind" .= ("stop_daemon" :: Text)]

actionResultContext :: ActionExecutionResult -> [Pair]
actionResultContext = \case
  CommandActionResult report ->
    [ "ok" .= report.ok
    , "status" .= report.status
    , "stdout" .= Log.logTextValue report.stdout
    , "stderr" .= Log.logTextValue report.stderr
    , "errorMessage" .= fmap Log.redactLogText report.errorMessage
    ]
  AppServerActionResult response ->
    [ "responseKind" .= valueKind response
    ]
  WriteJsonActionResult path ->
    [ "path" .= path
    ]
  WriteTextActionResult path ->
    [ "path" .= path
    ]
  SleepActionResult ->
    []
  StopDaemonActionResult ->
    []
  DryRunActionResult ->
    []

requestThreadId :: AppServerRequest -> Maybe Text
requestThreadId request =
  case request.requestParams of
    Object objectValue ->
      case KeyMap.lookup (Key.fromText "threadId") objectValue of
        Just (String threadId) -> Just threadId
        _ -> Nothing
    _ -> Nothing

valueKind :: Value -> Text
valueKind = \case
  Object {} -> "object"
  Array {} -> "array"
  String {} -> "string"
  Number {} -> "number"
  Bool {} -> "bool"
  Null -> "null"

runtimeCommandName :: RuntimeCommand -> Text
runtimeCommandName = \case
  CommandVersion {} -> "command_version"
  GhAuthStatus -> "gh_auth_status"
  GhApiUser -> "gh_api_user"
  GhIssueListOpen {} -> "gh_issue_list_open"
  GhIssueView {} -> "gh_issue_view"
  GhIssueCreate {} -> "gh_issue_create"
  GhIssueClose {} -> "gh_issue_close"
  GhPrListOpen {} -> "gh_pr_list_open"
  GhPrView {} -> "gh_pr_view"
  GhPrChecks {} -> "gh_pr_checks"
  GhReviewThreads {} -> "gh_review_threads"
  GhCreatePullRequest {} -> "gh_create_pull_request"
  GhUpdatePullRequestBody {} -> "gh_update_pull_request_body"
  GhResolveReviewThread {} -> "gh_resolve_review_thread"
  GhPrMerge {} -> "gh_pr_merge"
  GhPrCommentReviewAndMerge {} -> "gh_pr_comment_review_and_merge"
  CheckNonEmptyFile {} -> "check_non_empty_file"
  GitBranchCurrent {} -> "git_branch_current"
  GitRevParseHead {} -> "git_rev_parse_head"
  GitStatusPorcelain {} -> "git_status_porcelain"
  GitLsRemoteBranch {} -> "git_ls_remote_branch"
  GitPushDryRun {} -> "git_push_dry_run"
  GitPush {} -> "git_push"
  KillZero {} -> "kill_zero"
  KillTerm {} -> "kill_term"
  RawCommand command _args _cwd -> "raw_command:" <> Text.pack command
