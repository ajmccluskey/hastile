{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoMonomorphismRestriction  #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}

module Types where

import           Control.Applicative
import           Control.Lens         (Lens', makeLenses)
import           Data.Aeson
import qualified Data.ByteString      as BS
import           Data.ByteString.Lazy (ByteString, fromStrict)
import           Data.Map             as M
import           Data.Maybe           (catMaybes)
import           Data.Text            as T
import           Data.Time
import           Data.Typeable
import           Hasql.Pool           as P
import qualified Network.HTTP.Media   as HM
import           Options.Generic
import           Servant
import           STMContainers.Map    as STM

type GeoJson = M.Map Text Value

newtype ZoomLevel = ZoomLevel { _z :: Integer
                              } deriving (Show, Eq, Num)

data GoogleTileCoords = GoogleTileCoords { _x :: Integer
                                         , _y :: Integer
                                         } deriving (Eq, Show)

data Coordinates = Coordinates { _zl :: ZoomLevel
                               , _xy :: GoogleTileCoords
                               } deriving (Show, Eq)

newtype Pixels = Pixels Integer deriving (Show, Eq, Num)
instance ToJSON Pixels where
  toJSON (Pixels n) = Number $ fromIntegral n

data CmdLine = CmdLine { configFile :: FilePath
                       } deriving Generic
instance ParseRecord CmdLine

newtype LayerQuery = LayerQuery { unLayerQuery :: Text } deriving (Show, Eq)

instance ToJSON LayerQuery where
  toJSON (LayerQuery lq) = object [ "query" .= lq ]

instance FromJSON LayerQuery where
  parseJSON (Object o) = LayerQuery <$> o .: "query"
  parseJSON _ = Control.Applicative.empty

data Layer = Layer { _layerQuery        :: Text
                   , _layerLastModified :: UTCTime
                   } deriving (Show, Eq, Generic)

instance FromJSON Layer where
  parseJSON (Object o) =
       Layer <$> o .: "query" <*> o .: "last-modified"
  parseJSON _ = Control.Applicative.empty

data InputConfig = InputConfig { _inputConfigPgConnection :: Text
                     , _inputConfigPgPoolSize             :: Maybe Int
                     , _inputConfigPgTimeout              :: Maybe NominalDiffTime
                     , _inputConfigMapnikInputPlugins     :: Maybe FilePath
                     , _inputConfigPort                   :: Maybe Int
                     , _inputConfigLayers                 :: M.Map Text Layer
                     , _inputConfigTileBuffer             :: Maybe Pixels
                     } deriving (Show, Generic)

makeLenses ''InputConfig

data Config = Config { _configPgConnection       :: Text
                     , _configPgPoolSize         :: Int
                     , _configPgTimeout          :: NominalDiffTime
                     , _configMapnikInputPlugins :: FilePath
                     , _configPort               :: Int
                     , _configLayers             :: M.Map Text Layer
                     , _configTileBuffer         :: Pixels
                     } deriving (Show, Generic)

makeLenses ''Config

emptyInputConfig :: InputConfig
emptyInputConfig = InputConfig "" Nothing Nothing Nothing Nothing (fromList []) Nothing

instance FromJSON InputConfig where
  parseJSON (Object o) =
       InputConfig <$> o .: "db-connection" <*> o .:? "db-pool-size" <*> o .:? "db-timeout" <*>
          o .:? "mapnik-input-plugins" <*> o .:? "port" <*> o .: "layers" <*> (fmap . fmap) Pixels (o .:? "tile-buffer")
  parseJSON _ = Control.Applicative.empty

instance ToJSON Config where
  toJSON c = object
    [
      ("db-connection" .= _configPgConnection c),
      ("db-pool-size" .= _configPgPoolSize c),
      ("db-timeout" .= _configPgTimeout c),
      ("mapnik-input-plugins" .= _configMapnikInputPlugins c),
      ("port" .= _configPort c),
      ("layers" .= _configLayers c),
      ("tile-buffer" .= _configTileBuffer c)
    ]

instance ToJSON InputConfig where
  toJSON ic = object $ catMaybes
    [
      ("db-connection" .=) <$> Just (_inputConfigPgConnection ic),
      ("db-pool-size" .=) <$> _inputConfigPgPoolSize ic,
      ("db-timeout" .=) <$> _inputConfigPgTimeout ic,
      ("mapnik-input-plugins" .=) <$> _inputConfigMapnikInputPlugins ic,
      ("port" .=) <$> _inputConfigPort ic,
      ("layers" .=) <$> Just (_inputConfigLayers ic),
      ("tile-buffer" .=) <$> Just (_inputConfigTileBuffer ic)
    ]

instance ToJSON Layer where
  toJSON l = object
    [  "query" .= _layerQuery l,
       "last-modified" .= _layerLastModified l
    ]

data ServerState = ServerState { _ssPool           :: P.Pool
                               , _ssPluginDir      :: FilePath
                               , _ssConfigFile     :: FilePath
                               , _ssOriginalConfig :: Config
                               , _ssStateLayers    :: STM.Map Text Layer
                               }
makeLenses ''ServerState

ssBuffer :: Lens' ServerState Pixels
ssBuffer = ssOriginalConfig . configTileBuffer

newtype TileFeature = TileFeature { unTileFeature :: Value } deriving (Show, Eq)

mkGeoJSON :: [TileFeature] -> GeoJson
mkGeoJSON tfs = M.fromList [ ("type", String "FeatureCollection")
                           , ("features", toJSON . fmap unTileFeature $ tfs)
                           ]

err204 :: ServantErr
err204 = ServantErr { errHTTPCode = 204
                    , errReasonPhrase = "No Content"
                    , errBody = ""
                    , errHeaders = []
                    }

data AlreadyJSON deriving Typeable

instance Accept AlreadyJSON where
    contentType _ = "application" HM.// "json"

instance MimeRender AlreadyJSON Data.ByteString.Lazy.ByteString where
    mimeRender _ = id

instance MimeRender AlreadyJSON BS.ByteString where
    mimeRender _ = fromStrict

data MapboxVectorTile deriving Typeable

instance Accept MapboxVectorTile where
    contentType _ = "application" HM.// "vnd.mapbox-vector-tile"

instance MimeRender MapboxVectorTile Data.ByteString.Lazy.ByteString where
    mimeRender _ = id

instance MimeRender MapboxVectorTile BS.ByteString where
    mimeRender _ = fromStrict
