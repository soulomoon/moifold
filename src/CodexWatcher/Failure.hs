{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Failure
  ( FailureClass (..)
  , FailureClassification (..)
  , classifyAppServerFailure
  , classifyExternalFailureText
  , failureClassText
  , failureIsRetryable
  , transientFailureText
  ) where

import CodexWatcher.AppServerClient (AppServerClientFailure (..), JsonRpcError (..))
import CodexWatcher.Workflow.Failure
  ( FailureClass (..)
  , FailureClassification (..)
  , classifyExternalFailureText
  , failureClassText
  , failureIsRetryable
  , transientFailureText
  )
import Data.Text qualified as Text

classifyAppServerFailure :: AppServerClientFailure -> FailureClassification
classifyAppServerFailure = \case
  AppServerTransportFailure reason ->
    FailureClassification TransientFailure ("app-server transport failed: " <> reason)
  AppServerResponseTimedOut requestId ->
    FailureClassification TransientFailure ("app-server response timed out for request id " <> Text.pack (show requestId))
  AppServerDecodeFailure reason ->
    FailureClassification FatalFailure ("app-server JSON decode failed: " <> reason)
  AppServerResponseIdMismatch expected actual ->
    FailureClassification FatalFailure ("app-server response id mismatch: expected " <> Text.pack (show expected) <> ", got " <> Text.pack (show actual))
  AppServerJsonRpcFailure _responseId errorValue
    | transientFailureText errorValue.jsonRpcErrorMessage ->
        FailureClassification TransientFailure errorValue.jsonRpcErrorMessage
    | otherwise ->
        FailureClassification FatalFailure errorValue.jsonRpcErrorMessage
