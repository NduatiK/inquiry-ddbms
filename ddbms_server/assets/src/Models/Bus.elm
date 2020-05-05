module Models.Bus exposing
    ( Bus
    , Device
    , FuelType(..)
    , LocationUpdate
    , Part(..)
    , Repair
    , SimpleRoute
    , VehicleClass(..)
    , VehicleType(..)
    , busDecoder
    , busDecoderWithCallback
    , defaultConsumption
    , defaultSeats
    , imageForPart
    , simpleRouteDecoder
    , titleForPart
    , vehicleClassToFuelType
    , vehicleClassToType
    , vehicleTypeToIcon
    , vehicleTypeToString
    )

import Element
import Icons
import Icons.Repairs
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Location exposing (Location, locationDecoder)
import Time


type VehicleClass
    = VehicleClass VehicleType FuelType


type FuelType
    = Gasoline
    | Diesel


type alias Bus =
    { id : Int
    , numberPlate : String
    , seatsAvailable : Int
    , vehicleClass : VehicleClass
    , statedMilage : Float
    , route : Maybe SimpleRoute
    , device : Maybe Device
    , repairs : List Repair
    , last_seen : Maybe LocationUpdate
    }


type alias SimpleRoute =
    { id : Int
    , name : String
    , busID : Maybe Int
    }


type alias Device =
    String


type alias LocationUpdate =
    { bus : Int
    , location : Location
    , speed : Float
    , bearing : Float
    }



-- type alias Student =
--     { id : String
--     , name : String
--     }


type VehicleType
    = Van
    | Shuttle
    | SchoolBus


vehicleTypeToString : VehicleType -> String
vehicleTypeToString vehicleType =
    case vehicleType of
        Van ->
            "van"

        Shuttle ->
            "shuttle"

        SchoolBus ->
            "bus"


type alias Repair =
    { id : Int
    , part : Part
    , description : String
    , cost : Int
    , dateTime : Time.Posix
    }


type Part
    = FrontLeftTire
    | FrontRightTire
    | RearLeftTire
    | RearRightTire
    | Engine
    | FrontCrossAxis
    | RearCrossAxis
    | VerticalAxis


imageForPart : Part -> List (Element.Attribute msg) -> Element.Element msg
imageForPart part =
    case part of
        VerticalAxis ->
            Icons.Repairs.verticalAxisRepair

        Engine ->
            Icons.Repairs.engineRepair

        FrontLeftTire ->
            Icons.Repairs.frontLeftTireRepair

        FrontRightTire ->
            Icons.Repairs.frontRightTireRepair

        RearLeftTire ->
            Icons.Repairs.rearLeftTireRepair

        RearRightTire ->
            Icons.Repairs.rearRightTireRepair

        FrontCrossAxis ->
            Icons.Repairs.frontCrossAxisRepair

        RearCrossAxis ->
            Icons.Repairs.rearCrossAxisRepair


toPart : String -> Part
toPart partString =
    case partString of
        "Front Left Tire" ->
            FrontLeftTire

        "Front Right Tire" ->
            FrontRightTire

        "Rear Left Tire" ->
            RearLeftTire

        "Rear Right Tire" ->
            RearRightTire

        "Front Cross Axis" ->
            FrontCrossAxis

        "Rear Cross Axis" ->
            RearCrossAxis

        "Vertical Axis" ->
            VerticalAxis

        _ ->
            Engine


titleForPart : Part -> String
titleForPart part =
    case part of
        FrontLeftTire ->
            "Front Left Tire"

        FrontRightTire ->
            "Front Right Tire"

        RearLeftTire ->
            "Rear Left Tire"

        RearRightTire ->
            "Rear Right Tire"

        Engine ->
            "Engine"

        FrontCrossAxis ->
            "Front Cross Axis"

        RearCrossAxis ->
            "Rear Cross Axis"

        VerticalAxis ->
            "Vertical Axis"


busDecoderWithCallback : (Bus -> a) -> Decoder a
busDecoderWithCallback callback =
    let
        busDataDecoder id number_plate seats_available vehicle_type fuel_type stated_milage route device repairs update =
            let
                bus =
                    let
                        lastSeen =
                            Maybe.andThen
                                (\update_ ->
                                    Just (LocationUpdate id update_.location update_.speed update_.bearing)
                                )
                                update

                        fuelType =
                            case fuel_type of
                                "diesel" ->
                                    Diesel

                                _ ->
                                    Gasoline

                        vehicleType =
                            case vehicle_type of
                                "van" ->
                                    Van

                                "shuttle" ->
                                    Shuttle

                                _ ->
                                    SchoolBus
                    in
                    Bus id number_plate seats_available (VehicleClass vehicleType fuelType) stated_milage route device repairs lastSeen
            in
            Decode.succeed (callback bus)
    in
    Decode.succeed busDataDecoder
        |> required "id" int
        |> required "number_plate" string
        |> required "seats_available" int
        |> required "vehicle_type" string
        |> required "fuel_type" string
        |> required "stated_milage" float
        |> required "route" (nullable simpleRouteDecoder)
        |> required "device" (nullable string)
        |> required "performed_repairs" (list repairDecoder)
        |> required "last_seen" (nullable locationUpdateDecoder)
        |> resolve


busDecoder : Decoder Bus
busDecoder =
    busDecoderWithCallback identity


simpleRouteDecoder : Decoder SimpleRoute
simpleRouteDecoder =
    Decode.succeed SimpleRoute
        |> required "id" int
        |> required "name" string
        |> optional "bus_id" (nullable int) Nothing


repairDecoder : Decoder Repair
repairDecoder =
    let
        decoder id part description cost dateTimeString =
            case Iso8601.toTime dateTimeString of
                Result.Ok dateTime ->
                    Decode.succeed
                        { id = id
                        , part = toPart part
                        , description = description
                        , cost = cost
                        , dateTime = dateTime
                        }

                Result.Err _ ->
                    Decode.fail (dateTimeString ++ " cannot be decoded to a date")
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "part" string
        |> required "description" string
        |> required "cost" int
        |> required "time" string
        |> resolve


locationUpdateDecoder : Decoder LocationUpdate
locationUpdateDecoder =
    Decode.succeed LocationUpdate
        |> Json.Decode.Pipeline.hardcoded 0
        |> required "location" locationDecoder
        |> required "speed" float
        |> required "bearing" float


defaultConsumption : VehicleClass -> Float
defaultConsumption vehicleClass =
    case vehicleClass of
        VehicleClass Van Gasoline ->
            7.4

        VehicleClass Van Diesel ->
            8.1

        VehicleClass Shuttle Gasoline ->
            3.3

        VehicleClass Shuttle Diesel ->
            3.3

        VehicleClass SchoolBus Gasoline ->
            2.7

        VehicleClass SchoolBus Diesel ->
            3.0


defaultSeats : VehicleClass -> Int
defaultSeats vehicleClass =
    case vehicleClass of
        VehicleClass Van _ ->
            12

        VehicleClass Shuttle _ ->
            24

        VehicleClass SchoolBus _ ->
            48


vehicleClassToType : VehicleClass -> VehicleType
vehicleClassToType class =
    case class of
        VehicleClass vehicleType _ ->
            vehicleType


vehicleClassToFuelType : VehicleClass -> FuelType
vehicleClassToFuelType class =
    case class of
        VehicleClass _ fuelType ->
            fuelType


vehicleTypeToIcon : VehicleType -> Icons.IconBuilder msg
vehicleTypeToIcon vehicleType =
    case vehicleType of
        Van ->
            Icons.van

        Shuttle ->
            Icons.shuttle

        SchoolBus ->
            Icons.bus
