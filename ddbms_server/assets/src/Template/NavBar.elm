module Template.NavBar exposing (maxHeight, viewHeader)

import Api
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Region as Region
import Navigation exposing (Route)
import StyledElement


maxHeight : Int
maxHeight =
    70


viewHeader : Maybe Route -> Element msg
viewHeader route =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.14 }
        , height (px maxHeight)
        ]
        [ row [ paddingXY 24 12, spacing 10, width fill ]
            [ if route == Just Navigation.Setup then
                StyledElement.hoverLink [ alignLeft ]
                    { title = "Done", route = Navigation.Queries, rotation = pi / 2 }

              else
                StyledElement.hoverLink [ alignRight ]
                    { title = "Setup", route = Navigation.Setup, rotation = -pi / 2 }
            ]
        ]
