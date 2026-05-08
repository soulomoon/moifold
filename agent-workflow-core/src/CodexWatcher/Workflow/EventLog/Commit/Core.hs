-- | Generic event commit boundary for encoding one event and appending it
-- through a caller-owned committer. Concrete append targets, locking, backups,
-- and event-log file names remain workflow-owned.
module CodexWatcher.Workflow.EventLog.Commit.Core
  ( WorkflowEventCommitter (..)
  , appendEncodedWorkflowEvent
  , commitWorkflowEvent
  , workflowEncodedEventCommitter
  ) where

newtype WorkflowEventCommitter m event failure = WorkflowEventCommitter
  { runWorkflowEventCommitter :: event -> m (Either failure ())
  }

commitWorkflowEvent :: WorkflowEventCommitter m event failure -> event -> m (Either failure ())
commitWorkflowEvent =
  runWorkflowEventCommitter

appendEncodedWorkflowEvent
  :: (event -> encoded)
  -> (encoded -> m ())
  -> event
  -> m ()
appendEncodedWorkflowEvent encodeEvent appendEncoded event =
  appendEncoded (encodeEvent event)

workflowEncodedEventCommitter
  :: Monad m
  => (event -> m encoded)
  -> (encoded -> m ())
  -> WorkflowEventCommitter m event failure
workflowEncodedEventCommitter encodeEvent appendEncoded =
  WorkflowEventCommitter
    ( \event -> do
        encoded <- encodeEvent event
        appendEncoded encoded
        pure (Right ())
    )
