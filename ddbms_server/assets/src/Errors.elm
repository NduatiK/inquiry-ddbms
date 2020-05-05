module Errors exposing
    ( Errors(..)
    , InputError(..)
    , containsErrorFor
    , customInputErrorsFor
    , decodeErrors
    , errorToString
    , handleError
    , inputErrorsFor
    , toClientSideError
    , toClientSideErrors
    , toServerSideErrors
    )

import Api
import Dict
import Element exposing (..)
import Html.Attributes exposing (id)
import Http
import Json.Decode as Decode exposing (Decoder, decodeString, dict, list, string)
import Navigation
import Style exposing (..)


type InputError
    = InputError (List String)


type alias FieldName =
    String


type Errors internalError
    = ClientSideError internalError String
    | ServerSideError FieldName (List String)


{-| customInputErrorsFor formProblems fieldName visibleName errorsToMatch
-}
customInputErrorsFor : List (Errors clientError) -> String -> String -> List clientError -> Maybe InputError
customInputErrorsFor formProblems fieldName visibleName errorsToMatch =
    let
        clientSideErrors =
            List.map (\x -> ClientSideError x "") errorsToMatch
    in
    Maybe.map InputError
        (errorWhenContains
            clientSideErrors
            formProblems
            fieldName
            visibleName
        )


inputErrorsFor : List (Errors clientError) -> String -> List clientError -> Maybe InputError
inputErrorsFor formProblems fieldName errorsToMatch =
    customInputErrorsFor formProblems fieldName fieldName errorsToMatch


toClientSideError : ( a, String ) -> Errors a
toClientSideError problem =
    ClientSideError (Tuple.first problem) (Tuple.second problem)


toClientSideErrors : List ( a, String ) -> List (Errors a)
toClientSideErrors problems =
    List.map (\x -> ClientSideError (Tuple.first x) (Tuple.second x)) problems


toServerSideErrors : Http.Error -> List (Errors a)
toServerSideErrors formErrors =
    List.map (\x -> ServerSideError (Tuple.first x) (Tuple.second x)) (decodeFormErrors formErrors)


contains : Errors internalError -> List (Errors internalError) -> Bool
contains anError listOfErrors =
    List.any
        (\x ->
            case ( anError, x ) of
                ( ServerSideError aFieldName _, ServerSideError xFieldName _ ) ->
                    aFieldName == xFieldName

                ( ClientSideError aError _, ClientSideError xError _ ) ->
                    aError == xError

                _ ->
                    False
        )
        listOfErrors


errorWhenContains : List (Errors e) -> List (Errors e) -> String -> String -> Maybe (List String)
errorWhenContains matchFields formProblems fieldName visibleFieldName =
    let
        errorsForField =
            List.filter (\x -> contains x (ServerSideError fieldName [] :: matchFields)) formProblems

        beautifyError =
            \x ->
                case x of
                    ClientSideError _ string ->
                        [ string ]

                    ServerSideError fieldName2 strings ->
                        List.map (\str -> "The " ++ String.replace "_" " " visibleFieldName ++ " " ++ str) strings
    in
    case List.concatMap beautifyError errorsForField of
        [] ->
            Nothing

        errorStrings ->
            Just errorStrings


containsErrorFor fields problems =
    List.any
        (\field ->
            contains (ServerSideError field []) problems
        )
        fields



--- API ERRORS


type NetworkError
    = Unauthorized
    | BadRequest String


handleError : NetworkError -> Cmd msg
handleError error =
    case error of
        Unauthorized ->
            Cmd.batch
                []

        _ ->
            Cmd.none


decodeErrors : Http.Error -> ( NetworkError, Cmd msg )
decodeErrors error =
    let
        networkError =
            case error of
                Http.BadStatus response ->
                    if response.status.code == 401 then
                        Unauthorized

                    else
                        BadRequest
                            (response.body
                                |> decodeString (Decode.at [ "errors", "detail" ] string)
                                |> Result.withDefault "Server error"
                            )

                _ ->
                    BadRequest "Server error"
    in
    ( networkError, handleError networkError )


decodeFormErrors : Http.Error -> List ( String, List String )
decodeFormErrors error =
    let
        fieldDecoder : Decoder (Dict.Dict String (List String))
        fieldDecoder =
            Decode.at [ "errors", "detail" ] (dict (list string))

        decodeField response =
            response.body
                |> decodeString fieldDecoder
    in
    case error of
        Http.BadStatus response ->
            case decodeField response of
                Result.Err _ ->
                    []

                Result.Ok dictionary ->
                    Dict.toList dictionary

        _ ->
            []


errorToString : NetworkError -> String
errorToString error =
    case error of
        Unauthorized ->
            "Invalid email or password"

        BadRequest errorText ->
            errorText
