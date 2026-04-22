{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Types
  ( Domain (..)
  , Phase (..)
  , ThreadActivity (..)
  , Mutability (..)
  , KnownDomain (..)
  , RepoName (..)
  , IssueNumber (..)
  , PrNumber (..)
  , ThreadId (..)
  , TurnId (..)
  , BranchName (..)
  , ReviewThreadId (..)
  , CommitSha (..)
  , MergeCommit (..)
  , BlockedReason (..)
  , StopReason (..)
  , PlannerConfig (..)
  , IssueCreationRequest (..)
  , IssueDependency (..)
  , BlockedPlanningIssue (..)
  , PlanningGraph (..)
  , IssueConfig (..)
  , PrConfig (..)
  , WorkerThread (..)
  , ReviewerThread (..)
  , ActiveTurn (..)
  , ReviewEvidence (..)
  , CleanReviewEvidence (..)
  , CompletionEvidence (..)
  , WatcherState (..)
  , SomeWatcherState (..)
  , domainOf
  , phaseOf
  , someDomain
  , somePhase
  , isTerminalPhase
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.:?), (.!=), (.=))
import Control.Applicative ((<|>))
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Aeson.Types (Parser)

data Domain
  = IssuePlanning
  | IssueImplement
  | PrReview
  deriving stock (Eq, Show)

class KnownDomain (domain :: Domain) where
  knownDomain :: Domain

instance KnownDomain 'IssuePlanning where
  knownDomain = IssuePlanning

instance KnownDomain 'IssueImplement where
  knownDomain = IssueImplement

instance KnownDomain 'PrReview where
  knownDomain = PrReview

data Phase
  = Initialized
  | Triage
  | PlanMode
  | Implementing
  | CheckingReviews
  | FixingReviews
  | ReviewingClean
  | Merging
  | Blocked
  | Complete
  | Stopped
  deriving stock (Eq, Show)

data ThreadActivity
  = Idle
  | Active
  deriving stock (Eq, Show)

data Mutability
  = ReadOnly
  | CanStartTurn
  | CanMutateLocal
  | CanMutateGitHub
  | CanMerge
  deriving stock (Eq, Show)

newtype RepoName = RepoName { unRepoName :: Text }
  deriving stock (Eq, Show)

newtype IssueNumber = IssueNumber { unIssueNumber :: Int }
  deriving stock (Eq, Show)

newtype PrNumber = PrNumber { unPrNumber :: Int }
  deriving stock (Eq, Show)

newtype ThreadId = ThreadId { unThreadId :: Text }
  deriving stock (Eq, Show)

newtype TurnId = TurnId { unTurnId :: Text }
  deriving stock (Eq, Show)

newtype BranchName = BranchName { unBranchName :: Text }
  deriving stock (Eq, Show)

newtype ReviewThreadId = ReviewThreadId { unReviewThreadId :: Text }
  deriving stock (Eq, Show)

newtype CommitSha = CommitSha { unCommitSha :: Text }
  deriving stock (Eq, Show)

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)

newtype BlockedReason = BlockedReason { unBlockedReason :: Text }
  deriving stock (Eq, Show)

newtype StopReason = StopReason { unStopReason :: Text }
  deriving stock (Eq, Show)

data PlannerConfig = PlannerConfig
  { plannerRepo :: RepoName
  , plannerMaxParallel :: Int
  }
  deriving stock (Eq, Show)

data IssueCreationRequest = IssueCreationRequest
  { issueCreationTitle :: Text
  , issueCreationBody :: Text
  , issueCreationParent :: Maybe IssueNumber
  }
  deriving stock (Eq, Show)

instance ToJSON IssueCreationRequest where
  toJSON request =
    object $
      [ "title" .= issueCreationTitle request
      , "body" .= issueCreationBody request
      ]
        <> maybe [] (\parent -> ["parentIssueNumber" .= unIssueNumber parent]) (issueCreationParent request)

instance FromJSON IssueCreationRequest where
  parseJSON = withObject "IssueCreationRequest" $ \objectValue -> do
    title <- objectValue .: "title"
    if Text.null (Text.strip title)
      then fail "title must not be empty"
      else do
        body <- objectValue .:? "body" .!= ""
        parentNumber <- objectValue .:? "parentIssueNumber" <|> objectValue .:? "parent_issue_number"
        parent <- traverse parseParentIssueNumber parentNumber
        case parent of
          Just _ | Text.null (Text.strip body) -> fail "sub-issue body must not be empty"
          _ -> pure (IssueCreationRequest title body parent)

