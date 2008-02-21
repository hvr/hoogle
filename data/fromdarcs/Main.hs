
module Main where

import System.Cmd
import System.Environment
import System.Exit
import System.Directory
import System.FilePath
import System.IO

import Control.Monad
import Data.List
import Data.Maybe
import Data.Char


packages = ["base","Cabal","HUnit","QuickCheck","array","arrows","bytestring"
           ,"cgi","containers","directory","filepath","haskell-src","mtl"
           , {- "network", -} "old-locale","old-time","packedstring","parallel"
           ,"parsec","pretty","process","random","stm","template-haskell"
           ,"time","xhtml"]

keywords = ["|","->","<-","@","!","::","~","_","as","case","class","data"
           ,"default","deriving","do","else","forall","hiding","if","import"
           ,"in","infix","infixl","infixr","instance","let","module","newtype"
           ,"of","qualified","then","type","where"]

prefix = "http://darcs.haskell.org/ghc-6.8/packages/"

main = do
    args <- getArgs
    let rebuild = "skip" `notElem` args
    createDirectoryIfMissing True "grab"
    xs <- mapM (generate rebuild) packages
    (entires,docs) <- mapAndUnzipM divide xs
    writeBinaryFile "hoogle.txt" (unlines $ concat entires)
    writeBinaryFile "documentation.txt" (unlines $ concat docs)


bad = ["GM ::", "GT ::"]

divide file = do
    s <- readFile file
    let entries = filter (\x -> not $ any (`isPrefixOf` x) bad) $ lines s
        name = reverse $ drop 1 $ dropWhile (/= '-') $ reverse $ takeBaseName file
        docs = [drop 7 i ++ "\t" ++ name | i <- entries, "module " `isPrefixOf` i]
        expand x = if x == "module Prelude" then x:map ("keyword "++) keywords else [x]
    return (concatMap expand entries, docs)

generate rebuild url = do
    let name = last $ words $ map (\x -> if x == '/' then ' ' else x) url
        dir = "grab" </> name
        exe = "grab" </> name </> "Setup"
    ans <- findDatabase name

    when (rebuild || isNothing ans) $ do
        b <- doesDirectoryExist dir
        if b
            then system_ $ "darcs pull --all --repodir=" ++ dir
            else system_ $ "darcs get --partial " ++ prefix ++ url ++ "/ --repodir=" ++ dir

        setCurrentDirectory $ "grab" </> name
        fixup name
        system_ $ "ghc -i --make Setup"
        system_ $ "setup configure"
        system_ $ "setup haddock --hoogle"

        setCurrentDirectory "../.."

    liftM fromJust $ findDatabase name


findDatabase name = do
    let dir = "grab" </> name </> "dist" </> "doc" </> "html" </> name
    b <- doesDirectoryExist dir
    files <- if not b then return [] else getDirectoryContents dir
    return $ listToMaybe $ map (dir </>) $ filter ((==) ".txt" . takeExtension) files


system_ x = do
    putStrLn $ "Running: " ++ x
    res <- system x
    when (res /= ExitSuccess) $
        error "Command failed"

removeFile_ x = do
    b <- doesFileExist x
    when b $ removeFile x

readFile' x = do
    h <- openFile x ReadMode
    s <- hGetContents h
    () <- length s `seq` return ()
    hClose h
    return s

writeBinaryFile file x = do
    withBinaryFile file WriteMode (\h -> hPutStr h x)

fixup name = do
    -- FIX THE SETUP FILE
    removeFile_ "Setup.hs"
    removeFile_ "Setup.lhs"
    writeFile "Setup.hs" "import Distribution.Simple; main = defaultMain"

    -- FIX THE CABAL FILE
    let file = name <.> "cabal"
    x <- readFile' file

    -- trim build-depends as they may not exist on GHC 
    let f x = let (a,b) = span isSpace x 
              in if "build-depends" `isPrefixOf` map toLower b
                 then a ++ "build-depends:"
                 else x
    x <- return $ unlines $ map f $ lines x

    writeFile file x

    -- INCLUDE FILES
    let incdir = "include"
        n:ame = if "old-" `isPrefixOf` name then drop 4 name else name
        file = incdir </> ("Hs" ++ [toUpper n] ++ ame ++ "Config") <.> "h"
    b <- doesDirectoryExist incdir
    when b $ copyFile "../../Config.h" file