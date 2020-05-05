module Api exposing (..)

import Api.Endpoint as Endpoint exposing (Endpoint)
import Http exposing (Body)
import Json.Decode as Decode exposing (Decoder, Value, bool, decodeString, dict, field, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, requiredAt, resolve)
import Json.Encode as Encode
import Models.Location exposing (Location, locationDecoder)
import RemoteData exposing (RemoteData(..), WebData)


get : Endpoint -> Decoder a -> Cmd (WebData a)
get url decoder =
    Endpoint.get url decoder


post : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
post url body decoder =
    Endpoint.post url body decoder


patch : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
patch url body decoder =
    Endpoint.patch url body decoder
