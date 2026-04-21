{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Json
  ( decodeJsonFile
  , decodeOptionalJsonFile
  ) where

import Data.Aeson (FromJSON, eitherDecodeStrict')
import Data.ByteString qualified as ByteString
import Control.Exception (IOException, try)
import System.Directory (doesFileExist)

decodeJsonFile :: FromJSON a => FilePath -> IO (Either String a)
decodeJsonFile path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure (case bytesResult of
    Left error' -> Left (path <> ": " <> show error')
    Right bytes -> eitherDecodeStrict' bytes)

decodeOptionalJsonFile :: FromJSON a => FilePath -> IO (Either String (Maybe a))
decodeOptionalJsonFile path = do
  exists <- doesFileExist path
  if exists
    then fmap Just <$> decodeJsonFile path
    else pure (Right Nothing)
