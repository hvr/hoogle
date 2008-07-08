
module Data.Binary.Defer.Index(
    Id,
    Index, newIndex,
    Lookup, newLookup, lookupKey, lookupIndex,
    Link, newLink, fromLink, linkKey,
    Index_, newIndex_, getLookup, indexFreeze
    ) where

import General.Util
import Data.Binary.Defer
import Data.Binary.Defer.Array
import qualified Data.Map as Map
import Data.Maybe
import Data.List
import Data.Typeable

type Id = Int


---------------------------------------------------------------------
-- INDEX

newtype Index a = Index (Array a)


typename_Index = mkTyCon "Data.Binary.Defer.Index.Index"
instance Typeable1 Index where typeOf1 _ = mkTyConApp typename_Index []
instance Typeable a => Typeable (Index a) where typeOf = typeOfDefault


-- | Items will obtain the Id's 0..length-1
newIndex :: [a] -> Index a
newIndex = Index . array


instance BinaryDefer a => BinaryDefer (Index a) where
    put (Index x) = put x
    get = get1 Index

instance Show a => Show (Index a) where
    show (Index xs) = unlines $ zipWith f [0..] (elems xs)
        where
            f i x = "#" ++ si ++ replicate (width - length si + 1) ' ' ++ show x
                where si = show i
            width = length $ show $ arraySize xs

instance Functor Index where
    fmap f (Index x) = Index $ fmap f x


---------------------------------------------------------------------
-- LOOKUP

newtype Lookup a = Lookup {lookupKey :: Id}
                   deriving (Eq,Ord)

newLookup :: Id -> Lookup a
newLookup = Lookup

lookupIndex :: Lookup a -> Index a -> a
lookupIndex (Lookup i) (Index xs) = xs ! i


instance BinaryDefer (Lookup a) where
    put (Lookup key) = put key
    get = get1 Lookup
    size _ = size (0 :: Id)
    putFixed (Lookup key) = putFixed key
    getFixed = getFixed1 Lookup


instance Show (Lookup a) where
    show (Lookup key) = "#" ++ show key


---------------------------------------------------------------------
-- LINK

data Link a = Link Id a

newLink :: Id -> a -> Link a
newLink = Link

fromLink :: Link a -> a
fromLink (Link k v) = v

linkKey :: Link a -> Id
linkKey (Link k v) = k

instance Eq (Link a) where
    a == b = linkKey a == linkKey b

instance Ord a => Ord (Link a) where
    compare a b = compare (fromLink a) (fromLink b)

instance Show a => Show (Link a) where
    show = show . fromLink

instance Typeable a => BinaryDefer (Link a) where
    put = put . linkKey
    get = do
        i <- get
        Index xs <- getDeferGet
        return $ Link i $ xs ! i

    size _ = size (0 :: Id)
    putFixed = put
    getFixed = get


---------------------------------------------------------------------
-- INDEXMUTABLE

newtype Index_ a = Index_ (Map.Map a Id)

instance Show a => Show (Index_ a) where
    show = show . indexFreeze


newIndex_ :: Index_ a
newIndex_ = Index_ Map.empty


getLookup :: Ord a => a -> Index_ a -> (Index_ a, Lookup a)
getLookup x (Index_ mp) = (Index_ mp2, Lookup $ fromMaybe n res)
    where (res,mp2) = Map.insertLookupWithKey (\_ _ a -> a) x n mp
          n = Map.size mp


indexFreeze :: Index_ a -> Index a
indexFreeze (Index_ mp) = newIndex $ map fst $ sortBy (compare `on` snd) $ Map.toList mp
