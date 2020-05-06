module Pages.Queries exposing (Model, Msg, init, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Browser.Dom
import Colors
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import Html.Events exposing (..)
import Http
import Icons
import Json.Decode as Decode
import Ports
import Style exposing (edges)
import StyledElement
import Task


type alias Model =
    { receivedMessages : List String
    , scriptText : String
    }


init : ( Model, Cmd msg )
init =
    ( { receivedMessages = []
      , scriptText = ""
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = NoOp
    | ReceivedMessage String
    | ChangedScript String
    | Reset


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedMessage message ->
            ( { model
                | receivedMessages =
                    model.receivedMessages
                        ++ [ message
                           ]
              }
            , Browser.Dom.getViewportOf consoleId
                |> Task.andThen (.scene >> .height >> Browser.Dom.setViewportOf consoleId 0)
                |> Task.onError (\_ -> Task.succeed ())
                |> Task.perform (\_ -> NoOp)
            )

        ChangedScript script ->
            if String.endsWith "\n" script then
                ( { model | scriptText = "" }, Ports.sendQuery (String.replace "\"" "²" script) )

            else
                ( { model | scriptText = script }, Cmd.none )

        Reset ->
            ( { model | receivedMessages = [] }
            , resetDBs model
            )



-- VIEW


consoleId =
    "consoleId"


someData =
    ""


view : Model -> Element Msg
view model =
    Element.column
        [ width fill, height fill, spacing 40, paddingXY 24 8, Style.monospace ]
        [ viewHeading "InQuery"
        , el
            [ Background.color Colors.darkness
            , width fill
            , height fill
            , height (fill |> maximum 400)
            , Font.color Colors.white
            , Style.monospace
            , above
                (el
                    [ Background.color Colors.white
                    , Font.color Colors.darkness
                    , padding 4
                    , moveRight 12
                    , moveDown 16
                    , Font.size 17
                    , Border.color Colors.darkness
                    , Border.width 1
                    ]
                    (text "Output")
                )
            , paddingXY 10 20
            ]
            (el
                [ scrollbarY
                , width fill
                , height fill
                , htmlAttribute (Html.Attributes.id consoleId)
                , htmlAttribute (Html.Attributes.style "scroll-behavior" "smooth")
                ]
                (textColumn [ spacing 0, width fill ]
                    (List.map
                        (\x ->
                            paragraph
                                ([ paddingXY 20 0
                                 , width fill
                                 ]
                                    ++ (if String.startsWith "⧱" x then
                                            [ Font.color Colors.errorRed
                                            , paddingXY 20 10
                                            , Background.color Colors.white
                                            ]

                                        else
                                            [ Font.color Colors.white
                                            , Background.color Colors.transparent
                                            ]
                                       )
                                )
                                [ text (String.replace "⧱" "" x)
                                ]
                        )
                        (someData :: model.receivedMessages)
                    )
                )
            )
        , el
            [ Background.color Colors.white
            , width fill
            , height (fill |> maximum 200)
            , Font.color Colors.darkness
            , Style.monospace
            , Border.color Colors.darkness
            , Border.width 1
            , above
                (el
                    [ Background.color Colors.white
                    , Font.color Colors.darkness
                    , padding 4
                    , moveRight 12
                    , moveDown 12
                    , Font.size 17
                    ]
                    (text "Shell")
                )
            , paddingXY 10 20
            , height (px 150)
            ]
            (StyledElement.multilineInput
                [ Style.monospace
                ]
                { ariaLabel = ""
                , caption = Nothing
                , errorCaption = Nothing
                , icon = Nothing
                , onChange = ChangedScript
                , placeholder = Just (Input.placeholder [] (text "Enter your script"))
                , title = ""
                , value = model.scriptText
                }
            )
        , text "select * from tbl;"
        , text "insert into tbl (id, age, name) values (2, 1,\"tom\");"
        , text "insert into tbl (age, dept, name, salary) values (20, \"IM\",\"tom\",20000);"
        , text "insert into tbl (age, dept, name, salary) values (20, \"IM\",\"tom\",10000);"
        , text "insert into tbl (age, dept, name, salary) values (20, \"IM\",\"tom\",8000);"

        --         , el [] (text
        ]


viewHeading : String -> Element Msg
viewHeading title =
    Element.row
        [ width fill ]
        [ el Style.headerStyle (text title)
        , el [ centerX, centerY, width fill ]
            (StyledElement.ghostButton [ Border.color Colors.errorRed, alignRight, Font.color Colors.errorRed ]
                { title = "Reset DB"
                , icon = Icons.trash
                , onPress = Just Reset
                }
            )
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Ports.receivedMessage ReceivedMessage ]


resetDBs : Model -> Cmd Msg
resetDBs model =
    Api.post Endpoint.reset Http.emptyBody decoder
        |> Cmd.map (always NoOp)


decoder =
    Decode.succeed ()
