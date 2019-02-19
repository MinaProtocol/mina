{-

Derived from examples in https://github.com/serokell/kademlia

Copyright (c) 2015, fro_ozen
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 -}

import           Control.Exception         (finally)
import           Control.Monad             (when, foldM)
import           Control.Monad.Random      (Rand, RandomGen, evalRand, getRandom)
import           Data.Binary               (Binary (..), decodeOrFail, encode, getWord8,
                                            putWord8)
import qualified Data.Bool                 as BOOL
import qualified Data.ByteString           as B
import qualified Data.ByteString.Char8     as C
import           Data.ByteString.Lazy      (fromStrict, toStrict)
import qualified Data.ByteString.Base64    as B64
import           Data.Hashable             as H
import           Data.List                 ((\\))
import           Data.Tuple                (fst)
import           GHC.Conc                  (threadDelay)
import           Network                   (PortNumber)
import qualified Network.Kademlia          as K
import qualified Network.Kademlia.HashNodeId as KH
import           System.Environment        (getArgs)
import           System.Exit               (die)
import           System.Random             (mkStdGen)
import           System.IO                 (stdout, hFlush)

data Pong = Pong
          deriving (Eq, Show)

instance K.Serialize Pong where
    toBS = toBSBinary
    fromBS = fromBSBinary

type KademliaValue = Pong
type KademliaID = KH.HashId

type KademliaInstance = K.KademliaInstance KademliaID KademliaValue

instance Binary Pong where
    put _ = putWord8 1
    get = do
        w <- getWord8
        if w == 1
        then pure Pong
        else fail "no parse pong"

{- The nonce for the HashId is 14 bytes as described in
 - https://cardanodocs.com/technical/protocols/p2p/ -}
nonceSize :: Int
nonceSize = 14

makeSeed :: (H.Hashable h, Integral a) => h -> a
makeSeed h = fromIntegral (H.hash h)

toBSBinary :: Binary b => b -> B.ByteString
toBSBinary = toStrict . encode

fromBSBinary :: Binary b => B.ByteString -> Either String (b, B.ByteString)
fromBSBinary bs =
    case decodeOrFail $ fromStrict bs of
        Left (_, _, errMsg)  -> Left errMsg
        Right (rest, _, res) -> Right (res, toStrict rest)

generateByteString :: (RandomGen g) => Int -> Rand g B.ByteString
generateByteString len = C.pack <$> sequence (replicate len getRandom)

connectToPeer :: KademliaInstance -> String -> PortNumber -> KademliaID -> IO K.JoinResult
connectToPeer inst peerIp peerPort _ = K.joinNetwork inst (K.Peer peerIp peerPort)

whileM :: Monad m => (a -> Bool) -> (a -> m a) -> a -> m ()
whileM test act a = when (test a) $ (act a) >>= whileM test act

foreverM :: Monad m => (a -> m a) -> a -> m ()
foreverM = whileM (const True)

data Event = Live | Dead
dumpEvt :: Event -> String
dumpEvt Live = "on"
dumpEvt Dead = "off"

dumpFormat :: Event -> K.Node KH.HashId -> String
dumpFormat evt K.Node{peer=peer,nodeId=(KH.HashId bs)} = show peer ++ " " ++ (show $ B64.encode bs) ++ " " ++ dumpEvt evt

hasPeers :: K.KademliaInstance KH.HashId KademliaValue -> IO Bool
hasPeers inst = do
  peers <- K.dumpPeers inst
  return $ length peers > 0

formatAddress :: (Show a, Show b) => a -> b -> B.ByteString -> String
formatAddress ip port key = show ip ++ ":" ++ show port ++ ", " ++ show (B64.encode key)

{- Usage: ./$0 test '("127.0.0.1", 3000)' '("127.0.0.1", 3001)' -}
main :: IO ()
main = do
    (state : rest) <- getArgs
    {- TODO: When we implement (state == "prod"):
     -  1. Don't just cycle through all the peers in order
     -  2. Make sure that nonces are securely randomly generated
     -  3. Make the ping time WAY slower (use the kDefaultConfig raw -- ala
     -    Cardano) ~1hour heartbeats
     -}
    when (state == "test") $ do
      let ((externalIp, myPort) : peers) = map read rest
      let
          nonceGen  = \x -> KH.Nonce $ evalRand (generateByteString nonceSize) (mkStdGen $ makeSeed x)
          myKey     = KH.hashAddress $ nonceGen (externalIp, myPort)
          peerKeys  = (KH.hashAddress . nonceGen) <$> peers
          config = K.defaultConfig { K.pingTime = 2, K.storeValues = False }

      let logError = putStrLn . ("EROR: " ++)
      let logInfo = putStrLn . ("DBUG: " ++)
      let logData = putStrLn . ("DATA: " ++)
      let logTrace = putStrLn . ("TRAC: " ++)

      logInfo $ "Creating instance"
      kInstance <- K.createL ("127.0.0.1", myPort) (externalIp, myPort) myKey config logTrace logError

      {- If this is an initial peer, then don't try to connect to others -}
      _ <- if length peers == 0 then return () else do
        {- Try to join one of the peers in the peer list -}
        r <- foldM (\acc -> \((peerIp,peerPort), peerKey) ->
          case acc of
            K.JoinSuccess -> return acc
            _ -> do
              let KH.HashId peerKeyBytes = peerKey
              when (BOOL.not $ KH.verifyAddress peerKeyBytes) $ do
                die $ "Invalid address on initial peer: " ++ formatAddress peerIp peerPort peerKeyBytes
              logInfo $ "Attempting to connecting to peer: " ++ formatAddress peerIp peerPort peerKeyBytes
              r' <- connectToPeer kInstance peerIp (fromIntegral peerPort) peerKey
              didGetPeers <- hasPeers kInstance
              {- If someone connected to us, while we were in the process of handshaking we're in the network -}
              let r = if didGetPeers then K.JoinSuccess else r'
              when (r /= K.JoinSuccess) $
                  logError . ("Connection to peer failed "++) . show $ r
              return r) K.NodeDown (zip peers peerKeys)

        hFlush stdout

        when (r /= K.JoinSuccess) $
          die "All peers failed to respond!"

      logInfo $ "Dumping initial live peers"
      {- Dump all live peers first, after joining the network -}
      firstDump <- K.dumpPeers kInstance
      let peersFromDump d = fst <$> d
      let initialPeers = peersFromDump firstDump
      when (length initialPeers /= 0) $
        mapM_ logData $ (dumpFormat Live) <$> initialPeers

      hFlush stdout

      {- Forever, once a second, check to see if anything changed, and dump it -}
      finally
        (foreverM (\oldPeers -> do
        _ <- threadDelay 1000000
        currDump <- K.dumpPeers kInstance
        let currPeers = peersFromDump currDump
        let (newLives, newDeads) = (currPeers \\ oldPeers, oldPeers \\ currPeers)
        when (length newLives /= 0) $ do
          mapM_ logData $ (dumpFormat Live) <$> newLives
        when (length newDeads /= 0) $ do
          mapM_ logData $ (dumpFormat Dead) <$> newDeads
        hFlush stdout
        return currPeers) initialPeers)
        (K.close kInstance)
