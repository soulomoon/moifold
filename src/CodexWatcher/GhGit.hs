{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.GhGit
  ( GhIssue (..)
  , GhPullRequest (..)
  , GhPullRequestCheck (..)
  , GhPullRequestCreateResult (..)
  , GitWorktreeStatus (..)
  , RemoteIssue (..)
  , RemotePullRequest (..)
  , ReviewComment (..)
  , ReviewThread (..)
  , ReviewThreadsReport (..)
  , parseGhIssueList
  , parseGhIssueView
  , parseGhPrList
  , parseGhPrChecks
  , parseGhPrCreateResult
  , parseGhPrView
  , parseGhReviewThreads
  , parseGitBranch
  , parseGitSha
  , parseLsRemoteBranch
  , runGitWorktreeStatus
  , runGhIssueListOpen
  , runGhIssueView
  , runGhPrListOpen
  , runGhPrChecks
  , runGhPrView
  , runGhReviewThreads
  ) where

import CodexWatcher.Runtime
import CodexWatcher.Runtime.Json (decodeJsonText, parseCommandJson)
import CodexWatcher.JsonPath (decodeAtPath, decodeValue, valueText)
import CodexWatcher.Types
import Data.Aeson
  ( FromJSON (..)
  , Object
  , Value (..)
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types qualified as AesonTypes
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data GhIssue = GhIssue
  { ghIssueNumber :: IssueNumber
  , ghIssueTitle :: Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON GhIssue where
  parseJSON = withObject "GhIssue" \objectValue ->
    GhIssue
      <$> (IssueNumber <$> objectValue .: "number")
      <*> objectValue .: "title"

data RemoteIssue = RemoteIssue
  { remoteIssueState :: Text
  , remoteIssueClosed :: Bool
  , remoteIssueUrl :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON RemoteIssue where
  parseJSON = withObject "RemoteIssue" \objectValue -> do
    state <- objectValue .: "state"
    closed <- objectValue .:? "closed" .!= (state == "CLOSED")
    RemoteIssue state closed <$> objectValue .:? "url"

data GhPullRequest = GhPullRequest
  { ghPullRequestNumber :: PrNumber
  , ghPullRequestTitle :: Text
  , ghPullRequestHeadRefName :: BranchName
  , ghPullRequestHeadRefOid :: Maybe CommitSha
  , ghPullRequestLinkedIssueNumbers :: [IssueNumber]
  , ghPullRequestBody :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON GhPullRequest where
  parseJSON = withObject "GhPullRequest" \objectValue ->
    GhPullRequest
      <$> (PrNumber <$> objectValue .: "number")
      <*> objectValue .: "title"
      <*> (BranchName <$> objectValue .: "headRefName")
      <*> (fmap CommitSha <$> objectValue .:? "headRefOid")
      <*> parseClosingIssueReferences objectValue
      <*> objectValue .:? "body"

newtype ClosingIssueReference = ClosingIssueReference IssueNumber

instance FromJSON ClosingIssueReference where
  parseJSON = withObject "ClosingIssueReference" \objectValue ->
    ClosingIssueReference . IssueNumber <$> objectValue .: "number"

data GhPullRequestCreateResult
  = GhPullRequestCreated PrNumber
  | GhPullRequestReused PrNumber
  deriving stock (Eq, Show, Generic)

instance FromJSON GhPullRequestCreateResult where
  parseJSON = withObject "GhPullRequestCreateResult" \objectValue -> do
    status <- objectValue .: "status"
    prNumber' <- PrNumber <$> objectValue .: "prNumber"
    case normalizeStatus status of
      "created" -> pure (GhPullRequestCreated prNumber')
      "reused" -> pure (GhPullRequestReused prNumber')
      other -> fail ("unsupported PR create status: " <> Text.unpack other)

data GhPullRequestCheck = GhPullRequestCheck
  { ghPullRequestCheckName :: Text
  , ghPullRequestCheckState :: Text
  , ghPullRequestCheckBucket :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON GhPullRequestCheck where
  parseJSON = withObject "GhPullRequestCheck" \objectValue ->
    GhPullRequestCheck
      <$> objectValue .: "name"
      <*> objectValue .: "state"
      <*> objectValue .:? "bucket"

data RemotePullRequest = RemotePullRequest
  { remotePullRequestState :: Text
  , remotePullRequestUrl :: Maybe Text
  , remotePullRequestHeadRefOid :: Maybe CommitSha
  , remotePullRequestMergeCommit :: Maybe CommitSha
  , remotePullRequestMergedAt :: Maybe Text
  , remotePullRequestMergeStateStatus :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON RemotePullRequest where
  parseJSON = withObject "RemotePullRequest" \objectValue ->
    RemotePullRequest
      <$> objectValue .: "state"
      <*> objectValue .:? "url"
      <*> (fmap CommitSha <$> objectValue .:? "headRefOid")
      <*> parseMergeCommit objectValue
      <*> objectValue .:? "mergedAt"
      <*> objectValue .:? "mergeStateStatus"

data ReviewComment = ReviewComment
  { reviewCommentId :: Text
  , reviewCommentBody :: Text
  , reviewCommentPath :: Maybe Text
  , reviewCommentLine :: Maybe Int
  , reviewCommentAuthorLogin :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON ReviewComment where
  parseJSON = withObject "ReviewComment" \objectValue ->
    ReviewComment
      <$> objectValue .: "id"
      <*> objectValue .:? "body" .!= ""
      <*> objectValue .:? "path"
      <*> objectValue .:? "line"
      <*> parseAuthorLogin objectValue

data ReviewThread = ReviewThread
  { reviewThreadId :: ReviewThreadId
  , reviewThreadResolved :: Bool
  , reviewThreadOutdated :: Bool
  , reviewThreadPath :: Maybe Text
  , reviewThreadLine :: Maybe Int
  , reviewThreadStartLine :: Maybe Int
  , reviewThreadComments :: [ReviewComment]
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON ReviewThread where
  parseJSON = withObject "ReviewThread" \objectValue ->
    ReviewThread
      <$> (ReviewThreadId <$> objectValue .: "id")
      <*> objectValue .: "isResolved"
      <*> objectValue .:? "isOutdated" .!= False
      <*> objectValue .:? "path"
      <*> objectValue .:? "line"
      <*> objectValue .:? "startLine"
      <*> parseComments objectValue

data ReviewThreadsReport = ReviewThreadsReport
  { reviewThreads :: [ReviewThread]
  , unresolvedReviewThreads :: [ReviewThread]
  }
  deriving stock (Eq, Show, Generic)

data GitWorktreeStatus = GitWorktreeStatus
  { gitCurrentBranch :: Maybe BranchName
  , gitHeadSha :: Maybe CommitSha
  , gitDirtyStatus :: Text
  , gitIsDirty :: Bool
  , gitRemoteHeadSha :: Maybe CommitSha
  }
  deriving stock (Eq, Show, Generic)

parseGhIssueList :: Text -> Either Text [GhIssue]
parseGhIssueList =
  decodeJsonText "gh issue list"

parseGhIssueView :: Text -> Either Text RemoteIssue
parseGhIssueView =
  decodeJsonText "gh issue view"

parseGhPrList :: Text -> Either Text [GhPullRequest]
parseGhPrList =
  decodeJsonText "gh pr list"

parseClosingIssueReferences :: Object -> AesonTypes.Parser [IssueNumber]
parseClosingIssueReferences objectValue = do
  references <- objectValue .:? "closingIssuesReferences" .!= ([] :: [ClosingIssueReference])
  pure [issueNumber | ClosingIssueReference issueNumber <- references]

parseGhPrCreateResult :: Text -> Either Text GhPullRequestCreateResult
parseGhPrCreateResult =
  decodeJsonText "gh pr create"

parseGhPrChecks :: Text -> Either Text [GhPullRequestCheck]
parseGhPrChecks text =
  case decodeJsonText "gh pr checks" text of
    Right checks -> Right checks
    Left _ -> parseGhPrChecksTable text

parseGhPrChecksTable :: Text -> Either Text [GhPullRequestCheck]
parseGhPrChecksTable text
  | stripped == "" = Right []
  | "no required checks reported" `Text.isInfixOf` Text.toLower stripped = Right []
  | "no checks reported" `Text.isInfixOf` Text.toLower stripped = Right []
  | otherwise = traverse parseGhPrCheckLine (filter (not . Text.null) (Text.strip <$> Text.lines text))
 where
  stripped = Text.strip text

parseGhPrCheckLine :: Text -> Either Text GhPullRequestCheck
parseGhPrCheckLine line =
  case Text.splitOn "\t" line of
    name : state : _ ->
      Right (GhPullRequestCheck (stripCheckMarker name) (Text.strip state) Nothing)
    _ ->
      Left ("gh pr checks output line is not tab-separated: " <> line)

stripCheckMarker :: Text -> Text
stripCheckMarker text =
  Text.strip
    ( Text.dropWhile
        (\char -> char == 'X' || char == '-' || char == ' ')
        text
    )

parseGhPrView :: Text -> Either Text RemotePullRequest
parseGhPrView =
  decodeJsonText "gh pr view"

parseGhReviewThreads :: Text -> Either Text ReviewThreadsReport
parseGhReviewThreads text = do
  value <- decodeJsonText "gh review threads" text
  threads <- reviewThreadNodes value
  pure
    ReviewThreadsReport
      { reviewThreads = threads
      , unresolvedReviewThreads = filter (\thread -> not thread.reviewThreadResolved) threads
      }

parseGitBranch :: Text -> Maybe BranchName
parseGitBranch text =
  BranchName <$> nonEmptyStripped text

parseGitSha :: Text -> Maybe CommitSha
parseGitSha text =
  CommitSha <$> nonEmptyStripped text

parseLsRemoteBranch :: Text -> Maybe CommitSha
parseLsRemoteBranch text =
  case Text.words text of
    sha : _ -> Just (CommitSha sha)
    [] -> Nothing

runGhIssueListOpen :: Monad m => RuntimeInterpreter m -> RepoName -> m (Either Text [GhIssue])
runGhIssueListOpen interpreter repo =
  parseCommandJson parseGhIssueList <$> interpreter.runtimeRunCommand (GhIssueListOpen repo)

runGhIssueView :: Monad m => RuntimeInterpreter m -> RepoName -> IssueNumber -> m (Either Text RemoteIssue)
runGhIssueView interpreter repo issueNumber =
  parseCommandJson parseGhIssueView
    <$> interpreter.runtimeRunCommand (GhIssueView repo issueNumber ["state", "closed", "url"])

runGhPrListOpen :: Monad m => RuntimeInterpreter m -> RepoName -> m (Either Text [GhPullRequest])
runGhPrListOpen interpreter repo =
  parseCommandJson parseGhPrList <$> interpreter.runtimeRunCommand (GhPrListOpen repo)

runGhPrChecks :: Monad m => RuntimeInterpreter m -> RepoName -> PrNumber -> m (Either Text [GhPullRequestCheck])
runGhPrChecks interpreter repo prNumber = do
  report <- interpreter.runtimeRunCommand (GhPrChecks repo prNumber)
  case parseGhPrChecks report.stdout of
    Right checks -> pure (Right checks)
    Left parseError
      | report.ok -> pure (Left parseError)
      | otherwise -> pure (Left (commandText report))

runGhPrView :: Monad m => RuntimeInterpreter m -> RepoName -> PrNumber -> m (Either Text RemotePullRequest)
runGhPrView interpreter repo prNumber =
  parseCommandJson parseGhPrView
    <$> interpreter.runtimeRunCommand (GhPrView repo prNumber ["state", "mergedAt", "mergeCommit", "url", "headRefOid", "mergeStateStatus"])

runGhReviewThreads :: Monad m => RuntimeInterpreter m -> PrConfig -> m (Either Text ReviewThreadsReport)
runGhReviewThreads interpreter prConfig =
  parseCommandJson parseGhReviewThreads <$> interpreter.runtimeRunCommand (GhReviewThreads prConfig)

runGitWorktreeStatus :: Monad m => RuntimeInterpreter m -> FilePath -> BranchName -> m GitWorktreeStatus
runGitWorktreeStatus interpreter workdir branch = do
  branchReport <- interpreter.runtimeRunCommand (GitBranchCurrent workdir)
  headReport <- interpreter.runtimeRunCommand (GitRevParseHead workdir)
  dirtyReport <- interpreter.runtimeRunCommand (GitStatusPorcelain workdir)
  remoteReport <- interpreter.runtimeRunCommand (GitLsRemoteBranch workdir branch)
  let dirtyStatus = dirtyReport.stdout
  pure
    GitWorktreeStatus
      { gitCurrentBranch = parseGitBranch branchReport.stdout
      , gitHeadSha = parseGitSha headReport.stdout
      , gitDirtyStatus = dirtyStatus
      , gitIsDirty = not (Text.null (Text.strip dirtyStatus))
      , gitRemoteHeadSha = parseLsRemoteBranch remoteReport.stdout
      }

reviewThreadNodes :: Value -> Either Text [ReviewThread]
reviewThreadNodes value =
  decodeAtPath ["data", "repository", "pullRequest", "reviewThreads", "nodes"] value

parseMergeCommit :: Object -> AesonTypes.Parser (Maybe CommitSha)
parseMergeCommit objectValue = do
  maybeMergeValue <- objectValue .:? "mergeCommit"
  pure case maybeMergeValue of
    Just (Object mergeObject) ->
      CommitSha <$> (valueText =<< KeyMap.lookup "oid" mergeObject)
    Just (String sha) ->
      Just (CommitSha sha)
    _ ->
      Nothing

parseAuthorLogin :: Object -> AesonTypes.Parser (Maybe Text)
parseAuthorLogin objectValue = do
  maybeAuthorValue <- objectValue .:? "author"
  pure case maybeAuthorValue of
    Just (Object authorObject) -> valueText =<< KeyMap.lookup "login" authorObject
    _ -> Nothing

parseComments :: Object -> AesonTypes.Parser [ReviewComment]
parseComments objectValue = do
  maybeCommentsValue <- objectValue .:? "comments"
  pure case maybeCommentsValue of
    Just (Object commentsObject) ->
      maybe [] decodeComments (KeyMap.lookup "nodes" commentsObject)
    _ -> []

decodeComments :: Value -> [ReviewComment]
decodeComments value =
  either (const []) id (decodeValue value)

nonEmptyStripped :: Text -> Maybe Text
nonEmptyStripped text
  | Text.null stripped = Nothing
  | otherwise = Just stripped
 where
  stripped = Text.strip text

normalizeStatus :: Text -> Text
normalizeStatus =
  Text.toLower . Text.strip
