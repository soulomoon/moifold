{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.EventLog.File.Core
  ( WorkflowEventLogLineDecodeError (..)
  , decodeWorkflowEventLogLines
  , formatWorkflowEventLogLineDecodeError
  , numberedNonBlankWorkflowEventLogLines
  ) where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.Char (isSpace)
import Data.Text (Text)
import Data.Text qualified as Text

data WorkflowEventLogLineDecodeError = WorkflowEventLogLineDecodeError
  { workflowEventLogLineDecodeErrorLineNumber :: Int
  , workflowEventLogLineDecodeErrorReason :: Text
  }
  deriving stock (Eq, Show)

numberedNonBlankWorkflowEventLogLines :: ByteString -> [(Int, ByteString)]
numberedNonBlankWorkflowEventLogLines =
  filter (not . ByteString.Char8.all isSpace . snd)
    . zip [1 ..]
    . ByteString.Char8.lines

decodeWorkflowEventLogLines
  :: (ByteString -> Either Text event)
  -> ByteString
  -> Either WorkflowEventLogLineDecodeError [event]
decodeWorkflowEventLogLines decodeLine =
  traverse decodeNumberedLine . numberedNonBlankWorkflowEventLogLines
 where
  decodeNumberedLine (lineNumber, line) =
    case decodeLine line of
      Right event -> Right event
      Left reason ->
        Left
          WorkflowEventLogLineDecodeError
            { workflowEventLogLineDecodeErrorLineNumber = lineNumber
            , workflowEventLogLineDecodeErrorReason = reason
            }

formatWorkflowEventLogLineDecodeError :: WorkflowEventLogLineDecodeError -> Text
formatWorkflowEventLogLineDecodeError error' =
  "line "
    <> Text.pack (show error'.workflowEventLogLineDecodeErrorLineNumber)
    <> ": "
    <> error'.workflowEventLogLineDecodeErrorReason
