{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Command.Service
  ( renderService
  , serviceConfigFromCli
  , serviceConfigFromCliWithExecutable
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.ChildDaemon (stableExecutablePath)
import CodexWatcher.Cli.Types
import CodexWatcher.Supervisor
import CodexWatcher.Core.Ids (RepoName (unRepoName))
import Data.Text qualified as Text
import System.FilePath ((</>))

renderService :: RenderServiceCli -> IO ()
renderService options = do
  service <- serviceConfigFromCli options
  putStrLn "# systemd service"
  putStr (Text.unpack (renderSystemdService service))
  putStrLn "# logrotate"
  putStr (Text.unpack (renderLogrotateConfig service))

serviceConfigFromCli :: RenderServiceCli -> IO WatcherServiceConfig
serviceConfigFromCli options = do
  executable <- maybe stableExecutablePath pure options.renderServiceCliExecutable
  pure (serviceConfigFromCliWithExecutable options executable [])

serviceConfigFromCliWithExecutable :: RenderServiceCli -> FilePath -> [String] -> WatcherServiceConfig
serviceConfigFromCliWithExecutable options executable plannerArgs =
  let domain = cliDomainName options.renderServiceCliDomain
      stateDir = options.renderServiceCliStateDir
      endpoint = options.renderServiceCliEndpoint
      pollSeconds = show options.renderServiceCliPollSeconds
      logDir = maybe (stateDir </> "logs") id options.renderServiceCliLogDir
      appServerPathArgs =
        if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]
      implementerArgs =
        maybe [] (\root -> ["--implementers-root", root]) options.renderServiceCliImplementersRoot
      commandArgs =
        [ "run-" <> domain
        , "--events"
        , options.renderServiceCliEventsPath
        , "--state-dir"
        , stateDir
        , "--repo"
        , Text.unpack (unRepoName options.renderServiceCliRepo)
        , "--workdir"
        , options.renderServiceCliWorkdir
        , "--app-server-host"
        , endpoint.appServerHost
        , "--app-server-port"
        , show endpoint.appServerPort
        , "--poll-seconds"
        , pollSeconds
        , "--execute"
        , "--loop"
        ]
          <> appServerPathArgs
          <> plannerArgs
          <> implementerArgs
   in
    WatcherServiceConfig
      { serviceName = options.renderServiceCliName
      , serviceDescription = "Codex watcher " <> options.renderServiceCliName
      , serviceExecutable = executable
      , serviceArguments = commandArgs
      , serviceWorkingDirectory = options.renderServiceCliWorkdir
      , serviceLogDirectory = logDir
      , serviceRestartSeconds = options.renderServiceCliRestartSeconds
      , serviceLogRotateCount = options.renderServiceCliRotateCount
      }
