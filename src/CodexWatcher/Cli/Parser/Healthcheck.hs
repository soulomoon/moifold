{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Healthcheck
  ( healthcheckParser
  ) where

import CodexWatcher.Cli.Parser.Common (optionalEndpointParser, repoOption)
import CodexWatcher.Cli.Types (HealthcheckCli (..))
import Options.Applicative

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
