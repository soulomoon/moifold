{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Codec
  ( WorkflowCodecContract (..)
  , WorkflowCodecRoundTripFailure (..)
  , WorkflowDecodeError (..)
  , WorkflowEventTypeLabel (..)
  , WorkflowMetadataLabel (..)
  , WorkflowSchemaVersion (..)
  , formatWorkflowDecodeError
  , validateWorkflowCodecRoundTrip
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

newtype WorkflowEventTypeLabel = WorkflowEventTypeLabel
  { unWorkflowEventTypeLabel :: Text
  }
  deriving stock (Eq, Ord, Show)

newtype WorkflowSchemaVersion = WorkflowSchemaVersion
  { unWorkflowSchemaVersion :: Int
  }
  deriving stock (Eq, Ord, Show)

newtype WorkflowMetadataLabel = WorkflowMetadataLabel
  { unWorkflowMetadataLabel :: Text
  }
  deriving stock (Eq, Ord, Show)

data WorkflowDecodeError = WorkflowDecodeError
  { workflowDecodeErrorTypeLabel :: Maybe WorkflowEventTypeLabel
  , workflowDecodeErrorSchemaVersion :: Maybe WorkflowSchemaVersion
  , workflowDecodeErrorReason :: Text
  }
  deriving stock (Eq, Show)

data WorkflowCodecContract event encoded = WorkflowCodecContract
  { workflowCodecEventTypeLabel :: event -> WorkflowEventTypeLabel
  , workflowCodecSchemaVersion :: event -> WorkflowSchemaVersion
  , workflowCodecMetadataLabels :: [WorkflowMetadataLabel]
  , workflowCodecEncode :: event -> encoded
  , workflowCodecDecode :: encoded -> Either WorkflowDecodeError event
  }

data WorkflowCodecRoundTripFailure event encoded = WorkflowCodecRoundTripFailure
  { workflowRoundTripOriginalEvent :: event
  , workflowRoundTripEncodedValue :: encoded
  , workflowRoundTripFailure :: Either WorkflowDecodeError event
  }
  deriving stock (Eq, Show)

validateWorkflowCodecRoundTrip
  :: Eq event
  => WorkflowCodecContract event encoded
  -> event
  -> Either (WorkflowCodecRoundTripFailure event encoded) ()
validateWorkflowCodecRoundTrip contract event =
  let encoded = workflowCodecEncode contract event
   in case workflowCodecDecode contract encoded of
        Right decoded
          | decoded == event -> Right ()
          | otherwise ->
              Left
                WorkflowCodecRoundTripFailure
                  { workflowRoundTripOriginalEvent = event
                  , workflowRoundTripEncodedValue = encoded
                  , workflowRoundTripFailure = Right decoded
                  }
        Left errorValue ->
          Left
            WorkflowCodecRoundTripFailure
              { workflowRoundTripOriginalEvent = event
              , workflowRoundTripEncodedValue = encoded
              , workflowRoundTripFailure = Left errorValue
              }

formatWorkflowDecodeError :: WorkflowDecodeError -> Text
formatWorkflowDecodeError errorValue =
  Text.intercalate
    ": "
    [ maybe "<unknown-event>" unWorkflowEventTypeLabel errorValue.workflowDecodeErrorTypeLabel
    , maybe "schema <default>" (("schema " <>) . Text.pack . show . unWorkflowSchemaVersion) errorValue.workflowDecodeErrorSchemaVersion
    , errorValue.workflowDecodeErrorReason
    ]
