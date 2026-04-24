{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssuePlanning.Types
  ( PlannerConfig (..)
  , IssueCreationRequest (..)
  , IssueDependency (..)
  , BlockedPlanningIssue (..)
  , PlanningGraph (..)
  , parseParentIssueNumber
  , parsePositiveIssueNumber
  , issueNumberValue
  , issueNumberAlias
  , issueNumberListAlias
  ) where

import CodexWatcher.Core.Ids (IssueNumber (..), RepoName)
import CodexWatcher.Core.Limits (MaxParallel)
import Control.Applicative ((<|>))
import Data.Aeson (FromJSON (..), Object, ToJSON (..), Value, object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.Text (Text)
import Data.Text qualified as Text

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
