{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeAbstractions #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module CodexWatcher.Types
  ( Domain (..)
  , SDomain (..)
  , Phase (..)
  , SPhase (..)
  , ThreadActivity (..)
  , Mutability (..)
  , SMutability (..)
  , KnownDomain
  , KnownPhase
  , KnownMutability
  , RepoName (..)
  , IssueNumber (..)
  , PrNumber (..)
  , ThreadId (..)
  , TurnId (..)
  , RequestId (..)
  , BranchName (..)
  , ReviewThreadId (..)
  , CommitSha (..)
  , RuntimeWorkdir (..)
  , RuntimeStateDir (..)
  , RuntimeCwd (..)
  , MergeCommit (..)
  , BlockedReason (..)
  , StopReason (..)
  , MaxParallel
  , PollSeconds
  , StaleSeconds
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
  , nextRequestId
  , someDomain
  , somePhase
  , isTerminalState
  , mkMaxParallel
  , mkPollSeconds
  , mkStaleSeconds
  , unMaxParallel
  , unPollSeconds
  , unStaleSeconds
  , pollSecondsMicros
  , runtimeCwdPath
  , runtimeStateDirFile
  , runtimeStateDirPath
  , runtimeWorkdirPath
  ) where

import Data.Aeson (FromJSON (..), Object, ToJSON (..), Value, object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Singletons (SingI (..), SingKind (..))
import Data.Singletons.TH (genSingletons, singDecideInstances)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Control.Applicative ((<|>))
import Data.Kind (Constraint)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Aeson.Types (Parser)
import System.FilePath ((</>))

data Domain
  = IssuePlanning
  | IssueImplement
  | PrReview
  deriving stock (Eq, Show)

type KnownDomain :: Domain -> Constraint
type KnownDomain domain = SingI domain

data Phase
  = Initialized
  | PlanMode
  | Implementing
  | CheckingReviews
  | FixingReviews
  | ReviewingClean
  | WaitingMergeability
  | Merging
  | Blocked
  | Complete
  | Stopped
  deriving stock (Eq, Show)

type KnownPhase :: Phase -> Constraint
type KnownPhase phase = SingI phase

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

$(genSingletons [''Domain, ''Phase, ''Mutability])
$(singDecideInstances [''Mutability])

type KnownMutability :: Mutability -> Constraint
type KnownMutability mutability = SingI mutability

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

newtype RuntimeWorkdir = RuntimeWorkdir { unRuntimeWorkdir :: FilePath }
  deriving stock (Eq, Show)

newtype RuntimeStateDir = RuntimeStateDir { unRuntimeStateDir :: FilePath }
  deriving stock (Eq, Show)

data RuntimeCwd
  = RuntimeWorkdirCwd RuntimeWorkdir
  | RuntimeStateDirCwd RuntimeStateDir
  deriving stock (Eq, Show)

runtimeWorkdirPath :: RuntimeWorkdir -> FilePath
runtimeWorkdirPath =
  unRuntimeWorkdir

runtimeStateDirPath :: RuntimeStateDir -> FilePath
runtimeStateDirPath =
  unRuntimeStateDir

runtimeStateDirFile :: RuntimeStateDir -> FilePath -> FilePath
runtimeStateDirFile stateDir fileName =
  unRuntimeStateDir stateDir </> fileName

runtimeCwdPath :: RuntimeCwd -> FilePath
runtimeCwdPath = \case
  RuntimeWorkdirCwd workdir -> runtimeWorkdirPath workdir
  RuntimeStateDirCwd stateDir -> runtimeStateDirPath stateDir

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)

newtype BlockedReason = BlockedReason { unBlockedReason :: Text }
  deriving stock (Eq, Show)

newtype StopReason = StopReason { unStopReason :: Text }
  deriving stock (Eq, Show)

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

data PlannerConfig = PlannerConfig
  { plannerRepo :: RepoName
  , plannerMaxParallel :: MaxParallel
  , plannerScopeIssues :: [IssueNumber]
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
      <$> issueNumberAlias objectValue ["issueNumber", "issue", "number"]
      <*> issueNumberListAlias objectValue ["dependsOn", "depends_on"]

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
      <$> issueNumberAlias objectValue ["issueNumber", "issue", "number"]
      <*> issueNumberListAlias objectValue ["blockedBy", "blocked_by"]
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
  parseJSON = withObject "PlanningGraph" $ \objectValue -> do
    readyIssueValues <- objectValue .:? "ready_issues" .!= ([] :: [Value])
    PlanningGraph
      <$> traverse issueNumberValue readyIssueValues
      <*> objectValue .:? "blocked_issues" .!= []
      <*> objectValue .:? "dependencies" .!= []

parsePositiveIssueNumber :: Int -> Parser IssueNumber
parsePositiveIssueNumber number
  | number > 0 = pure (IssueNumber number)
  | otherwise = fail "issue number must be positive"

issueNumberValue :: Value -> Parser IssueNumber
issueNumberValue value =
  (parsePositiveIssueNumber =<< parseJSON value)
    <|> withObject "IssueNumberObject" (\objectValue -> issueNumberAlias objectValue ["issueNumber", "issue", "number"]) value

issueNumberAlias :: Object -> [Text] -> Parser IssueNumber
issueNumberAlias objectValue aliases =
  parseFirst aliases
 where
  parseFirst [] = fail "missing issue number"
  parseFirst (alias : rest) =
    case KeyMap.lookup (Key.fromText alias) objectValue of
      Just value -> issueNumberValue value
      Nothing -> parseFirst rest

issueNumberListAlias :: Object -> [Text] -> Parser [IssueNumber]
issueNumberListAlias objectValue aliases =
  parseFirst aliases
 where
  parseFirst [] = pure []
  parseFirst (alias : rest) =
    case KeyMap.lookup (Key.fromText alias) objectValue of
      Just value -> parseJSON value >>= traverse issueNumberValue
      Nothing -> parseFirst rest

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

  PlanningWaitingForReadyIssues
    :: PlannerConfig
    -> PlanningGraph
    -> WatcherState 'IssuePlanning 'Initialized

  IssueReadyToPlan
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'PlanMode

  IssueInPlanMode
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'PlanMode

  IssuePlanReady
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

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

  IssueHandoffReady
    :: IssueConfig
    -> PrNumber
    -> WatcherState 'IssueImplement 'Implementing

  IssueHandoffInitialized
    :: IssueConfig
    -> PrNumber
    -> WatcherState 'IssueImplement 'Implementing

  IssueWaitingForPrMerge
    :: IssueConfig
    -> PrNumber
    -> WatcherState 'IssueImplement 'Implementing

  IssueWaitingForIssueClose
    :: IssueConfig
    -> PrNumber
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

  PrWaitingForMergeability
    :: PrConfig
    -> CleanReviewEvidence
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'WaitingMergeability

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
  SomeWatcherState :: (KnownDomain domain, KnownPhase phase) => WatcherState domain phase -> SomeWatcherState

deriving stock instance Show SomeWatcherState

domainOf :: forall domain phase. KnownDomain domain => WatcherState domain phase -> Domain
domainOf _ = fromSing (sing @domain)

phaseOf :: forall domain phase. KnownPhase phase => WatcherState domain phase -> Phase
phaseOf _ = fromSing (sing @phase)

someDomain :: SomeWatcherState -> Domain
someDomain (SomeWatcherState state) = domainOf state

somePhase :: SomeWatcherState -> Phase
somePhase (SomeWatcherState state) = phaseOf state

isTerminalPhaseSing :: SPhase phase -> Bool
isTerminalPhaseSing SBlocked = True
isTerminalPhaseSing SComplete = True
isTerminalPhaseSing SStopped = True
isTerminalPhaseSing _ = False

isTerminalState :: SomeWatcherState -> Bool
isTerminalState (SomeWatcherState (_ :: WatcherState domain phase)) = isTerminalPhaseSing (sing @phase)
