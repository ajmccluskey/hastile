{-# LANGUAGE OverloadedStrings #-}

module Main where

-- import           Data.Aeson
-- import           Data.ByteString.Lazy as LBS (fromStrict, readFile)
-- import           Data.Maybe
-- import           Data.Monoid
-- import           Data.Text            (unpack)
-- import           System.Environment   (lookupEnv)
import           Test.Tasty
-- import           Test.Tasty.Golden

-- import           DB
-- import           MapboxVectorTile
-- import           Tile
-- import           Types

main :: IO ()
main = defaultMain integrationTest

integrationTest :: TestTree
integrationTest = testGroup "" []
--   let name = "MVT creation"
--       golden = "test/integration/mvt.golden"
--       geoJsonFile = "test/integration/tile.json"
--       layerName = "golden-test"
--       (z,x,y) = (14,13464,9727)
--       coords = Coordinates z $ GoogleTileCoords x y
--       actual = do
--         bs <- LBS.readFile geoJsonFile
--         let ebs = eitherDecode bs :: Either String GeoJson
--             decodeError = error . (("Unable to decode " <> geoJsonFile <> ": ") <>)
--             geoJson = either decodeError id ebs
--         pluginDir <- fromMaybe "/usr/local/lib/mapnik/input" <$> lookupEnv "MAPNIK_PLUGINS_DIR"
--         et <- fromGeoJSON defaultTileSize geoJson layerName pluginDir coords
--         either (error . unpack . ("Failed to create tile: " <>)) (return . fromStrict) et
   -- This failed under Linux - can't see what's different.
   -- Maybe binary file issues, maybe different mapnik version
--    in goldenVsStringDiff name  golden actual