{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Process
  ( commandSummary
  , redact
  , runProcessSpec
  , runRuntimeCommand
  , skippedCommand
  ) where

import CodexWatcher.Runtime.Command.Render (renderRuntimeCommand)
import CodexWatcher.Runtime.Command.Types
import Control.Exception (IOException, try)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import System.Exit (ExitCode (..))
import System.Process.Typed qualified as Process.Typed

runRuntimeCommand :: RuntimeCommand -> IO CommandReport
runRuntimeCommand = runProcessSpec . renderRuntimeCommand

commandSummary :: String -> [String] -> Maybe FilePath -> IO CommandReport
commandSummary command' args' cwd' =
  runRuntimeCommand (RawCommand command' args' cwd')

runProcessSpec :: RuntimeCommandSpec -> IO CommandReport
runProcessSpec spec = do
  result <-
    try (Process.Typed.readProcess (processConfigFromSpec spec))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
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
        , stdout = redact (Text.strip (Text.Encoding.decodeUtf8 (LazyByteString.toStrict stdout')))
        , stderr = redact (Text.strip (Text.Encoding.decodeUtf8 (LazyByteString.toStrict stderr')))
        , errorMessage = Nothing
        }

processConfigFromSpec :: RuntimeCommandSpec -> Process.Typed.ProcessConfig () () ()
processConfigFromSpec spec =
  setCwd spec.cwd $
    Process.Typed.setStdin (Process.Typed.byteStringInput (LazyByteString.fromStrict (Text.Encoding.encodeUtf8 spec.stdin))) $
      Process.Typed.proc spec.command spec.args
 where
  setCwd Nothing = id
  setCwd (Just cwd') = Process.Typed.setWorkingDir cwd'

skippedCommand :: Text -> CommandReport
skippedCommand reason' =
  CommandReport {ok = False, status = Nothing, stdout = "", stderr = "", errorMessage = Just reason'}

exitStatus :: ExitCode -> Maybe Int
exitStatus ExitSuccess = Just 0
exitStatus (ExitFailure code) = Just code

redact :: Text -> Text
redact =
  Text.unwords . fmap redactWord . Text.words
 where
  redactWord word
    | any (`Text.isPrefixOf` word) ["ghp_", "github_pat_", "gho_", "ghu_", "ghs_", "ghr_"] = "<redacted-token>"
    | otherwise = word
