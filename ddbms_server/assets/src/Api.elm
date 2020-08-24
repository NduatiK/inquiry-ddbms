module Api exposing (get, patch, post)

import Api.Endpoint as Endpoint exposing (Endpoint)
import Http exposing (Body)
import Json.Decode exposing (Decoder)
import RemoteData exposing (WebData)


get : Endpoint -> Decoder a -> Cmd (WebData a)
get url decoder =
    Endpoint.get url decoder


post : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
post url body decoder =
    Endpoint.post url body decoder


patch : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
patch url body decoder =
    Endpoint.patch url body decoder
