{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module BoundaryPolicySpec
  ( coreBoundaryForbiddenImportModules
  , workflowBoundaryPolicyTests
  ) where

import CodexWatcher.Workflow.GitHub.Ids
import CodexWatcher.Domain.PrReview.Types
import CodexWatcher.Runtime.Command.Render (renderRuntimeCommand)
import CodexWatcher.Runtime.Command.Types (RuntimeCommand (..), RuntimeCommandSpec (..))
import CodexWatcher.Workflow.GitHub.Command qualified as WorkflowGitHubCommand
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.FilePath ((</>))
import TestSupport.SourceScan

workflowBoundaryPolicyTests :: IO Bool
workflowBoundaryPolicyTests = do
  results <-
    sequence
      [ workflowCabalProjectListsStandaloneWorkflowPackages
      , workflowMoifoldCabalConsumesStandaloneWorkflowPackages
      , workflowCoreStandalonePackageKeepsPackageBoundary
      , workflowCodexStandalonePackageKeepsPackageBoundary
      , workflowGithubStandalonePackageKeepsPackageBoundary
      , workflowMoifoldCabalLibraryDoesNotReexportAdapters
      , workflowGithubCommandFacadeMatchesRuntimeRender
      , workflowIssueImplementLifecycleBoundarySourceScans
      ]
  pure (and results)

assert :: String -> Bool -> IO Bool
assert assertionName condition = do
  if condition
    then putStrLn ("PASS " <> assertionName)
    else putStrLn ("FAIL " <> assertionName)
  pure condition

workflowIssueImplementLifecycleBoundarySourceScans :: IO Bool
workflowIssueImplementLifecycleBoundarySourceScans = do
  coreSources <- sourceTextUnder ("agent-workflow-core" </> "src")
  lifecycleSources <-
    Text.intercalate "\n"
      <$> traverse
        (fmap Text.pack . readFile)
        [ "src" </> "CodexWatcher" </> "Domain" </> "IssueImplement" </> "Watcher.hs"
        , "src" </> "CodexWatcher" </> "Domain" </> "IssueImplement" </> "Loop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "Runtime.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "TurnStart.hs"
        , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "IssuePlanningFanout.hs"
        ]
  daemonSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Daemon.hs")
  issueFanoutSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "IssueFanout.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  cabalSource <- TextIO.readFile "moifold.cabal"
  let coreForbiddenImportModules =
        [ "CodexWatcher.ChildDaemon"
        , "CodexWatcher.WatcherRuntimeStatus"
        , "CodexWatcher.Healthcheck"
        , "CodexWatcher.EventLogRepair"
        , "CodexWatcher.Cli.Command.IssueFanout"
        , "CodexWatcher.AutomaticLoop.IssuePlanningFanout"
        , "CodexWatcher.Domain.IssueImplement"
        , "CodexWatcher.EventLog"
        , "CodexWatcher.Core.State"
        ]
      coreForbiddenTokens =
        [ "IssueConfig"
        , "WatcherEvent"
        , "SomeWatcherState"
        , "runtime-owner"
        , "issue-watcher.pid"
        , ".lock"
        ]
      lifecycleIndexedRouterTokens =
        [ "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed"
        , "projectIssueImplement"
        , "IssueImplementIndexedSpec"
        ]
      mainLibrarySection = cabalComponentSection "library" cabalSource
      coreImportViolations =
        sourceImportViolationsIn "agent-workflow-core/src" coreForbiddenImportModules coreSources
      coreTokenViolations =
        filter (`Text.isInfixOf` coreSources) coreForbiddenTokens
      lifecycleRouterViolations =
        filter (`Text.isInfixOf` lifecycleSources) lifecycleIndexedRouterTokens
      adapterReexportViolations =
        filter
          (`Text.isInfixOf` mainLibrarySection)
          [ "reexported-modules:"
          , "CodexWatcher.Workflow.Agent"
          , "CodexWatcher.Workflow.GitHub"
          ]
  importsOk <-
    assertNoTextMatches
      "workflow core source has no IssueImplement lifecycle ownership imports"
      coreImportViolations
  tokensOk <-
    assertNoTextMatches
      "workflow core source has no IssueImplement lifecycle ownership tokens"
      coreTokenViolations
  lifecycleRouterOk <-
    assertNoTextMatches
      "IssueImplement lifecycle modules do not route through indexed daemon projectors"
      lifecycleRouterViolations
  daemonRouterOk <-
    assert
      "live IssueImplement indexed projection routing remains isolated to Daemon"
      ("CodexWatcher.Workflow.Moifold.IssueImplement.Indexed" `Text.isInfixOf` daemonSource)
  compatibilityFacadeOk <-
    assertNoTextMatches
      "main moifold library keeps compatibility facades without adapter reexports"
      adapterReexportViolations
  launchOwnershipOk <-
    assert
      "IssueFanout keeps child lifecycle ownership in moifold"
      ( all
          (`Text.isInfixOf` issueFanoutSource)
          [ "startChildDaemonChecked"
          , "issue-watcher.pid"
          ]
      )
  healthcheckReadOnlyOk <-
    assert
      "healthcheck surfaces issue implement lifecycle files without mutation"
      ( all
          (`Text.isInfixOf` healthcheckSource)
          [ "(\"issueState\", \"issue-state.json\")"
          , "(\"plannerState\", \"planner-state.json\")"
          , "(\"daemonState\", \"daemon-state.json\")"
          , "(\"blockedState\", \"block-state.json\")"
          , "(\"runtimeOwner\", \"runtime-owner.json\")"
          , "fallbackPidPath kind stateDir' config.pidPath"
          ]
          && not ("planning-state.json" `Text.isInfixOf` healthcheckSource)
          && not ("writeJsonValue" `Text.isInfixOf` healthcheckSource)
      )
  healthcheckRuntimeOwnerContractOk <-
    assert
      "healthcheck preserves runtime-owner.json field-path contract"
      ( all
          (`Text.isInfixOf` healthcheckSource)
          [ "SIssuePlanning ->\n    sharedStateFiles"
          , "SIssueImplement ->\n    sharedStateFiles"
          , "(\"runtimeOwner\", \"runtime-owner.json\")"
          , "runtimeOwner' = config.runtimeOwner <|> lookupStateText [\"runtimeOwner\", \"owner\"] states"
          ]
          && not ("lookupStateText [\"runtimeOwner\", \"lease\", \"runtime\"]" `Text.isInfixOf` healthcheckSource)
      )
  pure
    ( importsOk
        && tokensOk
        && lifecycleRouterOk
        && daemonRouterOk
        && compatibilityFacadeOk
        && launchOwnershipOk
        && healthcheckReadOnlyOk
        && healthcheckRuntimeOwnerContractOk
    )

workflowMoifoldCabalConsumesStandaloneWorkflowPackages :: IO Bool
workflowMoifoldCabalConsumesStandaloneWorkflowPackages = do
  cabalSource <- Text.pack <$> readFile "moifold.cabal"
  let mainLibrarySection = cabalComponentSection "library" cabalSource
      watcherCoreTestSection = cabalComponentSection "test-suite watcher-core-test" cabalSource
      mainLibraryDependencyPackages = cabalBuildDependsPackages mainLibrarySection
      watcherCoreTestDependencyPackages = cabalBuildDependsPackages watcherCoreTestSection
      internalWorkflowComponentMatches =
        filter
          (`elem` Text.lines cabalSource)
          [ "library agent-workflow-core"
          , "library agent-workflow-codex"
          , "library agent-workflow-github"
          ]
      internalWorkflowDependencyMatches =
        filter
          (`Text.isInfixOf` cabalSource)
          [ "moifold:agent-workflow-core"
          , "moifold:agent-workflow-codex"
          , "moifold:agent-workflow-github"
          ]
      standaloneWorkflowDependencyBounds =
        [ "agent-workflow-core >=0.1 && <0.2"
        , "agent-workflow-codex >=0.1 && <0.2"
        , "agent-workflow-github >=0.1 && <0.2"
        ]
      mainLibraryMissingStandalonePackages =
        filter (`notElem` mainLibraryDependencyPackages) standaloneWorkflowPackageNames
      watcherCoreTestMissingStandalonePackages =
        filter (`notElem` watcherCoreTestDependencyPackages) standaloneWorkflowPackageNames
  noInternalComponentsOk <-
    assertNoTextMatches
      "moifold cabal no longer defines internal workflow sublibraries"
      internalWorkflowComponentMatches
  noInternalDependenciesOk <-
    assertNoTextMatches
      "moifold cabal no longer consumes internal workflow sublibraries"
      internalWorkflowDependencyMatches
  mainLibraryPackageNamesOk <-
    assertNoTextMatches
      "main moifold library depends on standalone workflow package names"
      mainLibraryMissingStandalonePackages
  watcherCoreTestPackageNamesOk <-
    assertNoTextMatches
      "watcher-core-test depends on standalone workflow package names"
      watcherCoreTestMissingStandalonePackages
  mainLibraryDependsOk <-
    assert
      "main moifold library depends on standalone workflow packages with approved bounds"
      (all (`Text.isInfixOf` mainLibrarySection) standaloneWorkflowDependencyBounds)
  watcherCoreTestDependsOk <-
    assert
      "watcher-core-test depends on standalone workflow packages with approved bounds"
      (all (`Text.isInfixOf` watcherCoreTestSection) standaloneWorkflowDependencyBounds)
  pure
    ( noInternalComponentsOk
        && noInternalDependenciesOk
        && mainLibraryPackageNamesOk
        && watcherCoreTestPackageNamesOk
        && mainLibraryDependsOk
        && watcherCoreTestDependsOk
    )

workflowCabalProjectListsStandaloneWorkflowPackages :: IO Bool
workflowCabalProjectListsStandaloneWorkflowPackages = do
  projectSource <- Text.pack <$> readFile "cabal.project"
  let projectPackages = sort (cabalFieldEntries "packages" projectSource)
      expectedPackages = sort ("." : standaloneWorkflowPackageNames)
      packageMismatches =
        inventoryMismatches "cabal.project packages" expectedPackages projectPackages
      internalWorkflowDependencyMatches =
        filter
          (`Text.isInfixOf` projectSource)
          [ "moifold:agent-workflow-core"
          , "moifold:agent-workflow-codex"
          , "moifold:agent-workflow-github"
          ]
  packageInventoryOk <-
    assertNoTextMatches
      "cabal.project lists the root and standalone workflow packages"
      packageMismatches
  noInternalDependenciesOk <-
    assertNoTextMatches
      "cabal.project does not reference internal workflow sublibraries"
      internalWorkflowDependencyMatches
  pure (packageInventoryOk && noInternalDependenciesOk)

standaloneWorkflowPackageNames :: [Text]
standaloneWorkflowPackageNames =
  [ "agent-workflow-core"
  , "agent-workflow-codex"
  , "agent-workflow-github"
  ]

workflowCoreStandalonePackageKeepsPackageBoundary :: IO Bool
workflowCoreStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-core" </> "agent-workflow-core.cabal")
  coreSources <- sourceTextUnder ("agent-workflow-core" </> "src")
  coreSourceModules <- sourceModulesUnder ("agent-workflow-core" </> "src")
  forbiddenImportViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-core" </> "src")
      coreBoundaryForbiddenImportModules
  let standaloneCoreSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "aeson"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "websockets"
        , "moifold,"
        , "moifold:"
        , "agent-workflow-codex"
        , "agent-workflow-github"
        ]
      forbiddenConcreteTypes =
        [ "ChildDaemon"
        , "Healthcheck"
        , "EventLogRepair"
        , "WatcherRuntimeStatus"
        , "SomeWatcherState"
        , "WatcherState"
        , "WatcherEvent"
        , "DaemonObservation"
        , "ObservedPolicyTick"
        , "EffectPlan"
        , "SomeEffect"
        , "ActionExecutionMode"
        , "RuntimeInterpreter"
        , "AppServerTurn"
        , "AppServerRequest"
        , "GitHubCommandSpec"
        , "RepoName"
        , "PrConfig"
        , "DaemonOptions"
        , "DaemonTickResult"
        , "runDaemonTickWithEvents"
        , "runObservedDaemonTickWithEvents"
        , "DaemonObservedTickResult"
        , "DaemonObservedTransactionFailure"
        , "CompatibilityWrite"
        , "PidFile"
        , "RuntimeOwner"
        , "RuntimeLease"
        , "FilePath"
        , "IO"
        , "ActionExecutionReport"
        , "CommandReport"
        , "PlannedAction"
        ]
      forbiddenConcreteNeedles =
        [ "runtime-owner"
        , "pid-file"
        , "pidFile"
        , ".lock"
        , "readFile"
        , "writeFile"
        , "createDirectory"
        , "System.Directory"
        , "System.FilePath"
        , "System.Process"
        ]
      coreSourceTokens = sourceIdentifierTokens coreSources
      standaloneForbiddenPackageMatches =
        filter (`Text.isInfixOf` standaloneCoreSection) standaloneForbiddenPackageNeedles
      forbiddenConcreteTokenMatches =
        filter (`elem` coreSourceTokens) forbiddenConcreteTypes
      forbiddenConcreteNeedleMatches =
        filter (`Text.isInfixOf` coreSources) forbiddenConcreteNeedles
      standaloneCoreDependencyPackages = cabalBuildDependsPackages standaloneCoreSection
      unapprovedStandaloneCoreDependencyMatches =
        filter (`notElem` ["base", "bytestring", "text"]) standaloneCoreDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneCoreSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-core exposed modules" (sort coreSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-core approved modules" (sort coreStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnCoreDeps =
        all (`elem` standaloneCoreDependencyPackages) ["base", "bytestring", "text"]
          && null unapprovedStandaloneCoreDependencyMatches
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-core"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          ]
  standalonePackageOk <-
    assertNoTextMatches
      "standalone workflow core package excludes forbidden package dependencies"
      standaloneForbiddenPackageMatches
  standaloneApprovedDependencyOk <-
    assertNoTextMatches
      "standalone workflow core package excludes unapproved package dependencies"
      unapprovedStandaloneCoreDependencyMatches
  importOk <-
    assertNoTextMatches
      "workflow core source excludes forbidden concrete imports"
      forbiddenImportViolations
  tokenOk <-
    assertNoTextMatches
      "workflow core source excludes concrete lifecycle action and event tokens"
      forbiddenConcreteTokenMatches
  ownershipNeedleOk <-
    assertNoTextMatches
      "workflow core source excludes concrete daemon ownership text"
      forbiddenConcreteNeedleMatches
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow core package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow core package exposes generic core modules"
      expectedStandaloneModuleMismatches
  standaloneCoreDepsOk <-
    assert
      "standalone workflow core package keeps the approved generic dependency set"
      standaloneDependsOnlyOnCoreDeps
  standaloneMetadataOk <-
    assert
      "standalone workflow core package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  pure
    ( standalonePackageOk
        && standaloneApprovedDependencyOk
        && importOk
        && tokenOk
        && ownershipNeedleOk
        && standaloneInventoryOk
        && standaloneExposedOk
        && standaloneCoreDepsOk
        && standaloneMetadataOk
    )

coreStandaloneExposedModules :: [Text]
coreStandaloneExposedModules =
  [ "CodexWatcher.Workflow.Audit"
  , "CodexWatcher.Workflow.Codec"
  , "CodexWatcher.Workflow.Daemon.Core"
  , "CodexWatcher.Workflow.DSL"
  , "CodexWatcher.Workflow.EventLog.Commit.Core"
  , "CodexWatcher.Workflow.EventLog.Core"
  , "CodexWatcher.Workflow.EventLog.File.Core"
  , "CodexWatcher.Workflow.Execution.Core"
  , "CodexWatcher.Workflow.Failure"
  , "CodexWatcher.Workflow.Indexed.Spec"
  , "CodexWatcher.Workflow.Permission.Core"
  , "CodexWatcher.Workflow.Spec"
  , "CodexWatcher.Workflow.Transaction.Core"
  ]

coreBoundaryForbiddenImportModules :: [Text]
coreBoundaryForbiddenImportModules =
  [ "CodexWatcher.Core.State"
  , "CodexWatcher.Domain."
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.Observation"
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Workflow.Moifold"
  , "CodexWatcher.Workflow.Observation"
  , "Data.Aeson"
  , "Data.Aeson.Key"
  , "Data.Aeson.KeyMap"
  , "Data.Aeson.Types"
  , "CodexWatcher.ActionExecutor"
  , "CodexWatcher.Runtime"
  , "CodexWatcher.EffectInterpreter"
  , "CodexWatcher.Runtime.Command"
  , "CodexWatcher.Runtime.Interpreter"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Workflow.GitHub"
  , "CodexWatcher.AppServerClient"
  , "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Agent.Codex"
  , "CodexWatcher.Workflow.Observation.Agent"
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.RunnerGuard"
  , "CodexWatcher.WatcherRuntimeStatus"
  , "CodexWatcher.Supervisor"
  ]

workflowCodexStandalonePackageKeepsPackageBoundary :: IO Bool
workflowCodexStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-codex" </> "agent-workflow-codex.cabal")
  codexSources <- sourceTextUnder ("agent-workflow-codex" </> "src")
  codexSourceModules <- sourceModulesUnder ("agent-workflow-codex" </> "src")
  forbiddenImportViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-codex" </> "src")
      codexBoundaryForbiddenImportModules
  let standaloneCodexSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "containers"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "moifold,"
        , "moifold:"
        ]
      forbiddenSourceNeedles =
        [ "CodexWatcher.AppServerClient"
        , "CodexWatcher.ActionExecutor"
        , "CodexWatcher.ChildDaemon"
        , "CodexWatcher.Daemon"
        , "CodexWatcher.DaemonLoop"
        , "CodexWatcher.Domain."
        , "CodexWatcher.Effects"
        , "CodexWatcher.EventLog"
        , "CodexWatcher.EventLogRepair"
        , "CodexWatcher.GhGit"
        , "CodexWatcher.Healthcheck"
        , "CodexWatcher.Runtime."
        , "CodexWatcher.StateMachine"
        , "CodexWatcher.Workflow.GitHub"
        , "CodexWatcher.Workflow.Moifold."
        , "issue-state.json"
        , "daemon-state.json"
        , "planning-state.json"
        , "pr-url"
        , "block-state"
        , "repair-state"
        , "runtime-owner"
        ]
      forbiddenConcreteTypes =
        [ "WatcherEvent"
        , "SomeWatcherState"
        ]
      codexSourceTokens = sourceIdentifierTokens codexSources
      standaloneForbiddenPackageMatches =
        filter (`Text.isInfixOf` standaloneCodexSection) standaloneForbiddenPackageNeedles
      forbiddenSourceMatches =
        filter (`Text.isInfixOf` codexSources) forbiddenSourceNeedles
      forbiddenConcreteTypeMatches =
        filter (`elem` codexSourceTokens) forbiddenConcreteTypes
      standaloneCodexDependencyPackages = cabalBuildDependsPackages standaloneCodexSection
      unapprovedStandaloneCodexDependencyMatches =
        filter (`notElem` ["aeson", "agent-workflow-core", "base", "bytestring", "text", "websockets"]) standaloneCodexDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneCodexSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-codex exposed modules" (sort codexSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-codex approved modules" (sort codexStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnCodexDeps =
        all (`elem` standaloneCodexDependencyPackages) ["aeson", "agent-workflow-core", "base", "bytestring", "text", "websockets"]
          && null unapprovedStandaloneCodexDependencyMatches
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-codex"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          , "agent-workflow-core >=0.1 && <0.2"
          ]
  standalonePackageOk <-
    assertNoTextMatches
      "standalone workflow Codex package excludes forbidden package dependencies"
      standaloneForbiddenPackageMatches
  standaloneApprovedDependencyOk <-
    assertNoTextMatches
      "standalone workflow Codex package excludes unapproved package dependencies"
      unapprovedStandaloneCodexDependencyMatches
  importOk <-
    assertNoTextMatches
      "workflow Codex source excludes moifold lifecycle imports"
      forbiddenImportViolations
  sourceOk <-
    assertNoTextMatches
      "workflow Codex source excludes moifold lifecycle ownership text"
      forbiddenSourceMatches
  concreteTypeOk <-
    assertNoTextMatches
      "workflow Codex source excludes concrete watcher state and event tokens"
      forbiddenConcreteTypeMatches
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow Codex package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow Codex package exposes adapter API modules"
      expectedStandaloneModuleMismatches
  standaloneCodexDepsOk <-
    assert
      "standalone workflow Codex package keeps the approved adapter dependency set"
      standaloneDependsOnlyOnCodexDeps
  standaloneMetadataOk <-
    assert
      "standalone workflow Codex package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  pure
    ( standalonePackageOk
        && standaloneApprovedDependencyOk
        && importOk
        && sourceOk
        && concreteTypeOk
        && standaloneInventoryOk
        && standaloneExposedOk
        && standaloneCodexDepsOk
        && standaloneMetadataOk
    )