parseParentIssueNumber :: Int -> Parser IssueNumber
parseParentIssueNumber number
  | number > 0 = pure (IssueNumber number)
  | otherwise = fail "parentIssueNumber must be positive"

data IssueDependency = IssueDependency
  { dependencyIssue :: IssueNumber
  , dependencyDependsOn :: [IssueNumber]
  }
  deriving stock (Eq, Show)

instance ToJSON IssueDependency where
  toJSON dependency =
    object
      [ "issueNumber" .= unIssueNumber dependency.dependencyIssue
      , "dependsOn" .= fmap unIssueNumber dependency.dependencyDependsOn
      ]

instance FromJSON IssueDependency where
  parseJSON = withObject "IssueDependency" $ \objectValue ->
    IssueDependency
      <$> (parsePositiveIssueNumber =<< objectValue .: "issueNumber")
      <*> (traverse parsePositiveIssueNumber =<< objectValue .:? "dependsOn" .!= [])

data BlockedPlanningIssue = BlockedPlanningIssue
  { blockedPlanningIssue :: IssueNumber
  , blockedPlanningDependsOn :: [IssueNumber]
  , blockedPlanningReason :: Text
  }
  deriving stock (Eq, Show)

instance ToJSON BlockedPlanningIssue where
  toJSON blocked =
    object
      [ "issueNumber" .= unIssueNumber blocked.blockedPlanningIssue
      , "blockedBy" .= fmap unIssueNumber blocked.blockedPlanningDependsOn
      , "reason" .= blocked.blockedPlanningReason
      ]

instance FromJSON BlockedPlanningIssue where
  parseJSON = withObject "BlockedPlanningIssue" $ \objectValue -> do
    reason <- objectValue .:? "reason" .!= ""
    BlockedPlanningIssue
      <$> (parsePositiveIssueNumber =<< objectValue .: "issueNumber")
      <*> (traverse parsePositiveIssueNumber =<< objectValue .:? "blockedBy" .!= [])
      <*> pure reason

data PlanningGraph = PlanningGraph
  { planningReadyIssues :: [IssueNumber]
  , planningBlockedIssues :: [BlockedPlanningIssue]
  , planningDependencies :: [IssueDependency]
  }
  deriving stock (Eq, Show)

instance ToJSON PlanningGraph where
  toJSON graph =
    object
      [ "ready_issues" .= fmap unIssueNumber graph.planningReadyIssues
      , "blocked_issues" .= graph.planningBlockedIssues
      , "dependencies" .= graph.planningDependencies
      ]

instance FromJSON PlanningGraph where
  parseJSON = withObject "PlanningGraph" $ \objectValue ->
    PlanningGraph
      <$> (traverse parsePositiveIssueNumber =<< objectValue .:? "ready_issues" .!= [])
      <*> objectValue .:? "blocked_issues" .!= []
      <*> objectValue .:? "dependencies" .!= []

parsePositiveIssueNumber :: Int -> Parser IssueNumber
parsePositiveIssueNumber number
  | number > 0 = pure (IssueNumber number)
  | otherwise = fail "issue number must be positive"

data IssueConfig = IssueConfig
  { issueRepo :: RepoName
  , issueNumber :: IssueNumber
  , issueBranch :: BranchName
  }
  deriving stock (Eq, Show)

data PrConfig = PrConfig
  { prRepo :: RepoName
  , prNumber :: PrNumber
  , prBranch :: BranchName
  }
  deriving stock (Eq, Show)

data ActiveTurn = ActiveTurn
  { activeThreadId :: ThreadId
  , activeTurnId :: TurnId
  }
  deriving stock (Eq, Show)

data WorkerThread (activity :: ThreadActivity) where
  WorkerIdle :: ThreadId -> WorkerThread 'Idle
  WorkerActive :: ActiveTurn -> WorkerThread 'Active

deriving stock instance Eq (WorkerThread activity)
deriving stock instance Show (WorkerThread activity)

data ReviewerThread (activity :: ThreadActivity) where
  ReviewerIdle :: ThreadId -> ReviewerThread 'Idle
  ReviewerActive :: ActiveTurn -> ReviewerThread 'Active

