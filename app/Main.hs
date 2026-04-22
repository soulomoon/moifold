{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.EventLog
import CodexWatcher.GoldenReplay
import CodexWatcher.Healthcheck
import CodexWatcher.Migration
import CodexWatcher.Runtime
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
    ["replay-events", path] -> replayEvents path
    "healthcheck" : rest -> runHealthcheck (parseHealthcheckOptions rest)
    "mark-runtime-owner" : rest -> markRuntimeOwner rest
    [] -> do
      putStrLn "codex-watcher-hs"
      putStrLn "usage: codex-watcher-hs replay <node-watcher-state-dir>"
      putStrLn "       codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"
      putStrLn "       codex-watcher-hs replay-issue-implement <node-issue-implement-state-dir>"
      putStrLn "       codex-watcher-hs replay-events <events.jsonl>"
      putStrLn "       codex-watcher-hs healthcheck [--state-root <path>] [--repo owner/name]"
      putStrLn "       codex-watcher-hs mark-runtime-owner --state-dir <path> --owner node|haskell"
      putStrLn "type-level domains:"
      print [IssuePlanning, IssueImplement, PrReview]
      putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
    _ -> die "usage: codex-watcher-hs replay <node-watcher-state-dir> | replay-events <events.jsonl> | healthcheck [--state-root <path>] [--repo owner/name] | mark-runtime-owner --state-dir <path> --owner node|haskell"

parseHealthcheckOptions :: [String] -> HealthcheckOptions
parseHealthcheckOptions args =
  HealthcheckOptions
    { stateRoot = maybe "/workspace/artifacts" id (lookupFlag "--state-root" args)
    , repoFilter = Text.pack <$> lookupFlag "--repo" args
    }

lookupFlag :: String -> [String] -> Maybe String
lookupFlag _ [] = Nothing
lookupFlag flag (current : value : rest)
  | current == flag = Just value
  | otherwise = lookupFlag flag (value : rest)
lookupFlag _ [_] = Nothing

markRuntimeOwner :: [String] -> IO ()
markRuntimeOwner args = do
  stateDir <- maybe (die "mark-runtime-owner requires --state-dir <path>") pure (lookupFlag "--state-dir" args)
  ownerText <- maybe (die "mark-runtime-owner requires --owner node|haskell") (pure . Text.pack) (lookupFlag "--owner" args)
  owner <- either (die . Text.unpack) pure (parseRuntimeOwner ownerText)
  writeRuntimeOwner ioRuntimeInterpreter stateDir owner
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText owner) <> " to " <> stateDir)

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

replayEvents :: FilePath -> IO ()
replayEvents path = do
  loaded <- loadEventLogFile path
  events <- either die pure loaded
  replay <- either (die . formatReplayFailure) pure (replayEventLog events)
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  putStrLn ("events: " <> show (length events))
  putStrLn ("effect batches: " <> show (length replay.replayEffects))

formatReplayFailure :: ReplayFailure -> String
formatReplayFailure failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
