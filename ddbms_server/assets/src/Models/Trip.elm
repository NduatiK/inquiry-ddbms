module Models.Trip exposing
    ( Report
    , StudentActivity
    , Trip
    ,  tripDecoder
       -- , busDecoderWithCallback

    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Location exposing (Location, locationDecoder)
import Time


type alias Trip =
    { id : Int
    , startTime : Time.Posix
    , endTime : Time.Posix
    , travelTime : String
    , reports : List Report
    , studentActivities : List StudentActivity
    , distanceCovered : Float
    }


type alias StudentActivity =
    { location : Location
    , time : Time.Posix
    , activity : String
    , student : Int
    , studentName : String
    }


type alias Report =
    { location : Location
    , time : Time.Posix
    }


tripDecoder : Decoder Trip
tripDecoder =
    let
        toDecoder : Int -> String -> String -> String -> List Report -> Float -> List StudentActivity -> Decoder Trip
        toDecoder id startDateString endDateString travelTime reports distanceCovered studentActivities =
            case ( Iso8601.toTime startDateString, Iso8601.toTime endDateString ) of
                ( Result.Ok startDate, Result.Ok endDate ) ->
                    Decode.succeed
                        { id = id
                        , startTime = startDate
                        , endTime = endDate
                        , travelTime = travelTime
                        , reports = List.reverse reports
                        , distanceCovered = distanceCovered
                        , studentActivities = studentActivities
                        }

                ( Result.Err _, _ ) ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")

                ( _, Result.Err _ ) ->
                    Decode.fail (endDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "id" int
        |> required "start_time" string
        |> required "end_time" string
        |> required "travel_time" string
        |> required "reports" (list reportDecoder)
        |> required "distance_covered" float
        |> required "student_activities" (list activityDecoder)
        |> resolve


reportDecoder : Decoder Report
reportDecoder =
    let
        toDecoder : Location -> String -> Decoder Report
        toDecoder location dateString =
            case Iso8601.toTime dateString of
                Result.Ok date ->
                    Decode.succeed (Report location date)

                Result.Err _ ->
                    Decode.fail (dateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "location" locationDecoder
        |> required "time" string
        |> resolve


activityDecoder : Decoder StudentActivity
activityDecoder =
    let
        toDecoder : Location -> String -> String -> Int -> String -> Decoder StudentActivity
        toDecoder location dateString activity student studentName =
            case Iso8601.toTime dateString of
                Result.Ok date ->
                    Decode.succeed (StudentActivity location date activity student studentName)

                Result.Err _ ->
                    Decode.fail (dateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "location" locationDecoder
        |> required "time" string
        |> required "activity" string
        |> required "student" int
        |> optional "student_name" string ""
        |> resolve



-- busDecoder : Decoder Bus
-- busDecoder =
--     busDecoderWithCallback identity
-- busDecoderWithCallback : (Bus -> a) -> Decoder a
-- busDecoderWithCallback callback =
--     let
--         busDataDecoder id number_plate seats_available vehicle_type stated_milage route device update =
--             let
--                 bus =
--                     let
--                         lastSeen =
--                             Maybe.andThen
--                                 (\update_ ->
--                                     Just (LocationUpdate id update_.location update_.speed update_.bearing)
--                                 )
--                                 update
--                         vehicleType =
--                             case vehicle_type of
--                                 "van" ->
--                                     Van
--                                 "shuttle" ->
--                                     Shuttle
--                                 _ ->
--                                     SchoolBus
--                     in
--                     Bus id number_plate seats_available vehicleType stated_milage route device lastSeen
--             in
--             Decode.succeed (callback bus)
--     in
--     Decode.succeed busDataDecoder
--         |> required "id" int
--         |> required "number_plate" string
--         |> required "seats_available" int
--         |> required "vehicle_type" string
--         |> required "stated_milage" float
--         |> required "route" (nullable routeDecoder)
--         |> required "device" (nullable string)
--         |> required "last_seen" (nullable locationUpdateDecoder)
--         |> Json.Decode.Pipeline.resolve
-- routeDecoder : Decoder Route
-- routeDecoder =
--     Decode.succeed Route
--         |> required "id" string
--         |> required "name" string
-- locationUpdateDecoder : Decoder LocationUpdate
-- locationUpdateDecoder =
--     Decode.succeed LocationUpdate
--         |> Json.Decode.Pipeline.hardcoded 0
--         |> required "location" locationDecoder
--         |> required "speed" float
--         |> required "bearing" float
