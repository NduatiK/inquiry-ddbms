module Api.Endpoint exposing
    ( Endpoint
    , get
    , patch
    , post
    , reset
    , setup
    )

import Http exposing (Body)
import Json.Decode exposing (Decoder)
import RemoteData exposing (RemoteData(..), WebData)
import Url.Builder exposing (QueryParameter, int)


type Endpoint
    = Endpoint String


get : Endpoint -> Decoder a -> Cmd (WebData a)
get endpoint decoder =
    Http.request
        { method = "GET"
        , headers = []
        , url = unwrap endpoint
        , body = Http.emptyBody
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest


post : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
post endpoint body decoder =
    Http.request
        { method = "POST"
        , headers = []
        , url = unwrap endpoint
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest


patch : Endpoint -> Body -> Decoder a -> Cmd (WebData a)
patch endpoint body decoder =
    Http.request
        { method = "PATCH"
        , headers = []
        , url = unwrap endpoint
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest



-- ENDPOINTS
-- login : Endpoint
-- login =
--     url [ "auth", "manager", "login" ] []


setup : Endpoint
setup =
    url [ "setup" ] []


reset : Endpoint
reset =
    url [ "reset" ] []



-- PRIVATE


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    Url.Builder.absolute ("api" :: paths) queryParams
        |> Endpoint
