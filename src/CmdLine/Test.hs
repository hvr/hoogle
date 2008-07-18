
module CmdLine.Test(testFile) where

import Hoogle.All
import Hoogle.Item.All
import General.Code
import Data.Binary.Defer.Index


testFile :: FilePath -> FilePath -> IO ()
testFile srcfile dbfile = do
    putStrLn $ "Testing " ++ srcfile
    db <- loadDataBase dbfile
    src <- readFile srcfile
    let bad = filter (not . runTest db) $ catMaybes $ zipWith parseTest [1..] $ lines src
    if null bad then
        putStrLn "All tests passed"
     else do
        putStr $ unlines $ map failedTest bad
        putStrLn $ show (length bad) ++ " tests failed"


-- LineNo Query Results
data Test = Test Int String Query [String]
            deriving Show


parseTest :: Int -> String -> Maybe Test
parseTest line str | "@test " `isPrefixOf` str =
    case reads $ drop 5 str of
        [(x,rest)] -> case parseQuery x of
            Right q -> Just $ Test line x q (words rest)
            _ -> err
        _ -> err
    where err = error $ "Couldn't parse @test on line " ++ show line
parseTest line str = Nothing


runTest :: DataBase -> Test -> Bool
runTest db (Test _ _ q ans) = f ans $ searchAll [db] q
    where
        f ["*"] _ = True
        f ("*":x:xs) (m:ms) = f (if g x m then xs else "*":x:xs) ms
        f (x:xs) (m:ms) = g x m && f xs ms
        f [] [] = True
        f _ _ = False

        g name m = name == entryName (fromLink $ resultEntry m)


failedTest :: Test -> String
failedTest (Test line str _ _) = "Line " ++ show line ++ ", " ++ str
