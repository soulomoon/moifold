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
    ["replay", dir] -> replayAny dir
    ["replay-pr-review", dir] -> replayPrReview dir
    ["replay-issue-implement", dir] -> replayIssueImplement dir
    [] -> do
      putStrLn "codex-watcher-hs"
      putStrLn "usage: codex-watcher-hs replay <node-watcher-state-dir>"
      putStrLn "       codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"
      putStrLn "       codex-watcher-hs replay-issue-implement <node-issue-implement-state-dir>"
      putStrLn "type-level domains:"
      print [IssuePlanning, IssueImplement, PrReview]
      putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
    _ -> die "usage: codex-watcher-hs replay <node-watcher-state-dir>"

replayAny :: FilePath -> IO ()
replayAny dir = do
  loaded <- loadNodeSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeSnapshot snapshot)
  printReplay replay

replayPrReview :: FilePath -> IO ()
replayPrReview dir = do
  loaded <- loadNodePrReviewSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodePrReviewSnapshot snapshot)
  printReplay replay

replayIssueImplement :: FilePath -> IO ()
replayIssueImplement dir = do
  loaded <- loadNodeIssueImplementSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeIssueImplementSnapshot snapshot)
  printReplay replay

printReplay :: ReplayResult -> IO ()
printReplay replay = do
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  mapM_ (putStrLn . ("warning: " <>) . Text.unpack) replay.replayWarnings
