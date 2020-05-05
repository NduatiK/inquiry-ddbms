port module Models.Location exposing
    ( Location
    , clearSchoolLocation
    , locationDecoder
    , storeSchoolLocation
    )

import Json.Decode as Decode exposing (Decoder, float)
import Json.Decode.Pipeline exposing (required)


port setSchoolLocation : Maybe Location -> Cmd msg


storeSchoolLocation : Location -> Cmd msg
storeSchoolLocation location =
    setSchoolLocation (Just location)


clearSchoolLocation : Cmd msg
clearSchoolLocation =
    setSchoolLocation Nothing


type alias Location =
    { lng : Float
    , lat : Float
    }


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "lng" float
        |> required "lat" float
