module StyledElement.Footer exposing (coloredView, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Input as Input
import Style exposing (..)
import StyledElement exposing (textStack)


view : page -> (page -> String) -> List ( page, String, msg ) -> Element msg
view currentPage pageToString tabs =
    let
        mappedTabs =
            List.map (\( page, body, action ) -> { page = page, body = body, action = action, highlightColor = Colors.darkGreen }) tabs
    in
    coloredView currentPage pageToString mappedTabs


coloredView : page -> (page -> String) -> List { a | page : page, body : String, action : msg, highlightColor : Color } -> Element msg
coloredView currentPage pageToString tabs =
    let
        renderFooterChild { page, body, action, highlightColor } =
            footerChild highlightColor currentPage pageToString page body action

        paddedTabViews =
            if List.length tabs >= 3 then
                List.map renderFooterChild tabs

            else
                List.map renderFooterChild tabs ++ [ el [ width (fill |> maximum 10) ] none ]
    in
    column
        [ width fill
        , spacing 0
        ]
        [ el [ width fill, height (px 2), Background.color Colors.semiDarkText ] none
        , row
            [ spaceEvenly
            , width fill
            ]
            paddedTabViews
        ]


footerChild : Color -> page -> (page -> String) -> page -> String -> msg -> Element msg
footerChild highlightColor currentPage pageToString page body action =
    Input.button [ alignTop, width (fill |> maximum 190) ]
        { label =
            column
                [ width fill
                ]
                [ el
                    [ height (px 16)
                    , Style.animatesAll
                    , Background.color
                        (if pageToString currentPage == pageToString page then
                            highlightColor

                         else
                            Colors.transparent
                        )
                    , width (fill |> maximum 190)
                    ]
                    none
                , StyledElement.textStackWithColor (pageToString page) body highlightColor
                ]
        , onPress = Just action
        }
