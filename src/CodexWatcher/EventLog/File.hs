module CodexWatcher.EventLog.File
  ( loadEventLogFile
  ) where

import CodexWatcher.EventLog.Types
import Data.Aeson (eitherDecodeStrict')
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.Char (isSpace)

loadEventLogFile :: FilePath -> IO (Either String [WatcherEvent])
loadEventLogFile path = do
  bytes <- ByteString.readFile path
  pure (traverse parseLine (numberedNonBlankLines bytes))

numberedNonBlankLines :: ByteString.ByteString -> [(Int, ByteString.ByteString)]
numberedNonBlankLines =
  filter (not . ByteString.Char8.all isSpace . snd)
    . zip [1 ..]
    . ByteString.Char8.lines

parseLine :: (Int, ByteString.ByteString) -> Either String WatcherEvent
parseLine (lineNumber, line) =
  case eitherDecodeStrict' line of
    Left error' -> Left ("line " <> show lineNumber <> ": " <> error')
    Right event -> Right event
