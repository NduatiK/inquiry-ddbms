module Pages.Queries exposing (Model, Msg, init, update, view)

import Element exposing (..)
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
import Style exposing (edges)


type alias Model =
    {}


init : ( Model, Cmd msg )
init =
    ( {}
    , Cmd.none
    )



-- UPDATE


type Msg
    = NoOp


update : msg -> model -> ( model, Cmd msg )
update msg model =
    ( model, Cmd.none )



-- VIEW


view : Model -> Element msg
view model =
    Element.column
        [ width fill, spacing 40, paddingXY 24 8 ]
        [ viewHeading "Home" Nothing
        , el [] (text "Welcome")
        ]


viewHeading : String -> Maybe String -> Element msg
viewHeading title subLine =
    Element.column
        [ width fill ]
        [ el
            Style.headerStyle
            (text title)
        , case subLine of
            Nothing ->
                none

            Just caption ->
                el Style.captionStyle (text caption)
        ]
