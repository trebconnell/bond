-- Copyright (c) Microsoft. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for full license information.

module IO
    ( parseFile
    , parseBondFile
    , parseASTFile
    , parseNamespaceMappings
    , parseAliasMappings
    )
    where

import Control.Applicative
import Control.Monad.Loops (firstM)
import Data.Aeson (eitherDecode)
import Data.Void (Void)
import qualified Data.ByteString.Lazy as BL
import qualified Data.List.NonEmpty as NE
import qualified Data.Text as T
import Language.Bond.Codegen.TypeMapping
import Language.Bond.Parser
import Language.Bond.Syntax.JSON()
import Language.Bond.Syntax.Types (Bond(..))
import Prelude
import System.Directory
import System.Exit
import System.FilePath
import System.IO
import Text.Megaparsec
import Text.Printf


parseFile :: [FilePath] -> FilePath -> IO(Bond)
parseFile importDirs file =
    if takeExtension file == ".json" then
        parseASTFile file else
        parseBondFile importDirs file


parseBondFile :: [FilePath] -> FilePath -> IO(Bond)
parseBondFile importDirs file = do
    cwd <- getCurrentDirectory
    input <- readFileUtf8 file
    result <- parseBond file input (cwd </> file) readImportFile
    case result of
        Left err -> do
            putStrLn $ msbuildErrorMessage err
            exitFailure
        Right bond -> return bond
  where
    readImportFile parentFile importFile = do
        path <- findFilePath (takeDirectory parentFile:importDirs)
        case path of
            Just path' -> do
                content <- readFileUtf8 path'
                return (path', content)
            Nothing -> fail $ "Can't find import file " ++ importFile
      where
        findFilePath dirs = fmap (</> importFile) <$> firstM (doesFileExist . (</> importFile)) dirs

    readFileUtf8 name = do
        h <- openFile name ReadMode
        hSetEncoding h utf8_bom
        hGetContents h


parseASTFile :: FilePath -> IO(Bond)
parseASTFile file = do
    input <- BL.readFile file
    case eitherDecode input of
        Left err -> do
            putStrLn $ "Error parsing " ++ file ++ ": " ++ show err
            exitFailure
        Right bond -> return bond


parseAliasMappings :: [String] -> IO [AliasMapping]
parseAliasMappings = mapM $
    \ s -> case parseAliasMapping s of
        Left err -> fail $ show err
        Right m -> return m


parseNamespaceMappings :: [String] -> IO [NamespaceMapping]
parseNamespaceMappings = mapM $
    \ s -> case parseNamespaceMapping s of
        Left err -> fail $ show err
        Right m -> return m

msbuildErrorMessage :: (ParseError Char Void) -> String
msbuildErrorMessage err = printf "%s(%d,%d) : error B0000: %s" name line col message
    where
        message = combinedMessage err
        pos = errorPos err
        name = sourceName (NE.head pos)
        line = unPos $ sourceLine (NE.head pos)
        col = unPos $ sourceColumn (NE.head pos)

combinedMessage :: (ParseError Char Void) -> String
combinedMessage err = id $ T.unpack $ T.intercalate (T.pack ", ") messages
    where
        -- parseErrorPretty returns a multi-line String.
        -- We need to break it up to make a useful one-line message.
        messages = T.splitOn (T.pack "\n") $ T.strip $ T.pack $ parseErrorPretty err
