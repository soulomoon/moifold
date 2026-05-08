{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Small reusable failure classification helpers for transient failures,
-- fatal failures, policy violations, and external state mismatches. Concrete
-- workflows decide how classifications affect lifecycle state.
module CodexWatcher.Workflow.Failure
  ( FailureClass (..)
  , FailureClassification (..)
  , classifyExternalFailureText
  , failureClassText
  , failureIsRetryable
  , transientFailureText
  ) where

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

classifyExternalFailureText :: Text -> FailureClassification
classifyExternalFailureText reason
  | transientFailureText reason =
      FailureClassification TransientFailure reason
  | policyViolationText reason =
      FailureClassification PolicyViolation reason
  | externalStateMismatchText reason =
      FailureClassification ExternalStateMismatch reason
  | otherwise =
      -- Most CLI/API read failures are safe to retry. Callers that already
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
    , "network is unreachable"
    , "failed to connect"
    , "could not resolve host"
    , "timeout"
    , "timed out"
    , "i/o timeout"
    , "socket"
    , "tls"
    , "gnutls"
    , "non-properly terminated"
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