codexStandaloneExposedModules :: [Text]
codexStandaloneExposedModules =
  [ "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Agent.Codex"
  , "CodexWatcher.Workflow.Agent.Codex.Client"
  , "CodexWatcher.Workflow.Agent.Codex.Interpreter"
  , "CodexWatcher.Workflow.Agent.Codex.Protocol"
  , "CodexWatcher.Workflow.Agent.Codex.Transport"
  , "CodexWatcher.Workflow.Agent.Ids"
  , "CodexWatcher.Workflow.Agent.Types"
  , "CodexWatcher.Workflow.Observation.Agent"
  ]

codexBoundaryForbiddenImportModules :: [Text]
codexBoundaryForbiddenImportModules =
  [ "CodexWatcher.AppServerClient"
  , "CodexWatcher.ActionExecutor"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.Domain."
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.Runtime."
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Workflow.GitHub"
  , "CodexWatcher.Workflow.Moifold."
  , "CodexWatcher.Workflow.Types"
  ]

workflowGithubStandalonePackageKeepsPackageBoundary :: IO Bool
workflowGithubStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-github" </> "agent-workflow-github.cabal")
  githubSourceModules <- sourceModulesUnder ("agent-workflow-github" </> "src")
  importViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-github" </> "src")
      githubForbiddenImportModules
  ownershipViolations <-
    sourceTextNeedleViolationsUnder
      ("agent-workflow-github" </> "src")
      githubForbiddenOwnershipTokens
  let standaloneGithubSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "bytestring"
        , "containers"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "websockets"
        , "moifold,"
        , "moifold:"
        , "agent-workflow-core"
        , "agent-workflow-codex"
        ]
      standaloneGithubDependencyPackages = cabalBuildDependsPackages standaloneGithubSection
      unapprovedStandaloneGithubDependencyMatches =
        filter (`notElem` ["aeson", "base", "text"]) standaloneGithubDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneGithubSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-github exposed modules" (sort githubSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-github approved modules" (sort githubStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnGithubDeps =
        all
          (`elem` standaloneGithubDependencyPackages)
          ["aeson", "base", "text"]
          && null unapprovedStandaloneGithubDependencyMatches
          && not (any (`Text.isInfixOf` standaloneGithubSection) standaloneForbiddenPackageNeedles)
      standaloneDependencyBoundsMatchPolicy =
        all
          (`Text.isInfixOf` standaloneGithubSection)
          [ "aeson >=2.2 && <3"
          , "base >=4.18 && <5"
          , "text >=2.0 && <3"
          ]
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-github"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          ]
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow GitHub package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow GitHub package exposes only adapter modules"
      expectedStandaloneModuleMismatches
  standaloneDependencyOk <-
    assert
      "standalone workflow GitHub package keeps the approved adapter dependency set"
      (standaloneDependsOnlyOnGithubDeps && standaloneDependencyBoundsMatchPolicy)
  standaloneMetadataOk <-
    assert
      "standalone workflow GitHub package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  importsOk <-
    assertNoTextMatches
      "workflow GitHub source has no moifold state-machine, daemon, lifecycle, runtime, or compatibility imports"
      importViolations
  ownershipOk <-
    assertNoTextMatches
      "workflow GitHub source has no moifold lifecycle ownership tokens"
      ownershipViolations
  pure
    ( standaloneInventoryOk
        && standaloneExposedOk
        && standaloneDependencyOk
        && standaloneMetadataOk
        && importsOk
        && ownershipOk
    )

githubStandaloneExposedModules :: [Text]
githubStandaloneExposedModules =
  [ "CodexWatcher.Workflow.GitHub.Command"
  , "CodexWatcher.Workflow.GitHub.Ids"
  , "CodexWatcher.Workflow.GitHub.Remote"
  ]

githubForbiddenImportModules :: [Text]
githubForbiddenImportModules =
  [ "CodexWatcher.AppServer"
  , "CodexWatcher.AppServerClient"
  , "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Cli"
  , "CodexWatcher.Core."
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.Domain"
  , "CodexWatcher.EffectInterpreter"
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.Json"
  , "CodexWatcher.Logging"
  , "CodexWatcher.Observation"
  , "CodexWatcher.Runtime"
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Supervisor"
  , "CodexWatcher.Turn"
  , "CodexWatcher.TurnOutput"
  , "CodexWatcher.WatcherLiveness"
  , "CodexWatcher.WatcherRuntimeStatus"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Daemon"
  , "CodexWatcher.Workflow.EventLog"
  , "CodexWatcher.Workflow.Execution"
  , "CodexWatcher.Workflow.Moifold"
  , "CodexWatcher.Workflow.Observation"
  , "CodexWatcher.Workflow.Permission"
  , "CodexWatcher.Workflow.Transaction"
  , "CodexWatcher.Workflow.Types"
  ]

githubForbiddenOwnershipTokens :: [Text]
githubForbiddenOwnershipTokens =
  [ "WatcherEvent"
  , "SomeWatcherState"
  , "RuntimeCommand"
  , "RuntimeInterpreter"
  , "CommandReport"
  , "IssueConfig"
  , "PrConfig"
  , "ReviewEvidence"
  , "CleanReviewEvidence"
  , "Healthcheck"
  , "EventLogRepair"
  , "runtime-owner"
  , "daemon-state.json"
  , "issue-state.json"
  , "planning-state.json"
  , "watcher-state.json"
  , "block-state.json"
  , "app-server"
  ]

workflowMoifoldCabalLibraryDoesNotReexportAdapters :: IO Bool
workflowMoifoldCabalLibraryDoesNotReexportAdapters = do
  cabalSource <- Text.pack <$> readFile "moifold.cabal"
  appServerCompatibilitySource <- Text.pack <$> readFile ("src" </> "CodexWatcher" </> "AppServerClient.hs")
  let mainLibrarySection = cabalComponentSection "library" cabalSource
      adapterModuleNeedles =
        [ "CodexWatcher.AppServerProtocol"
        , "CodexWatcher.Workflow.Agent"
        , "CodexWatcher.Workflow.Agent.Codex"
        , "CodexWatcher.Workflow.Agent.Codex.Protocol"
        , "CodexWatcher.Workflow.Agent.Ids"
        , "CodexWatcher.Workflow.Agent.Types"
        , "CodexWatcher.Workflow.Observation.Agent"
        , "CodexWatcher.Workflow.GitHub.Ids"
        ]
      noAdapterReexports =
        not ("reexported-modules:" `Text.isInfixOf` mainLibrarySection)
          && not (any (`Text.isInfixOf` mainLibrarySection) adapterModuleNeedles)
      keepsAdapterDependencies =
        all
          (`Text.isInfixOf` mainLibrarySection)
          [ "agent-workflow-codex >=0.1 && <0.2"
          , "agent-workflow-github >=0.1 && <0.2"
          ]
      mainLibraryDoesNotOwnAppServerTransport =
        not ("websockets" `Text.isInfixOf` mainLibrarySection)
          && "import CodexWatcher.Workflow.Agent.Codex.Transport" `Text.isInfixOf` appServerCompatibilitySource
          && "import CodexWatcher.Workflow.Agent.Codex.Client" `Text.isInfixOf` appServerCompatibilitySource
          && not ("Network.WebSockets" `Text.isInfixOf` appServerCompatibilitySource)
          && not ("data AppServerEndpoint" `Text.isInfixOf` appServerCompatibilitySource)
          && not ("newtype AppServerConnection" `Text.isInfixOf` appServerCompatibilitySource)
  assert
    "main moifold library does not reexport workflow adapter modules or own app-server transport"
    (noAdapterReexports && keepsAdapterDependencies && mainLibraryDoesNotOwnAppServerTransport)

workflowGithubCommandFacadeMatchesRuntimeRender :: IO Bool
workflowGithubCommandFacadeMatchesRuntimeRender = do
  let repo = RepoName "soulomoon/mlf2"
      issue = IssueNumber 42
      pr = PrNumber 6
      branch = BranchName "codex/example"
      thread = ReviewThreadId "PRRT_test"
      prConfig = PrConfig repo pr branch
      checks =
        [ (renderRuntimeCommand GhAuthStatus, WorkflowGitHubCommand.ghAuthStatusCommand)
        , (renderRuntimeCommand GhApiUser, WorkflowGitHubCommand.ghApiUserCommand)
        , (renderRuntimeCommand (GhIssueListOpen repo), WorkflowGitHubCommand.ghIssueListOpenCommand repo)
        , (renderRuntimeCommand (GhIssueView repo issue WorkflowGitHubCommand.ghIssueViewStateFields), WorkflowGitHubCommand.ghIssueViewCommand repo issue WorkflowGitHubCommand.ghIssueViewStateFields)
        , (renderRuntimeCommand (GhPrListOpen repo), WorkflowGitHubCommand.ghPrListOpenCommand repo)
        , (renderRuntimeCommand (GhPrListByHead repo branch "all"), WorkflowGitHubCommand.ghPrListByHeadCommand repo branch "all")
        , (renderRuntimeCommand (GhPrView repo pr ["state", "url"]), WorkflowGitHubCommand.ghPrViewCommand repo pr ["state", "url"])
        , (renderRuntimeCommand (GhPrView repo pr WorkflowGitHubCommand.ghPrViewRemoteFields), WorkflowGitHubCommand.ghPrViewCommand repo pr WorkflowGitHubCommand.ghPrViewRemoteFields)
        , (renderRuntimeCommand (GhPrView repo pr WorkflowGitHubCommand.ghPrViewMergeMetadataFields), WorkflowGitHubCommand.ghPrViewCommand repo pr WorkflowGitHubCommand.ghPrViewMergeMetadataFields)
        , (renderRuntimeCommand (GhPrChecks repo pr), WorkflowGitHubCommand.ghPrChecksCommand repo pr)
        , (renderRuntimeCommand (GhReviewThreads prConfig), WorkflowGitHubCommand.ghReviewThreadsCommand repo pr)
        , (renderRuntimeCommand (GhResolveReviewThread thread), WorkflowGitHubCommand.ghResolveReviewThreadCommand thread)
        , (renderRuntimeCommand (GhReplyReviewThread thread "still applies"), WorkflowGitHubCommand.ghReplyReviewThreadCommand thread "still applies")
        , (renderRuntimeCommand (GhPrMerge repo pr "squash"), WorkflowGitHubCommand.ghPrMergeCommand repo pr "squash")
        , (renderRuntimeCommand (GitBranchCurrent "/tmp/work"), WorkflowGitHubCommand.gitBranchCurrentCommand "/tmp/work")
        , (renderRuntimeCommand (GitRevParseHead "/tmp/work"), WorkflowGitHubCommand.gitRevParseHeadCommand "/tmp/work")
        , (renderRuntimeCommand (GitStatusPorcelain "/tmp/work"), WorkflowGitHubCommand.gitStatusPorcelainCommand "/tmp/work")
        , (renderRuntimeCommand (GitLsRemoteBranch "/tmp/work" branch), WorkflowGitHubCommand.gitLsRemoteBranchCommand "/tmp/work" branch)
        , (renderRuntimeCommand (GitPushDryRun "/tmp/work" branch), WorkflowGitHubCommand.gitPushDryRunCommand "/tmp/work" branch)
        , (renderRuntimeCommand (GitPush "/tmp/work" branch), WorkflowGitHubCommand.gitPushCommand "/tmp/work" branch)
        ]
  assert
    "workflow GitHub command facade matches runtime render"
    (all commandSpecMatches checks)

commandSpecMatches :: (RuntimeCommandSpec, WorkflowGitHubCommand.GitHubCommandSpec) -> Bool
commandSpecMatches (runtimeSpec, githubSpec) =
  runtimeSpec.command == githubSpec.githubCommand
    && runtimeSpec.args == githubSpec.githubCommandArgs
    && runtimeSpec.cwd == githubSpec.githubCommandCwd
    && runtimeSpec.stdin == githubSpec.githubCommandStdin
