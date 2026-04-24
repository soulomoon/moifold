{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Core.Limits
  ( MaxParallel
  , PollSeconds
  , StaleSeconds
  , mkMaxParallel
  , mkPollSeconds
  , mkStaleSeconds
  , unMaxParallel
  , unPollSeconds
  , unStaleSeconds
  , pollSecondsMicros
  ) where

import Data.Aeson (ToJSON (..))

newtype MaxParallel = MaxParallel { unMaxParallel :: Int }
  deriving stock (Eq, Ord)

instance Show MaxParallel where
  show =
    show . unMaxParallel

instance ToJSON MaxParallel where
  toJSON =
    toJSON . unMaxParallel

mkMaxParallel :: Int -> Maybe MaxParallel
mkMaxParallel value
  | value > 0 = Just (MaxParallel value)
  | otherwise = Nothing

newtype PollSeconds = PollSeconds { unPollSeconds :: Int }
  deriving stock (Eq, Ord)

instance Show PollSeconds where
  show =
    show . unPollSeconds

mkPollSeconds :: Int -> Maybe PollSeconds
mkPollSeconds value
  | value > 0 = Just (PollSeconds value)
  | otherwise = Nothing

pollSecondsMicros :: PollSeconds -> Int
pollSecondsMicros pollSeconds =
  unPollSeconds pollSeconds * 1000000

newtype StaleSeconds = StaleSeconds { unStaleSeconds :: Int }
  deriving stock (Eq, Ord)

instance Show StaleSeconds where
  show =
    show . unStaleSeconds

mkStaleSeconds :: Int -> Maybe StaleSeconds
mkStaleSeconds value
  | value > 0 = Just (StaleSeconds value)
  | otherwise = Nothing
