{-# LANGUAGE OverloadedStrings #-}

module TestSupport.SourceScan
  ( assertNoTextMatches
  , cabalBuildDependsPackages
  , cabalComponentSection
  , cabalExposedModules
  , cabalFieldEntries
  , inventoryMismatches
  , sourceIdentifierTokens
  , sourceImportViolationsIn
  , sourceImportViolationsUnder
  , sourceModulesUnder
  , sourceTextNeedleViolationsIn
  , sourceTextNeedleViolationsUnder
  , sourceTextUnder
  , textNeedlesInOrder
  ) where

import Control.Monad (when)
import Data.Char (isAlphaNum)
import Data.List ((\\))
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (dropExtension, makeRelative, splitDirectories, (</>))

cabalComponentSection :: Text -> Text -> Text
cabalComponentSection componentName cabalSource =
  case dropWhile (/= componentName) (Text.lines cabalSource) of
    [] -> ""
    _component : rest ->
      Text.unlines (takeWhile (not . isTopLevelComponent) rest)
 where
  isTopLevelComponent line =
    not (Text.null line)
      && not (" " `Text.isPrefixOf` line)
      && any
        (`Text.isPrefixOf` line)
        [ "common "
        , "library"
        , "executable "
        , "test-suite "
        , "benchmark "
        ]

cabalFieldLines :: Text -> Text -> [Text]
cabalFieldLines fieldName cabalSource =
  case dropWhile (not . isNamedField) (Text.lines cabalSource) of
    [] -> []
    fieldLine : rest ->
      let fieldIndent = Text.length (Text.takeWhile (== ' ') fieldLine)
          fieldValue =
            Text.strip
              . Text.drop 1
              . Text.dropWhile (/= ':')
              $ fieldLine
          continuationLines =
            fmap Text.strip $
              takeWhile
                ( \line ->
                    not (Text.null (Text.strip line))
                      && Text.length (Text.takeWhile (== ' ') line) > fieldIndent
                )
                rest
       in fieldValue : continuationLines
 where
  isNamedField line =
    (fieldName <> ":") `Text.isPrefixOf` Text.strip line

cabalFieldEntries :: Text -> Text -> [Text]
cabalFieldEntries fieldName =
  filter (not . Text.null)
    . Text.words
    . Text.replace "," " "
    . Text.unlines
    . cabalFieldLines fieldName

cabalExposedModules :: Text -> [Text]
cabalExposedModules =
  cabalFieldEntries "exposed-modules"

cabalBuildDependsPackages :: Text -> [Text]
cabalBuildDependsPackages componentSection =
  filter (not . Text.null)
    . fmap (Text.takeWhile isCabalDependencyPackageChar . Text.strip)
    . Text.splitOn ","
    . Text.intercalate "\n"
    $ cabalFieldLines "build-depends" componentSection

isCabalDependencyPackageChar :: Char -> Bool
isCabalDependencyPackageChar character =
  isAlphaNum character || character == '-' || character == '_' || character == ':'

inventoryMismatches :: Text -> [Text] -> [Text] -> [Text]
inventoryMismatches inventoryName expected actual =
  [ inventoryName <> " missing: " <> Text.intercalate ", " missing
  | not (null missing)
  ]
    <> [ inventoryName <> " extra: " <> Text.intercalate ", " extra
       | not (null extra)
       ]
 where
  missing = expected \\ actual
  extra = actual \\ expected

assertNoTextMatches :: String -> [Text] -> IO Bool
assertNoTextMatches assertionName matches = do
  when (not (null matches)) $
    mapM_ (putStrLn . ("  " <>) . Text.unpack) matches
  testAssert assertionName (null matches)

testAssert :: String -> Bool -> IO Bool
testAssert assertionName condition = do
  if condition
    then putStrLn ("PASS " <> assertionName)
    else putStrLn ("FAIL " <> assertionName)
  pure condition

textNeedlesInOrder :: [Text] -> Text -> Bool
textNeedlesInOrder [] _source =
  True
textNeedlesInOrder (needle : rest) source =
  case Text.breakOn needle source of
    (_before, after)
      | Text.null after -> False
      | otherwise -> textNeedlesInOrder rest (Text.drop (Text.length needle) after)

sourceImportViolationsUnder :: FilePath -> [Text] -> IO [Text]
sourceImportViolationsUnder root forbiddenModules = do
  files <- sourceFilesUnder root
  fmap concat $
    traverse
      ( \path -> do
          source <- Text.pack <$> readFile path
          pure (sourceImportViolationsIn path forbiddenModules source)
      )
      files

sourceImportViolationsIn :: FilePath -> [Text] -> Text -> [Text]
sourceImportViolationsIn path forbiddenModules source =
  concatMap lineViolation (zip [(1 :: Int) ..] (Text.lines source))
 where
  pathText = Text.pack path
  lineViolation (lineNumber, line) =
    case sourceImportedModule line of
      Nothing -> []
      Just moduleName ->
        case filter (`forbiddenModuleMatches` moduleName) forbiddenModules of
          [] -> []
          forbiddenModule : _ ->
            [ pathText
                <> ":"
                <> Text.pack (show lineNumber)
                <> ": "
                <> moduleName
                <> " matches "
                <> forbiddenModule
            ]

sourceTextNeedleViolationsUnder :: FilePath -> [Text] -> IO [Text]
sourceTextNeedleViolationsUnder root forbiddenNeedles = do
  files <- sourceFilesUnder root
  fmap concat $
    traverse
      ( \path -> do
          source <- Text.pack <$> readFile path
          pure (sourceTextNeedleViolationsIn path forbiddenNeedles source)
      )
      files

sourceTextNeedleViolationsIn :: FilePath -> [Text] -> Text -> [Text]
sourceTextNeedleViolationsIn path forbiddenNeedles source =
  concatMap lineViolation (zip [(1 :: Int) ..] (Text.lines source))
 where
  pathText = Text.pack path
  lineViolation (lineNumber, line) =
    [ pathText
        <> ":"
        <> Text.pack (show lineNumber)
        <> ": contains "
        <> needle
    | needle <- forbiddenNeedles
    , needle `Text.isInfixOf` line
    ]

sourceImportedModule :: Text -> Maybe Text
sourceImportedModule line
  | Just rest <- Text.stripPrefix "import qualified " stripped =
      sourceImportedModuleFromRest rest
  | Just rest <- Text.stripPrefix "import " stripped =
      sourceImportedModuleFromRest rest
  | otherwise =
      Nothing
 where
  stripped = Text.strip line

sourceImportedModuleFromRest :: Text -> Maybe Text
sourceImportedModuleFromRest rest =
  let moduleName =
        Text.takeWhile isSourceModuleChar
          . dropPackageQualifier
          . Text.strip
          $ rest
   in if Text.null moduleName
        then Nothing
        else Just moduleName

dropPackageQualifier :: Text -> Text
dropPackageQualifier rest =
  case Text.stripPrefix "\"" rest of
    Just afterOpenQuote ->
      Text.strip
        . Text.drop 1
        . Text.dropWhile (/= '"')
        $ afterOpenQuote
    Nothing -> rest

forbiddenModuleMatches :: Text -> Text -> Bool
forbiddenModuleMatches forbiddenModule moduleName
  | "." `Text.isSuffixOf` forbiddenModule =
      moduleName == Text.dropEnd 1 forbiddenModule
        || forbiddenModule `Text.isPrefixOf` moduleName
  | otherwise =
      moduleName == forbiddenModule
        || (forbiddenModule <> ".") `Text.isPrefixOf` moduleName

isSourceModuleChar :: Char -> Bool
isSourceModuleChar character =
  isAlphaNum character || character == '_' || character == '\'' || character == '.'

sourceTextUnder :: FilePath -> IO Text
sourceTextUnder root = do
  files <- sourceFilesUnder root
  Text.intercalate "\n" <$> traverse (fmap Text.pack . readFile) files

sourceModulesUnder :: FilePath -> IO [Text]
sourceModulesUnder root = do
  files <- sourceFilesUnder root
  pure [moduleName | Just moduleName <- fmap (sourceModuleFromPath root) files]

sourceModuleFromPath :: FilePath -> FilePath -> Maybe Text
sourceModuleFromPath root path
  | ".hs" `Text.isSuffixOf` pathText =
      Just
        . Text.intercalate "."
        . fmap Text.pack
        . splitDirectories
        . dropExtension
        $ makeRelative root path
  | otherwise =
      Nothing
 where
  pathText = Text.pack path

sourceIdentifierTokens :: Text -> [Text]
sourceIdentifierTokens =
  filter (not . Text.null) . Text.split (not . isSourceIdentifierChar)
 where
  isSourceIdentifierChar character =
    isAlphaNum character || character == '_' || character == '\''

sourceFilesUnder :: FilePath -> IO [FilePath]
sourceFilesUnder root = do
  entries <- listDirectory root
  fmap concat $
    traverse
      ( \entry -> do
          let path = root </> entry
          isDirectory <- doesDirectoryExist path
          if isDirectory
            then sourceFilesUnder path
            else pure [path | ".hs" `Text.isSuffixOf` Text.pack path]
      )
      entries
