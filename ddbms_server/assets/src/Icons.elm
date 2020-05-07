module Icons exposing (..)

import Element exposing (Attribute, Element, alpha, height, image, px, width)
import Html.Attributes


type alias IconBuilder msg =
    List (Attribute msg) -> Element msg


iconNamed : String -> List (Attribute msg) -> Element msg
iconNamed name attrs =
    image (alpha 0.54 :: Element.htmlAttribute (Html.Attributes.style "pointer-events" "none") :: attrs)
        { src = name, description = "" }


chevronDown : List (Attribute msg) -> Element msg
chevronDown =
    iconNamed "images/chevron_down.svg"


loading : List (Attribute msg) -> Element msg
loading attrs =
    iconNamed "images/loading.svg" (width (px 48) :: height (px 48) :: attrs)


add : List (Attribute msg) -> Element msg
add attrs =
    iconNamed "images/add.svg" (width (px 24) :: height (px 24) :: attrs)


trash : List (Attribute msg) -> Element msg
trash attrs =
    iconNamed "images/trash.svg" (width (px 24) :: height (px 24) :: attrs)
