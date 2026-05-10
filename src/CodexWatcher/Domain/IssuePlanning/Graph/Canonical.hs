{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssuePlanning.Graph.Canonical
  ( PlanningIssueFact (..)
  , canonicalPlanningGraph
  , planningIssueFactsFromSnapshot
  ) where

import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))
import CodexWatcher.Domain.IssuePlanning.Types
  ( BlockedPlanningIssue (..)
  , IssueDependency (..)
  , PlannerConfig (..)
  , PlanningGraph (..)
  )
import Control.Applicative ((<|>))
import Data.Aeson (FromJSON (..), Value, withObject, (.:), (.:?), (.!=))
import Data.Aeson.Types (Parser, parseEither)
import Data.List (nub, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data PlanningIssueFact = PlanningIssueFact
  { planningIssueFactNumber :: IssueNumber
  , planningIssueFactClosed :: Bool
  , planningIssueFactParent :: Maybe IssueNumber
  , planningIssueFactSubIssues :: [IssueNumber]
  }
  deriving stock (Eq, Show)

data SnapshotIssue = SnapshotIssue
  { snapshotIssueNumber :: IssueNumber
  , snapshotIssueClosed :: Bool
  , snapshotIssueParent :: Maybe IssueNumber
  , snapshotIssueSubIssues :: [SnapshotIssue]
  }
  deriving stock (Eq, Show)

planningIssueFactsFromSnapshot :: Value -> Either Text [PlanningIssueFact]
planningIssueFactsFromSnapshot value =
  case parseEither parseIssueSnapshot value of
    Left reason -> Left (Text.pack reason)
    Right issues -> Right (dedupeFacts (concatMap flattenIssue issues))

canonicalPlanningGraph :: PlannerConfig -> [PlanningIssueFact] -> PlanningGraph -> PlanningGraph
canonicalPlanningGraph plannerConfig facts candidate =
  PlanningGraph
    { planningReadyIssues = readyIssues
    , planningBlockedIssues = blockedIssues
    , planningDependencies = dependencies
    }
 where
  factMap = Map.fromList [(fact.planningIssueFactNumber, fact) | fact <- dedupeFacts facts]
  orderedOpenIssues =
    [ issue
    | issue <- orderedIssues plannerConfig (Map.elems factMap)
    , maybe False (not . planningIssueFactClosed) (Map.lookup issue factMap)
    ]
  openIssueSet = Set.fromList orderedOpenIssues
  dependencyHints = dependencyHintMap candidate openIssueSet
  childBlockers = childBlockerMap factMap openIssueSet
  blockersByIssue =
    Map.unionWith unionIssues dependencyHints childBlockers
  dependencies =
    [ IssueDependency issue blockers
    | issue <- orderedOpenIssues
    , let blockers = Map.findWithDefault [] issue blockersByIssue
    ]
  readyIssues =
    [ issue
    | IssueDependency issue blockers <- dependencies
    , null blockers
    ]
  blockedIssues =
    [ BlockedPlanningIssue issue blockers (blockedReason issue blockers)
    | IssueDependency issue blockers <- dependencies
    , not (null blockers)
    ]
  blockedReason issue blockers =
    fromMaybe
      ("waiting for open dependencies: " <> issueListText blockers)
      (candidateBlockedReason candidate issue blockers)

parseIssueSnapshot :: Value -> Parser [SnapshotIssue]
parseIssueSnapshot =
  withObject "IssuePlanningSnapshot" \objectValue ->
    objectValue .:? "issues" .!= []

instance FromJSON SnapshotIssue where
  parseJSON =
    withObject "SnapshotIssue" \objectValue -> do
      number <- IssueNumber <$> objectValue .: "number"
      state <- objectValue .:? "state" .!= ("" :: Text)
      closed <- objectValue .:? "closed" .!= (Text.toUpper state == "CLOSED")
      parent <- fmap IssueNumber <$> objectValue .:? "parentIssueNumber"
      subIssues <- objectValue .:? "subIssues" .!= []
      pure
        SnapshotIssue
          { snapshotIssueNumber = number
          , snapshotIssueClosed = closed || Text.toUpper state == "CLOSED"
          , snapshotIssueParent = parent
          , snapshotIssueSubIssues = subIssues
          }

flattenIssue :: SnapshotIssue -> [PlanningIssueFact]
flattenIssue issue =
  PlanningIssueFact
    { planningIssueFactNumber = issue.snapshotIssueNumber
    , planningIssueFactClosed = issue.snapshotIssueClosed
    , planningIssueFactParent = issue.snapshotIssueParent
    , planningIssueFactSubIssues = fmap snapshotIssueNumber issue.snapshotIssueSubIssues
    }
    : concatMap flattenIssue issue.snapshotIssueSubIssues

dedupeFacts :: [PlanningIssueFact] -> [PlanningIssueFact]
dedupeFacts =
  Map.elems . foldl insertFact Map.empty
 where
  insertFact facts fact =
    Map.insertWith mergeFact fact.planningIssueFactNumber fact facts
  mergeFact new old =
    PlanningIssueFact
      { planningIssueFactNumber = old.planningIssueFactNumber
      , planningIssueFactClosed = old.planningIssueFactClosed || new.planningIssueFactClosed
      , planningIssueFactParent = old.planningIssueFactParent <|> new.planningIssueFactParent
      , planningIssueFactSubIssues = unionIssues old.planningIssueFactSubIssues new.planningIssueFactSubIssues
      }

orderedIssues :: PlannerConfig -> [PlanningIssueFact] -> [IssueNumber]
orderedIssues plannerConfig facts =
  case plannerConfig.plannerScopeIssues of
    [] -> sortOn unIssueNumber (fmap planningIssueFactNumber facts)
    scopeIssues -> scopeIssues <> [issue | issue <- descendantIssues, issue `notElem` scopeIssues]
 where
  factMap = Map.fromList [(fact.planningIssueFactNumber, fact) | fact <- facts]
  descendantIssues =
    concatMap descendantsOf plannerConfig.plannerScopeIssues
  descendantsOf issue =
    case Map.lookup issue factMap of
      Nothing -> []
      Just fact -> fact.planningIssueFactSubIssues <> concatMap descendantsOf fact.planningIssueFactSubIssues

dependencyHintMap :: PlanningGraph -> Set IssueNumber -> Map IssueNumber [IssueNumber]
dependencyHintMap candidate openIssueSet =
  Map.fromListWith unionIssues (dependencyEntries <> blockedEntries)
 where
  dependencyEntries =
    [ (dependency.dependencyIssue, filterOpen dependency.dependencyDependsOn)
    | dependency <- candidate.planningDependencies
    , dependency.dependencyIssue `Set.member` openIssueSet
    ]
  blockedEntries =
    [ (blocked.blockedPlanningIssue, filterOpen blocked.blockedPlanningDependsOn)
    | blocked <- candidate.planningBlockedIssues
    , blocked.blockedPlanningIssue `Set.member` openIssueSet
    ]
  filterOpen =
    filter (`Set.member` openIssueSet)

childBlockerMap :: Map IssueNumber PlanningIssueFact -> Set IssueNumber -> Map IssueNumber [IssueNumber]
childBlockerMap factMap openIssueSet =
  Map.fromList
    [ (issue, openChildren)
    | (issue, fact) <- Map.toList factMap
    , issue `Set.member` openIssueSet
    , let openChildren = filter (`Set.member` openIssueSet) fact.planningIssueFactSubIssues
    , not (null openChildren)
    ]

candidateBlockedReason :: PlanningGraph -> IssueNumber -> [IssueNumber] -> Maybe Text
candidateBlockedReason candidate issue blockers =
  case matchingReasons of
    reason : _ | not (Text.null reason) -> Just reason
    _ -> Nothing
 where
  blockersSet = Set.fromList blockers
  matchingReasons =
    [ blocked.blockedPlanningReason
    | blocked <- candidate.planningBlockedIssues
    , blocked.blockedPlanningIssue == issue
    , Set.fromList blocked.blockedPlanningDependsOn == blockersSet
    ]

unionIssues :: [IssueNumber] -> [IssueNumber] -> [IssueNumber]
unionIssues left right =
  nub (left <> right)

issueListText :: [IssueNumber] -> Text
issueListText issues =
  Text.intercalate ", " (fmap (("#" <>) . Text.pack . show . unIssueNumber) issues)
