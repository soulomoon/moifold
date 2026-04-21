{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.GoldenReplay
import CodexWatcher.Snapshot
import CodexWatcher.Types
import Data.Text qualified as Text
import System.Environment (getArgs)
import System.Exit (die)

main :: IO ()
main =
  getArgs >>= \case
    ["replay-pr-review", dir] -> replayPrReview dir
    [] -> do
      putStrLn "codex-watcher-hs"
      putStrLn "usage: codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"
      putStrLn "type-level domains:"
      print [IssuePlanning, IssueImplement, PrReview]
      putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
    _ -> die "usage: codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"

replayPrReview :: FilePath -> IO ()
replayPrReview dir = do
  loaded <- loadNodePrReviewSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodePrReviewSnapshot snapshot)
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  mapM_ (putStrLn . ("warning: " <>) . Text.unpack) replay.replayWarnings
