{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Repair
  ( repairInvalidStateParser
  ) where

import CodexWatcher.Cli.Parser.Common (eventsPathOption, stateDirOption)
import CodexWatcher.Cli.Types (RepairInvalidStateCli (..))
import Options.Applicative

repairInvalidStateParser :: Parser RepairInvalidStateCli
repairInvalidStateParser =
  RepairInvalidStateCli
    <$> eventsPathOption
    <*> stateDirOption
    <*> switch (long "execute" <> help "Archive and rewrite events.jsonl plus compatibility state files")
