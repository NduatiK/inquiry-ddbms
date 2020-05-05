module Models.Household exposing
    ( Guardian
    , Household
    , Location
    , Student
    , TravelTime(..)
    , householdDecoder
    , studentByRouteDecoder
    , studentDecoder
    )

import Json.Decode as Decode exposing (Decoder, float, int, list, string, succeed)
import Json.Decode.Pipeline exposing (required, resolve)
import Models.Bus exposing (SimpleRoute, simpleRouteDecoder)
import Utils.GroupBy


type alias Household =
    { id : Int
    , route : Int
    , guardian : Guardian
    , homeLocation : Location
    , students : List Student
    }


type alias Guardian =
    { id : Int
    , name : String
    , phoneNumber : String
    , email : String
    }


type TravelTime
    = TwoWay
    | Morning
    | Evening


type alias Student =
    { id : Int
    , name : String
    , travelTime : TravelTime
    , homeLocation : Location
    , pickupLocation : Location
    , route : SimpleRoute
    }


type alias Location =
    { lng : Float
    , lat : Float
    }


studentByRouteDecoder : Decoder ( List ( String, List Student ), List Household )
studentByRouteDecoder =
    let
        decoder : List Household -> Decoder ( List ( String, List Student ), List Household )
        decoder households =
            let
                students =
                    List.concat (List.map .students households)
            in
            Decode.succeed
                ( Utils.GroupBy.attr
                    { groupBy = .route >> .name
                    , nameAs = .route >> .name
                    , reverse = False
                    }
                    students
                , households
                )
    in
    list householdDecoder
        |> Decode.andThen decoder


householdDecoder : Decoder Household
householdDecoder =
    let
        decoder id name email phoneNumber students =
            case List.head students of
                Just student ->
                    succeed (Household id student.route.id (Guardian id name phoneNumber email) student.homeLocation students)

                Nothing ->
                    Decode.fail "Expected more than one student"
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "name" string
        |> required "email" string
        |> required "phone_number" string
        |> required "students" (list studentDecoder)
        |> resolve


studentDecoder : Decoder Student
studentDecoder =
    let
        decoder id name travel_time home_location pickup_location route =
            let
                travelTime =
                    case travel_time of
                        "evening" ->
                            Evening

                        "morning" ->
                            Morning

                        _ ->
                            TwoWay
            in
            succeed (Student id name travelTime home_location pickup_location route)
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "name" string
        |> required "travel_time" string
        |> required "home_location" locationDecoder
        |> required "pickup_location" locationDecoder
        |> required "route" simpleRouteDecoder
        |> resolve


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "lng" float
        |> required "lat" float
