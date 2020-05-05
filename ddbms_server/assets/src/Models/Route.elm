module Models.Route exposing (Route, routeDecoder)

import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Models.Location exposing (Location, locationDecoder)


type alias Route =
    { id : Int
    , name : String
    , path : List Location
    , bus : Maybe SimpleBus
    }


type alias SimpleBus =
    { id : Int
    , numberPlate : String
    }


routeDecoder : Decoder Route
routeDecoder =
    Decode.succeed Route
        |> required "id" int
        |> required "name" string
        |> required "path" (list locationDecoder)
        |> required "bus" (nullable busDecoder)


busDecoder : Decoder SimpleBus
busDecoder =
    Decode.succeed SimpleBus
        |> required "id" int
        |> required "number_plate" string
