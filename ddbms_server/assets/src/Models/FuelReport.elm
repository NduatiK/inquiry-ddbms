module Models.FuelReport exposing
    ( FuelReport
    , fuelRecordDecoder
    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Time


type alias FuelReport =
    { id : Int
    , cost : Int
    , volume : Float
    , distance_covered : Int
    , date : Time.Posix
    }


fuelRecordDecoder : Decoder FuelReport
fuelRecordDecoder =
    let
        decoder id cost volume distance_covered dateTimeString =
            case Iso8601.toTime dateTimeString of
                Result.Ok dateTime ->
                    Decode.succeed
                        { id = id
                        , cost = cost
                        , volume = volume
                        , distance_covered = distance_covered
                        , date = dateTime
                        }

                Result.Err _ ->
                    Decode.fail (dateTimeString ++ " cannot be decoded to a date")
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "cost" int
        |> required "volume" float
        |> required "distance_travelled" int
        |> required "date" string
        |> resolve
