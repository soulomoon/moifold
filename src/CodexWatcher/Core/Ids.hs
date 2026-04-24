{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Core.Ids
  ( RepoName (..)
  , IssueNumber (..)
  , PrNumber (..)
  , ThreadId (..)
  , TurnId (..)
  , RequestId (..)
  , BranchName (..)
  , ReviewThreadId (..)
  , CommitSha (..)
  , nextRequestId
  ) where

import Data.Aeson (ToJSON (..))
import Data.Text (Text)

newtype RepoName = RepoName { unRepoName :: Text }
  deriving stock (Eq, Show)

newtype IssueNumber = IssueNumber { unIssueNumber :: Int }
  deriving stock (Eq, Ord, Show)

newtype PrNumber = PrNumber { unPrNumber :: Int }
  deriving stock (Eq, Show)

newtype ThreadId = ThreadId { unThreadId :: Text }
  deriving stock (Eq, Show)

newtype TurnId = TurnId { unTurnId :: Text }
  deriving stock (Eq, Show)

newtype RequestId = RequestId { unRequestId :: Int }
  deriving stock (Eq, Ord)

instance Show RequestId where
  show =
    show . unRequestId

instance ToJSON RequestId where
  toJSON =
    toJSON . unRequestId

nextRequestId :: RequestId -> RequestId
nextRequestId requestId =
  RequestId (unRequestId requestId + 1)

newtype BranchName = BranchName { unBranchName :: Text }
  deriving stock (Eq, Show)

newtype ReviewThreadId = ReviewThreadId { unReviewThreadId :: Text }
  deriving stock (Eq, Show)

newtype CommitSha = CommitSha { unCommitSha :: Text }
  deriving stock (Eq, Show)
