{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import CodexWatcher.Types
import Data.Text qualified as Text

main :: IO ()
main = do
  putStrLn "codex-watcher-hs"
  putStrLn "type-level domains:"
  print [IssuePlanning, IssueImplement, PrReview]
  putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
