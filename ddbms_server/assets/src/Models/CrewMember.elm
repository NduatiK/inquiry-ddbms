module Models.CrewMember exposing (Change(..), CrewMember, Role(..), applyChanges, crewDecoder, encodeChanges, roleToString, trimChanges)

import Http
import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode exposing (encode)


type alias CrewMember =
    { id : Int
    , name : String
    , role : Role
    , email : String
    , phoneNumber : String
    , bus : Maybe Int
    }


type Role
    = Driver
    | Assistant


roleToString : Role -> String
roleToString role =
    case role of
        Driver ->
            "Driver"

        Assistant ->
            "Assistant"


crewDecoder : Decoder CrewMember
crewDecoder =
    let
        decoder id name role_ email phoneNumber bus =
            let
                crewMember =
                    let
                        role =
                            case role_ of
                                "driver" ->
                                    Driver

                                _ ->
                                    Assistant
                    in
                    CrewMember id name role email phoneNumber bus
            in
            Decode.succeed crewMember
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "name" string
        |> required "role" string
        |> required "email" string
        |> required "phone_number" string
        |> required "bus_id" (nullable int)
        |> Json.Decode.Pipeline.resolve


{-| Changes
Bus

  - Add the member onto a role
  - Remove the member on a role
  - Change the member on a role
    • Remove member 1
    • Add member 2

Member

  - Add to bus
  - Remove from bus
  - Move bus 1 from Bus A to B
    • Remove 1 from Bus A
    • Remove 2 from Bus B (if necessary)
    • Add 1 to Bus B

-}
type Change
    = Add Int Int
    | Remove Int Int


applyChanges : List Change -> { a | crew : List CrewMember } -> { a | crew : List CrewMember }
applyChanges changes data =
    List.foldl
        (\change editedData ->
            let
                crew =
                    case change of
                        Add crewMember_id bus ->
                            List.map
                                (\c ->
                                    if crewMember_id == c.id then
                                        { c | bus = Just bus }

                                    else
                                        c
                                )
                                editedData.crew

                        Remove crewMember_id _ ->
                            List.map
                                (\c ->
                                    if crewMember_id == c.id then
                                        { c | bus = Nothing }

                                    else
                                        c
                                )
                                editedData.crew
            in
            { editedData | crew = crew }
        )
        data
        (List.reverse changes)


trimChanges : { a | crew : List CrewMember } -> { a | crew : List CrewMember } -> List Change
trimChanges dataOld dataNew =
    let
        zipped =
            List.map2 Tuple.pair dataOld.crew dataNew.crew

        changes =
            zipped
                |> List.filter (\( old, new ) -> old.bus /= new.bus)
                |> List.map
                    (\( old, new ) ->
                        case ( old.bus, new.bus ) of
                            ( Nothing, Just bus ) ->
                                [ Add new.id bus ]

                            ( Just bus, Nothing ) ->
                                [ Remove new.id bus ]

                            ( Just bus1, Just bus2 ) ->
                                [ Add new.id bus2, Remove new.id bus1 ]

                            _ ->
                                []
                    )
                |> List.concat
    in
    changes


encodeChanges : List Change -> Http.Body
encodeChanges changes =
    let
        objectEncoder change =
            Encode.object
                [ ( "change", Encode.string (changeToString change) )
                , ( "bus", Encode.int (changeToBusID change) )
                , ( "crew_member", Encode.int (changeToCrewID change) )
                ]
    in
    Encode.list objectEncoder changes
        |> Http.jsonBody


changeToString : Change -> String
changeToString change =
    case change of
        Add _ _ ->
            "add"

        Remove _ _ ->
            "remove"


changeToBusID : Change -> Int
changeToBusID change =
    case change of
        Add _ bus_id ->
            bus_id

        Remove _ bus_id ->
            bus_id


changeToCrewID : Change -> Int
changeToCrewID change =
    case change of
        Add crew_id _ ->
            crew_id

        Remove crew_id _ ->
            crew_id
