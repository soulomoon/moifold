{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.File
  ( appendJsonLine
  , readJsonValue
  , writeJsonValue
  , writeTextFile
  ) where

import Control.Exception (IOException, try)
import Data.Aeson (Value, eitherDecodeStrict', encode)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import System.Directory (createDirectoryIfMissing, renameFile)
import System.FilePath (takeDirectory)

readJsonValue :: FilePath -> IO (Either Text Value)
readJsonValue path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case bytesResult of
    Left error' -> Left (Text.pack (show error'))
    Right bytes -> either (Left . Text.pack) Right (eitherDecodeStrict' bytes)

writeJsonValue :: FilePath -> Value -> IO ()
writeJsonValue path value = do
  createDirectoryIfMissing True (takeDirectory path)
  let tmpPath = path <> ".tmp"
  LazyByteString.writeFile tmpPath (encode value)
  renameFile tmpPath path

writeTextFile :: FilePath -> Text -> IO ()
writeTextFile path content = do
  createDirectoryIfMissing True (takeDirectory path)
  let tmpPath = path <> ".tmp"
  ByteString.writeFile tmpPath (Text.Encoding.encodeUtf8 content)
  renameFile tmpPath path

appendJsonLine :: FilePath -> Value -> IO ()
appendJsonLine path value =
  LazyByteString.appendFile path (encode value <> "\n")
