-- |
-- Module:      Data.Chimera.WheelMapping
-- Copyright:   (c) 2017 Andrew Lelechenko
-- Licence:     MIT
-- Maintainer:  Andrew Lelechenko <andrew.lelechenko@gmail.com>
--
-- Helpers for mapping to <http://mathworld.wolfram.com/RoughNumber.html rough numbers>
-- and back. Mostly useful in number theory.
--
-- __Example__
--
-- Let 'isPrime' be an expensive predicate, which checks whether its
-- argument is a prime number. We can improve performance of repetitive reevaluation by memoization:
--
-- > isPrimeBS :: Chimera
-- > isPrimeBS = tabulate isPrime
-- >
-- > isPrime' :: Word -> Bool
-- > isPrime' = index isPrimeBS
--
-- However, it is well-known that the only even prime is 2.
-- So we can save half of space by memoizing the predicate for odd
-- numbers only:
--
-- > isPrimeBS2 :: Chimera
-- > isPrimeBS2 = tabulate (\n -> isPrime (2 * n + 1))
-- >
-- > isPrime2' :: Word -> Bool
-- > isPrime2' n
-- >   | n == 2    = True
-- >   | even n    = False
-- >   | otherwise = index isPrimeBS2 ((n - 1) `quot` 2)
--
-- or, using 'fromWheel2' and 'toWheel2',
--
-- > isPrimeBS2 :: Chimera
-- > isPrimeBS2 = tabulate (isPrime . fromWheel2)
-- >
-- > isPrime2' :: Word -> Bool
-- > isPrime2' n
-- >   | n == 2    = True
-- >   | even n    = False
-- >   | otherwise = index isPrimeBS2 (toWheel2 n)
--
-- Well, we also know that all primes, except 2 and 3, are coprime to 6; and all primes, except 2, 3 and 5, are coprime 30. So we can save even more space by writing
--
-- > isPrimeBS6 :: Chimera
-- > isPrimeBS6 = tabulate (isPrime . fromWheel6)
-- >
-- > isPrime6' :: Word -> Bool
-- > isPrime6' n
-- >   | n `elem` [2, 3] = True
-- >   | n `gcd` 6 /= 1  = False
-- >   | otherwise       = index isPrimeBS6 (toWheel6 n)
--
-- or
--
-- > isPrimeBS30 :: Chimera
-- > isPrimeBS30 = tabulate (isPrime . fromWheel30)
-- >
-- > isPrime30' :: Word -> Bool
-- > isPrime30' n
-- >   | n `elem` [2, 3, 5] = True
-- >   | n `gcd` 30 /= 1    = False
-- >   | otherwise          = index isPrimeBS30 (toWheel30 n)

module Data.Chimera.WheelMapping
  ( fromWheel2
  , toWheel2
  , fromWheel6
  , toWheel6
  , fromWheel30
  , toWheel30
  , fromWheel210
  , toWheel210
  ) where

import Data.Bits
import Data.Primitive.ByteArray
import Data.Word

word2int :: Word -> Int
word2int = fromIntegral

-- | Left inverse for 'fromWheel2'. Monotonically non-decreasing function.
--
-- prop> toWheel2 . fromWheel2 == id
toWheel2 :: Word -> Word
toWheel2 i = i `shiftR` 1
{-# INLINE toWheel2 #-}

-- | 'fromWheel2' n is the (n+1)-th positive odd number.
-- Sequence <https://oeis.org/A005408 A005408>.
--
-- prop> map fromWheel2 [0..] == [ n | n <- [0..], n `gcd` 2 == 1 ]
--
-- > > map fromWheel2 [0..9]
-- > [1,3,5,7,9,11,13,15,17,19]
fromWheel2 :: Word -> Word
fromWheel2 i = i `shiftL` 1 + 1
{-# INLINE fromWheel2 #-}

-- | Left inverse for 'fromWheel6'. Monotonically non-decreasing function.
--
-- prop> toWheel6 . fromWheel6 == id
toWheel6 :: Word -> Word
toWheel6 i = i `quot` 3
{-# INLINE toWheel6 #-}

-- | 'fromWheel6' n is the (n+1)-th positive number, not divisible by 2 or 3.
-- Sequence <https://oeis.org/A007310 A007310>.
--
-- prop> map fromWheel6 [0..] == [ n | n <- [0..], n `gcd` 6 == 1 ]
--
-- > > map fromWheel6 [0..9]
-- > [1,5,7,11,13,17,19,23,25,29]
fromWheel6 :: Word -> Word
fromWheel6 i = i `shiftL` 1 + i + (i .&. 1) + 1
{-# INLINE fromWheel6 #-}

-- | Left inverse for 'fromWheel30'. Monotonically non-decreasing function.
--
-- prop> toWheel30 . fromWheel30 == id
toWheel30 :: Word -> Word
toWheel30 i = q `shiftL` 3 + (r + r `shiftR` 4) `shiftR` 2
  where
    (q, r) = i `quotRem` 30
{-# INLINE toWheel30 #-}

-- | 'fromWheel30' n is the (n+1)-th positive number, not divisible by 2, 3 or 5.
-- Sequence <https://oeis.org/A007775 A007775>.
--
-- prop> map fromWheel30 [0..] == [ n | n <- [0..], n `gcd` 30 == 1 ]
--
-- > > map fromWheel30 [0..9]
-- > [1,7,11,13,17,19,23,29,31,37]
fromWheel30 :: Word -> Word
fromWheel30 i = ((i `shiftL` 2 - i `shiftR` 2) .|. 1)
              + ((i `shiftL` 1 - i `shiftR` 1) .&. 2)
{-# INLINE fromWheel30 #-}

-- | Left inverse for 'fromWheel210'. Monotonically non-decreasing function.
--
-- prop> toWheel210 . fromWheel210 == id
toWheel210 :: Word -> Word
toWheel210 i = q * 48 + fromIntegral (toWheel210Table `indexByteArray` word2int r :: Word8)
  where
    (q, r) = i `quotRem` 210
{-# INLINE toWheel210 #-}

toWheel210Table :: ByteArray
toWheel210Table = byteArrayFromList ([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 13, 13, 14, 14, 14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 22, 22, 23, 23, 23, 23, 24, 24, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 30, 30, 31, 31, 31, 31, 32, 32, 32, 32, 32, 32, 33, 33, 34, 34, 34, 34, 34, 34, 35, 35, 35, 35, 35, 35, 36, 36, 36, 36, 37, 37, 38, 38, 38, 38, 39, 39, 39, 39, 39, 39, 40, 40, 41, 41, 41, 41, 41, 41, 42, 42, 42, 42, 43, 43, 44, 44, 44, 44, 45, 45, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 47] :: [Word8])

-- | 'fromWheel210' n is the (n+1)-th positive number, not divisible by 2, 3, 5 or 7.
-- Sequence <https://oeis.org/A008364 A008364>.
--
-- prop> map fromWheel210 [0..] == [ n | n <- [0..], n `gcd` 210 == 1 ]
--
-- > > map fromWheel210 [0..9]
-- > [1,11,13,17,19,23,29,31,37,41]
fromWheel210 :: Word -> Word
fromWheel210 i = q * 210 + fromIntegral (fromWheel210Table `indexByteArray` word2int r :: Word8)
  where
    (q, r) = i `quotRem` 48
{-# INLINE fromWheel210 #-}

fromWheel210Table :: ByteArray
fromWheel210Table = byteArrayFromList ([1, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 121, 127, 131, 137, 139, 143, 149, 151, 157, 163, 167, 169, 173, 179, 181, 187, 191, 193, 197, 199, 209] :: [Word8])