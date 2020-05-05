module Colors exposing (..)

import Color
import Element exposing (..)
import Element.Background as Background
import Html.Attributes



-- COLORS


toSVGColor : Color -> Color.Color
toSVGColor color =
    let
        { red, green, blue } =
            toRgb color
    in
    Color.rgb red green blue


withGradient : Float -> Color -> Attr decorative msg
withGradient radius color =
    Background.gradient
        { angle = radius
        , steps = [ color, withAlpha color 0, withAlpha color 0 ]
        }


withAlpha : Color -> Float -> Color
withAlpha color alpha =
    let
        { red, green, blue } =
            toRgb color
    in
    rgba red green blue alpha


semiDarkText : Color
semiDarkText =
    withAlpha (rgb255 4 30 37) 0.69


transparent : Color
transparent =
    Element.rgba 0 0 0 0


black : Color
black =
    Element.rgb 0 0 0


white : Color
white =
    Element.rgb 1 1 1


purple : Color
purple =
    Element.rgb255 89 79 238


simpleGrey : Color
simpleGrey =
    Element.rgb255 224 224 224


sassyGrey : Color
sassyGrey =
    Element.rgb255 163 175 190


sassyGreyDark : Color
sassyGreyDark =
    Element.rgb255 130 140 152


teal : Color
teal =
    Element.rgb255 102 218 213


darkGreen : Color
darkGreen =
    Element.rgb255 30 165 145


backgroundGreen : Color
backgroundGreen =
    Element.rgba255 30 165 145 0.7


darkText : Color
darkText =
    Element.rgb255 4 31 38


darkness : Color
darkness =
    Element.rgb255 51 63 78


errorRed : Color
errorRed =
    Element.rgb255 200 0 0


fillPurple : Attribute msg
fillPurple =
    Html.Attributes.style "filter" "brightness(0) saturate(100%) invert(24%) sepia(97%) saturate(1937%) hue-rotate(235deg) brightness(97%) contrast(93%)"
        |> htmlAttribute


fillWhite : Attribute msg
fillWhite =
    Html.Attributes.style "filter" "brightness(100%) saturate(0) invert(1)"
        |> htmlAttribute


fillDarkGreen : Attribute msg
fillDarkGreen =
    Html.Attributes.style "filter" "invert(59%) sepia(40%) saturate(342%) hue-rotate(114deg) brightness(93%) contrast(88%)"
        |> htmlAttribute


fillErrorRed : Attribute msg
fillErrorRed =
    Html.Attributes.style "filter" "invert(41%) sepia(141%) saturate(396%) hue-rotate(294deg) brightness(74%) contrast(121%)"
        |> htmlAttribute
