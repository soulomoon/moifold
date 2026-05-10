{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Domain.IssuePlanning.Scope
  ( planningGraphIssues
  , planningGraphScopeContains
  , scopedGraphClosure
  ) where

import CodexWatcher.Workflow.GitHub.Ids (IssueNumber)
import CodexWatcher.Domain.IssuePlanning.Types
  ( BlockedPlanningIssue (..)
  , IssueDependency (..)
  , PlanningGraph (..)
  )

planningGraphIssues :: PlanningGraph -> [IssueNumber]
planningGraphIssues graph =
  graph.planningReadyIssues <> blockedIssues <> dependencyIssues <> dependencyRefs
 where
  blockedIssues = fmap blockedPlanningIssue graph.planningBlockedIssues
  dependencyIssues = fmap dependencyIssue graph.planningDependencies
  dependencyRefs = concatMap dependencyDependsOn graph.planningDependencies

planningGraphScopeContains :: [IssueNumber] -> PlanningGraph -> IssueNumber -> Bool
planningGraphScopeContains [] _graph _issue =
  True
planningGraphScopeContains scopeIssues graph issue =
  issue `elem` scopedGraphClosure scopeIssues graph

scopedGraphClosure :: [IssueNumber] -> PlanningGraph -> [IssueNumber]
scopedGraphClosure scopeIssues graph =
  go [] scopeIssues
 where
  go seen [] = seen
  go seen (issue : rest)
    | issue `elem` seen = go seen rest
    | otherwise = go (seen <> [issue]) (graphIssueDependencies issue <> rest)

  graphIssueDependencies issue =
    concat
      [ dependency.dependencyDependsOn
      | dependency <- graph.planningDependencies
      , dependency.dependencyIssue == issue
      ]
      <> concat
        [ blocked.blockedPlanningDependsOn
        | blocked <- graph.planningBlockedIssues
        , blocked.blockedPlanningIssue == issue
        ]
