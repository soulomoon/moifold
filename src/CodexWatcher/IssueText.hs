{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.IssueText
  ( issueNumbersCsv
  , issueNumbersText
  ) where

import CodexWatcher.Types (IssueNumber (..))
import Data.Text (Text)
import Data.Text qualified as Text

issueNumbersCsv :: [IssueNumber] -> Text
issueNumbersCsv =
  issueNumbersWith ","

issueNumbersText :: [IssueNumber] -> Text
issueNumbersText =
  issueNumbersWith ", "

issueNumbersWith :: Text -> [IssueNumber] -> Text
issueNumbersWith separator =
  Text.intercalate separator . fmap (Text.pack . show . unIssueNumber)
