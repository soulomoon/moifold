{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Json
  ( decodeJsonFile
  , decodeOptionalJsonFile
  ) where

import Data.Aeson (FromJSON, eitherDecodeStrict')
import Data.ByteString qualified as ByteString
import System.Directory (doesFileExist)

decodeJsonFile :: FromJSON a => FilePath -> IO (Either String a)
decodeJsonFile path = eitherDecodeStrict' <$> ByteString.readFile path

decodeOptionalJsonFile :: FromJSON a => FilePath -> IO (Either String (Maybe a))
decodeOptionalJsonFile path = do
  exists <- doesFileExist path
  if exists
    then fmap Just <$> decodeJsonFile path
    else pure (Right Nothing)
