module CodexWatcher.EventLog.File
  ( loadEventLogFile
  ) where

import CodexWatcher.EventLog.Types
import CodexWatcher.Workflow.EventLog.File.Core
  ( decodeWorkflowEventLogLines
  , formatWorkflowEventLogLineDecodeError
  )
import Data.Aeson (eitherDecodeStrict')
import Data.Bifunctor (first)
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text

loadEventLogFile :: FilePath -> IO (Either String [WatcherEvent])
loadEventLogFile path = do
  bytes <- ByteString.readFile path
  pure
    ( first
        (Text.unpack . formatWorkflowEventLogLineDecodeError)
        (decodeWorkflowEventLogLines decodeWatcherEventLine bytes)
    )

decodeWatcherEventLine :: ByteString.ByteString -> Either Text.Text WatcherEvent
decodeWatcherEventLine line =
  first Text.pack (eitherDecodeStrict' line)
