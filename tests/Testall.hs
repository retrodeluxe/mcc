module Main where

import Test.Tasty (defaultMain, TestTree, testGroup)
import Test.Tasty.Golden
import System.FilePath (takeBaseName, replaceExtension)

import Microc

import           Data.String.Conversions
import qualified Data.Text.IO as T
import           Data.Text (Text)

import System.IO.Silently

-- | Given a microc file, attempt to compile and execute it and write the
-- results to a new file to be compared with what should be the correct output
runFile :: FilePath -> IO Text
runFile infile = do
  program <- T.readFile infile
  let parseTree = runParser programP (cs infile) program
  case parseTree of
    Left _ -> redirect $ parseTest' programP program
    Right ast -> case checkProgram ast of
      Left err -> redirect $ T.putStrLn err
      Right sast -> do
        let llvmModule = codegenProgram sast
        redirect $ run llvmModule
  where
    redirect action = cs <$> capture_ action

main :: IO ()
main = defaultMain =<< goldenTests

-- | All of the test cases
-- General structure taken from 
-- https://ro-che.info/articles/2017-12-04-golden-tests
goldenTests :: IO TestTree
goldenTests = testGroup "all tests" <$> sequence [passing, failing]

passing :: IO TestTree
passing = do
  mcFiles <- findByExtension [".mc"] "tests/pass"
  return $ testGroup "microc passing tests"
    [ goldenVsString (takeBaseName mcFile) outfile (cs <$> runFile mcFile)
      | mcFile <- mcFiles, let outfile = replaceExtension mcFile ".out" ]

failing :: IO TestTree
failing = do
  mcFiles <- findByExtension [".mc"] "tests/fail"
  return $ testGroup "microc failing tests"
    [ goldenVsString (takeBaseName mcFile) outfile (cs <$> runFile mcFile)
      | mcFile <- mcFiles, let outfile = replaceExtension mcFile ".err" ]