deriving stock instance Eq (ReviewerThread activity)
deriving stock instance Show (ReviewerThread activity)

data ReviewEvidence = ReviewEvidence
  { unresolvedThreads :: NonEmpty ReviewThreadId
  , reviewedCommit :: CommitSha
  }
  deriving stock (Eq, Show)

data CleanReviewEvidence = CleanReviewEvidence
  { cleanReviewCommit :: CommitSha
  , cleanReviewComment :: Text
  }
  deriving stock (Eq, Show)

data CompletionEvidence (domain :: Domain) where
  PlanningComplete :: CompletionEvidence 'IssuePlanning
  IssueAlreadyResolved :: IssueNumber -> CompletionEvidence 'IssueImplement
  IssueComplete :: PrNumber -> CompletionEvidence 'IssueImplement
  PrMerged :: MergeCommit -> CompletionEvidence 'PrReview

deriving stock instance Eq (CompletionEvidence domain)
deriving stock instance Show (CompletionEvidence domain)

data WatcherState (domain :: Domain) (phase :: Phase) where
  PlanningReady
    :: PlannerConfig
    -> WatcherState 'IssuePlanning 'Initialized

  PlanningTurnActive
    :: PlannerConfig
    -> ActiveTurn
    -> WatcherState 'IssuePlanning 'PlanMode

  IssueNeedsTriage
    :: IssueConfig
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Triage

  IssueTriageActive
    :: IssueConfig
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'Triage

  IssuePlanReady
    :: IssueConfig
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'PlanMode

  IssueInPlanMode
    :: IssueConfig
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'PlanMode

  IssueImplementationReady
    :: IssueConfig
    -> Maybe PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

  IssueImplementing
    :: IssueConfig
    -> Maybe PrNumber
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'Implementing

  PrCheckingReviews
    :: PrConfig
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'CheckingReviews

  PrFixingReviews
    :: PrConfig
    -> ReviewEvidence
    -> WorkerThread 'Active
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'FixingReviews

  PrReviewingClean
    :: PrConfig
    -> CommitSha
    -> WorkerThread 'Idle
    -> ReviewerThread 'Active
    -> WatcherState 'PrReview 'ReviewingClean

  PrMerging
    :: PrConfig
    -> CleanReviewEvidence
    -> WatcherState 'PrReview 'Merging

  BlockedState
    :: BlockedReason
    -> WatcherState domain 'Blocked

  CompleteState
    :: CompletionEvidence domain
    -> WatcherState domain 'Complete

  StoppedState
    :: StopReason
    -> WatcherState domain 'Stopped

deriving stock instance Eq (WatcherState domain phase)
deriving stock instance Show (WatcherState domain phase)

data SomeWatcherState where
  SomeWatcherState :: KnownDomain domain => WatcherState domain phase -> SomeWatcherState

deriving stock instance Show SomeWatcherState

domainOf :: forall domain phase. KnownDomain domain => WatcherState domain phase -> Domain
domainOf _ = knownDomain @domain

phaseOf :: WatcherState domain phase -> Phase
phaseOf PlanningReady {} = Initialized
phaseOf PlanningTurnActive {} = PlanMode
phaseOf IssueNeedsTriage {} = Triage
phaseOf IssueTriageActive {} = Triage
phaseOf IssuePlanReady {} = PlanMode
phaseOf IssueInPlanMode {} = PlanMode
phaseOf IssueImplementationReady {} = Implementing
phaseOf IssueImplementing {} = Implementing
phaseOf PrCheckingReviews {} = CheckingReviews
phaseOf PrFixingReviews {} = FixingReviews
phaseOf PrReviewingClean {} = ReviewingClean
phaseOf PrMerging {} = Merging
phaseOf BlockedState {} = Blocked
phaseOf CompleteState {} = Complete
phaseOf StoppedState {} = Stopped

someDomain :: SomeWatcherState -> Domain
someDomain (SomeWatcherState state) = domainOf state

somePhase :: SomeWatcherState -> Phase
somePhase (SomeWatcherState state) = phaseOf state

isTerminalPhase :: Phase -> Bool
isTerminalPhase Blocked = True
isTerminalPhase Complete = True
isTerminalPhase Stopped = True
isTerminalPhase _ = False
