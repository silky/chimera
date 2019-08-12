{-# LANGUAGE ScopedTypeVariables #-}

{-# OPTIONS_GHC -fno-warn-orphans -fno-warn-unused-imports #-}

module Main where

import Test.QuickCheck.Function
import Test.Tasty
import Test.Tasty.HUnit as H
import Test.Tasty.QuickCheck as QC

import Data.Bits
import Data.Function (fix)
import Data.List
import qualified Data.Vector as V
import qualified Data.Vector.Generic as G
import qualified Data.Vector.Unboxed as U
import Data.Word

import Data.Chimera.ContinuousMapping
import Data.Chimera.WheelMapping
import qualified Data.Chimera as Ch

instance (G.Vector v a, Arbitrary a) => Arbitrary (Ch.Chimera v a) where
  arbitrary = Ch.tabulateM (const arbitrary)

main :: IO ()
main = defaultMain $ testGroup "All"
  [ contMapTests
  , wheelMapTests
  , chimeraTests
  ]

contMapTests :: TestTree
contMapTests = testGroup "ContinuousMapping"
  [ testGroup "wordToInt . intToWord"
    [ QC.testProperty "random" $ \i -> w2i_i2w i === i
    , H.testCase "maxBound" $ assertEqual "should be equal" maxBound (w2i_i2w maxBound)
    , H.testCase "minBound" $ assertEqual "should be equal" minBound (w2i_i2w minBound)
    ]
  , testGroup "intToWord . wordToInt"
    [ QC.testProperty "random" $ \i -> i2w_w2i i === i
    , H.testCase "maxBound" $ assertEqual "should be equal" maxBound (i2w_w2i maxBound)
    , H.testCase "minBound" $ assertEqual "should be equal" minBound (i2w_w2i minBound)
    ]

  , testGroup "to . from Z-curve 2D"
    [ QC.testProperty "random" $ \z -> (\(x, y) -> toZCurve x y) (fromZCurve z) === z
    ]
  , testGroup "from . to Z-curve 2D"
    [ QC.testProperty "random" $ \x y -> fromZCurve (toZCurve x y) === (x `rem` (1 `shiftL` 32), y `rem` (1 `shiftL` 32))
    ]

  , testGroup "to . from Z-curve 3D"
    [ QC.testProperty "random" $ \t -> (\(x, y, z) -> toZCurve3 x y z) (fromZCurve3 t) === t `rem` (1 `shiftL` 63)
    ]
  , testGroup "from . to Z-curve 3D"
    [ QC.testProperty "random" $ \x y z -> fromZCurve3 (toZCurve3 x y z) === (x `rem` (1 `shiftL` 21), y `rem` (1 `shiftL` 21), z `rem` (1 `shiftL` 21))
    ]
  ]

wheelMapTests :: TestTree
wheelMapTests = testGroup "WheelMapping"
  [ testGroup "toWheel . fromWheel"
    [ QC.testProperty   "2" $ \(Shrink2 x) -> x < maxBound `div` 2 ==> toWheel2   (fromWheel2   x) === x
    , QC.testProperty   "6" $ \(Shrink2 x) -> x < maxBound `div` 3 ==> toWheel6   (fromWheel6   x) === x
    , QC.testProperty  "30" $ \(Shrink2 x) -> x < maxBound `div` 4 ==> toWheel30  (fromWheel30  x) === x
    , QC.testProperty "210" $ \(Shrink2 x) -> x < maxBound `div` 5 ==> toWheel210 (fromWheel210 x) === x
    ]
  ]

chimeraTests :: TestTree
chimeraTests = testGroup "Chimera"
  [ QC.testProperty "index . tabulate = id" $
    \(Fun _ (f :: Word -> Bool)) ix ->
      let jx = ix `mod` 65536 in
        f jx === Ch.index (Ch.tabulate f :: Ch.Chimera V.Vector Bool) jx
  , QC.testProperty "index . tabulateFix = fix" $
    \(Fun _ g) ix ->
      let jx = ix `mod` 65536 in
        let f = mkUnfix g in
          fix f jx === Ch.index (Ch.tabulateFix f :: Ch.Chimera V.Vector Bool) jx

  , QC.testProperty "mapWithKey" $
    \(Blind bs) (Fun _ (g :: (Word, Bool) -> Bool)) ix ->
      let jx = ix `mod` 65536 in
        g (jx, Ch.index bs jx) === Ch.index (Ch.mapWithKey (curry g) bs :: Ch.Chimera V.Vector Bool) jx

  , QC.testProperty "zipWithKey" $
    \(Blind bs1) (Blind bs2) (Fun _ (g :: (Word, Bool, Bool) -> Bool)) ix ->
      let jx = ix `mod` 65536 in
        g (jx, Ch.index bs1 jx, Ch.index bs2 jx) === Ch.index (Ch.zipWithKey (\i b1 b2 -> g (i, b1, b2)) bs1 bs2 :: Ch.Chimera V.Vector Bool) jx
  ]

-------------------------------------------------------------------------------
-- Utils

w2i_i2w :: Int -> Int
w2i_i2w = wordToInt . intToWord

i2w_w2i :: Word -> Word
i2w_w2i  = intToWord . wordToInt

mkUnfix :: (Word -> [Word]) -> (Word -> Bool) -> Word -> Bool
mkUnfix splt f x
  = foldl' (==) True
  $ map f
  $ takeWhile (\y -> 0 <= y && y < x)
  $ splt x
