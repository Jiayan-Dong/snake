{-# LANGUAGE OverloadedStrings #-}
module UI where

import Control.Monad (forever, void)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.State (put, modify)
import Control.Concurrent (threadDelay, forkIO)
import Data.Maybe (fromMaybe)

import Snake

import Brick
  ( App(..), AttrMap, BrickEvent(..), EventM, Widget
  , customMain, neverShowCursor
  , halt
  , hLimit, vLimit, vBox, hBox
  , padRight, padLeft, padTop, padAll, Padding(..)
  , withBorderStyle
  , str
  , attrMap, attrName, withAttr, emptyWidget, AttrName, on, fg
  , (<+>)
  )
import Brick.BChan (newBChan, writeBChan)
import qualified Brick.Widgets.Border as B
import qualified Brick.Widgets.Border.Style as BS
import qualified Brick.Widgets.Center as C
import Control.Lens ((^.))
import qualified Graphics.Vty as V
import Graphics.Vty.Platform.Unix (mkVty)
import Data.Sequence (Seq)
import qualified Data.Sequence as S
import Linear.V2 (V2(..))

-- Types

-- | Ticks mark passing of time
--
-- This is our custom event that will be constantly fed into the app.
data Tick = Tick

-- | Named resources
--
-- Not currently used, but will be easier to refactor
-- if we call this "Name" now.
type Name = ()

data Cell = Snake | Food | Empty

-- App definition

app :: App Game Tick Name
app = App { appDraw = drawUI
          , appChooseCursor = neverShowCursor
          , appHandleEvent = handleEvent
          , appStartEvent = return ()
          , appAttrMap = const theMap
          }

main :: IO ()
main = do
  chan <- newBChan 10
  forkIO $ forever $ do
    writeBChan chan Tick
    threadDelay 100000 -- decides how fast your game moves
  g <- initGame
  let builder = mkVty V.defaultConfig
  initialVty <- builder
  void $ customMain initialVty builder (Just chan) app g

-- Handling events

handleEvent :: BrickEvent Name Tick -> EventM Name Game ()
handleEvent (AppEvent Tick)                       = modify step
handleEvent (VtyEvent (V.EvKey V.KUp []))         = modify $ turn North
handleEvent (VtyEvent (V.EvKey V.KDown []))       = modify $ turn South
handleEvent (VtyEvent (V.EvKey V.KRight []))      = modify $ turn East
handleEvent (VtyEvent (V.EvKey V.KLeft []))       = modify $ turn West
handleEvent (VtyEvent (V.EvKey (V.KChar 'k') [])) = modify $ turn North
handleEvent (VtyEvent (V.EvKey (V.KChar 'j') [])) = modify $ turn South
handleEvent (VtyEvent (V.EvKey (V.KChar 'l') [])) = modify $ turn East
handleEvent (VtyEvent (V.EvKey (V.KChar 'h') [])) = modify $ turn West
handleEvent (VtyEvent (V.EvKey (V.KChar 'r') [])) = liftIO initGame >>= put
handleEvent (VtyEvent (V.EvKey (V.KChar 'q') [])) = halt
handleEvent (VtyEvent (V.EvKey V.KEsc []))        = halt
handleEvent _                                     = return ()

-- Drawing

drawUI :: Game -> [Widget Name]
drawUI g =
  [ C.center $ padRight (Pad 2) (drawStats g) <+> drawGrid g ]

drawStats :: Game -> Widget Name
drawStats g = hLimit 11
  $ vBox [ drawScore (g ^. score)
         , padTop (Pad 2) $ drawGameOver (g ^. dead)
         ]

drawScore :: Int -> Widget Name
drawScore n = withBorderStyle BS.unicodeBold
  $ B.borderWithLabel (str "Score")
  $ C.hCenter
  $ padAll 1
  $ str $ show n

drawGameOver :: Bool -> Widget Name
drawGameOver dead =
  if dead
     then withAttr gameOverAttr $ C.hCenter $ str "GAME OVER"
     else emptyWidget

drawGrid :: Game -> Widget Name
drawGrid g = withBorderStyle BS.unicodeBold
  $ B.borderWithLabel (str "Snake")
  $ vBox rows
  where
    rows         = [hBox $ cellsInRow r | r <- [height-1,height-2..0]]
    cellsInRow y = [drawCoord (V2 x y) | x <- [0..width-1]]
    drawCoord    = drawCell . cellAt
    cellAt c
      | c `elem` g ^. snake = Snake
      | c == g ^. food      = Food
      | otherwise           = Empty

drawCell :: Cell -> Widget Name
drawCell Snake = withAttr snakeAttr cw
drawCell Food  = withAttr foodAttr cw
drawCell Empty = withAttr emptyAttr cw

cw :: Widget Name
cw = str "  "

theMap :: AttrMap
theMap = attrMap V.defAttr
  [ (snakeAttr, V.blue `on` V.blue)
  , (foodAttr, V.red `on` V.red)
  , (gameOverAttr, fg V.red `V.withStyle` V.bold)
  ]

gameOverAttr :: AttrName
gameOverAttr = attrName "gameOver"

snakeAttr, foodAttr, emptyAttr :: AttrName
snakeAttr = attrName "snakeAttr"
foodAttr = attrName "foodAttr"
emptyAttr = attrName "emptyAttr"
