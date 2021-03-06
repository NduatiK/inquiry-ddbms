module Page exposing (frame, transformToModelMsg)

import Element exposing (..)
import Element.Background as Background
import Navigation exposing (Route)
import Template.NavBar exposing (viewHeader)


{-| Transforms a pages (model, msg) into another page's (model, msg)

    Used to transform child pages into parent types.

-}
transformToModelMsg : (subModel -> model) -> (subMsg -> msg) -> ( subModel, Cmd subMsg ) -> ( model, Cmd msg )
transformToModelMsg toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


frame : Element a -> (a -> msg) -> Maybe Route -> Element msg
frame body toMsg route =
    let
        renderedBody =
            row [ height fill, width fill ]
                [ el [ height fill, width (px 1), Background.color (rgba 0 0 0 0.2) ] none
                , el
                    [ width fill
                    , alignTop
                    , height fill
                    , scrollbarY
                    ]
                    (Element.map toMsg body)
                ]
    in
    column [ width fill, height fill ]
        [ viewHeader route
        , renderedBody
        ]
