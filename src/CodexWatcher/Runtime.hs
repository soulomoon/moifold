{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime
  ( CommandReport (..)
  , RuntimeCommand (..)
  , RuntimeCommandSpec (..)
  , RuntimeInterpreter (..)
  , appendJsonLine
  , commandSummary
  , commandText
  , ioRuntimeInterpreter
  , readJsonValue
  , redact
  , renderRuntimeCommand
  , runProcessSpec
  , runRuntimeCommand
  , skippedCommand
  , writeJsonValue
  ) where

import CodexWatcher.Types
  ( BranchName (..)
  , PrNumber (..)
  , RepoName (..)
  )
import Control.Exception (IOException, try)
import Data.Aeson
  ( ToJSON
  , Value
  , eitherDecodeStrict'
  , encode
  )
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import System.Process qualified as Process

data RuntimeCommand
  = CommandVersion String
  | GhAuthStatus
  | GhApiUser
  | GhPrView RepoName PrNumber [Text]
  | GitBranchCurrent FilePath
  | GitRevParseHead FilePath
  | GitStatusPorcelain FilePath
  | GitLsRemoteBranch FilePath BranchName
  | GitPushDryRun FilePath BranchName
  | KillZero Text
  | RawCommand String [String] (Maybe FilePath)
  deriving stock (Eq, Show, Generic)

data RuntimeCommandSpec = RuntimeCommandSpec
  { command :: String
  , args :: [String]
  , cwd :: Maybe FilePath
  , stdin :: Text
  }
  deriving stock (Eq, Show, Generic)

data CommandReport = CommandReport
  { ok :: Bool
  , status :: Maybe Int
  , stdout :: Text
  , stderr :: Text
  , errorMessage :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data RuntimeInterpreter m = RuntimeInterpreter
  { runtimeRunCommand :: RuntimeCommand -> m CommandReport
  , runtimeReadJsonValue :: FilePath -> m (Either Text Value)
  , runtimeWriteJsonValue :: FilePath -> Value -> m ()
  , runtimeAppendJsonLine :: FilePath -> Value -> m ()
  }

ioRuntimeInterpreter :: RuntimeInterpreter IO
ioRuntimeInterpreter =
  RuntimeInterpreter
    { runtimeRunCommand = runRuntimeCommand
    , runtimeReadJsonValue = readJsonValue
    , runtimeWriteJsonValue = writeJsonValue
    , runtimeAppendJsonLine = appendJsonLine
    }

renderRuntimeCommand :: RuntimeCommand -> RuntimeCommandSpec
renderRuntimeCommand (CommandVersion command') =
  RuntimeCommandSpec command' ["--version"] Nothing ""
renderRuntimeCommand GhAuthStatus =
  RuntimeCommandSpec "gh" ["auth", "status"] Nothing ""
renderRuntimeCommand GhApiUser =
  RuntimeCommandSpec "gh" ["api", "user"] Nothing ""
renderRuntimeCommand (GhPrView repo prNumber fields) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "view"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--json"
    , Text.unpack (Text.intercalate "," fields)
    ]
    Nothing
    ""
renderRuntimeCommand (GitBranchCurrent workdir) =
  RuntimeCommandSpec "git" ["branch", "--show-current"] (Just workdir) ""
renderRuntimeCommand (GitRevParseHead workdir) =
  RuntimeCommandSpec "git" ["rev-parse", "HEAD"] (Just workdir) ""
renderRuntimeCommand (GitStatusPorcelain workdir) =
  RuntimeCommandSpec "git" ["status", "--porcelain"] (Just workdir) ""
renderRuntimeCommand (GitLsRemoteBranch workdir branch) =
  RuntimeCommandSpec "git" ["ls-remote", "origin", "refs/heads/" <> Text.unpack (unBranchName branch)] (Just workdir) ""
renderRuntimeCommand (GitPushDryRun workdir branch) =
  RuntimeCommandSpec "git" ["push", "--dry-run", "origin", Text.unpack (unBranchName branch)] (Just workdir) ""
renderRuntimeCommand (KillZero pid) =
  RuntimeCommandSpec "kill" ["-0", Text.unpack pid] Nothing ""
renderRuntimeCommand (RawCommand command' args' cwd') =
  RuntimeCommandSpec command' args' cwd' ""

runRuntimeCommand :: RuntimeCommand -> IO CommandReport
runRuntimeCommand = runProcessSpec . renderRuntimeCommand

commandSummary :: String -> [String] -> Maybe FilePath -> IO CommandReport
commandSummary command' args' cwd' =
  runRuntimeCommand (RawCommand command' args' cwd')

runProcessSpec :: RuntimeCommandSpec -> IO CommandReport
runProcessSpec spec = do
  result <-
    try
      (Process.readCreateProcessWithExitCode (Process.proc spec.command spec.args) {Process.cwd = spec.cwd} (Text.unpack spec.stdin))
      :: IO (Either IOException (ExitCode, String, String))
  pure case result of
    Left error' ->
      CommandReport
        { ok = False
        , status = Nothing
        , stdout = ""
        , stderr = ""
        , errorMessage = Just (Text.pack (show error'))
        }
    Right (exitCode, stdout', stderr') ->
      CommandReport
        { ok = exitCode == ExitSuccess
        , status = exitStatus exitCode
        , stdout = redact (Text.strip (Text.pack stdout'))
        , stderr = redact (Text.strip (Text.pack stderr'))
        , errorMessage = Nothing
        }

readJsonValue :: FilePath -> IO (Either Text Value)
readJsonValue path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case bytesResult of
    Left error' -> Left (Text.pack (show error'))
    Right bytes -> either (Left . Text.pack) Right (eitherDecodeStrict' bytes)

writeJsonValue :: FilePath -> Value -> IO ()
writeJsonValue path value =
  LazyByteString.writeFile path (encode value)

appendJsonLine :: FilePath -> Value -> IO ()
appendJsonLine path value =
  LazyByteString.appendFile path (encode value <> "\n")

skippedCommand :: Text -> CommandReport
skippedCommand reason' =
  CommandReport {ok = False, status = Nothing, stdout = "", stderr = "", errorMessage = Just reason'}

exitStatus :: ExitCode -> Maybe Int
exitStatus ExitSuccess = Just 0
exitStatus (ExitFailure code) = Just code

commandText :: CommandReport -> Text
commandText report =
  Text.intercalate " " (filter (not . Text.null) [report.stderr, report.stdout, maybe "" id report.errorMessage])

redact :: Text -> Text
redact =
  Text.unwords . fmap redactWord . Text.words
 where
  redactWord word
    | any (`Text.isPrefixOf` word) ["ghp_", "github_pat_", "gho_", "ghu_", "ghs_", "ghr_"] = "<redacted-token>"
    | otherwise = word
