module CodexWatcher.Cli.Parser.AppServerProbe
  ( appServerProbeParser
  ) where

import CodexWatcher.Cli.Parser.Common (requiredEndpointParser, threadIdOption, workdirOptionDefault)
import CodexWatcher.Cli.Types (AppServerProbeCli (..))
import Options.Applicative

appServerProbeParser :: Parser AppServerProbeCli
appServerProbeParser =
  AppServerProbeCli
    <$> requiredEndpointParser
    <*> optional threadIdOption
    <*> switch (long "create-smoke-thread" <> help "Create a minimal app-server thread to verify thread/start")
    <*> switch (long "start-smoke-turn" <> help "Start a minimal turn to verify turn/start; creates a smoke thread when --thread-id is omitted")
    <*> workdirOptionDefault
