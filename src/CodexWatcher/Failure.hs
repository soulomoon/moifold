{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
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
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data FailureClass
  = TransientFailure
  | FatalFailure
  | PolicyViolation
  | ExternalStateMismatch
  deriving stock (Eq, Show, Generic)

data FailureClassification = FailureClassification
  { failureClass :: FailureClass
  , failureReason :: Text
  }
  deriving stock (Eq, Show, Generic)

failureIsRetryable :: FailureClassification -> Bool
failureIsRetryable classification =
  classification.failureClass == TransientFailure

failureClassText :: FailureClass -> Text
failureClassText = \case
  TransientFailure -> "transient"
  FatalFailure -> "fatal"
  PolicyViolation -> "policy_violation"
  ExternalStateMismatch -> "external_state_mismatch"

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

classifyExternalFailureText :: Text -> FailureClassification
classifyExternalFailureText reason
  | transientFailureText reason =
      FailureClassification TransientFailure reason
  | policyViolationText reason =
      FailureClassification PolicyViolation reason
  | externalStateMismatchText reason =
      FailureClassification ExternalStateMismatch reason
  | otherwise =
      -- Most GitHub/CLI read failures are safe to retry. Callers that already
      -- proved a domain invariant violation should construct a stricter class.
      FailureClassification TransientFailure reason

transientFailureText :: Text -> Bool
transientFailureText reason =
  any (`Text.isInfixOf` normalized) transientNeedles
 where
  normalized = Text.toLower (Text.strip reason)
  transientNeedles =
    [ "eof"
    , "unexpected end of json input"
    , "connection reset"
    , "connection refused"
    , "connection closed"
    , "temporarily unavailable"
    , "timeout"
    , "timed out"
    , "i/o timeout"
    , "socket"
    , "tls"
    , "rate limit"
    , "secondary rate limit"
    , "server error"
    , "502"
    , "503"
    , "504"
    , "500 internal"
    ]

policyViolationText :: Text -> Bool
policyViolationText reason =
  any (`Text.isInfixOf` normalized) policyNeedles
 where
  normalized = Text.toLower (Text.strip reason)
  policyNeedles =
    [ "permission denied"
    , "forbidden"
    , "insufficient permission"
    , "requires authentication"
    , "not authorized"
    ]

externalStateMismatchText :: Text -> Bool
externalStateMismatchText reason =
  any (`Text.isInfixOf` normalized) mismatchNeedles
 where
  normalized = Text.toLower (Text.strip reason)
  mismatchNeedles =
    [ "outside configured scope"
    , "already active"
    , "already terminal"
    , "already closed"
    , "not linked to issue"
    , "pr mismatch"
    , "head changed"
    ]
