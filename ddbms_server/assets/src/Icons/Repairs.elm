module Icons.Repairs exposing (..)

import Element exposing (..)
import Html.Attributes
import Style exposing (edges)


type alias IconBuilder msg =
    List (Attribute msg) -> Element msg


iconNamed : String -> List (Attribute msg) -> Element msg
iconNamed name attrs =
    image attrs
        { src = name, description = "" }


chassis : List (Attribute msg) -> Element msg
chassis attrs =
    iconNamed "images/repairs/chassis.svg" (Element.htmlAttribute (Html.Attributes.style "pointer-events" "none") :: attrs)


engine : List (Attribute msg) -> Element msg
engine attrs =
    iconNamed "images/repairs/engine.svg" (centerX :: Element.htmlAttribute (Html.Attributes.style "pointer-events" "none") :: alignTop :: attrs)


frontLeftTireRepair : List (Attribute msg) -> Element msg
frontLeftTireRepair attrs =
    iconNamed "images/repairs/repair/front_left_tire_repair.svg" (alignLeft :: attrs)


frontRightTireRepair : List (Attribute msg) -> Element msg
frontRightTireRepair attrs =
    iconNamed "images/repairs/repair/front_right_tire_repair.svg" (alignRight :: attrs)


rearLeftTireRepair : List (Attribute msg) -> Element msg
rearLeftTireRepair attrs =
    iconNamed "images/repairs/repair/rear_left_tire_repair.svg" (alignBottom :: alignLeft :: attrs)


rearRightTireRepair : List (Attribute msg) -> Element msg
rearRightTireRepair attrs =
    iconNamed "images/repairs/repair/rear_right_tire_repair.svg" (alignBottom :: alignRight :: attrs)


engineRepair : List (Attribute msg) -> Element msg
engineRepair attrs =
    iconNamed "images/repairs/repair/engine_repair.svg" (paddingEach { edges | top = 73 } :: centerX :: alignTop :: attrs)


frontCrossAxisRepair : List (Attribute msg) -> Element msg
frontCrossAxisRepair attrs =
    iconNamed "images/repairs/repair/front_cross_axis_repair.svg" (centerX :: alignTop :: attrs)


rearCrossAxisRepair : List (Attribute msg) -> Element msg
rearCrossAxisRepair attrs =
    iconNamed "images/repairs/repair/rear_cross_axis_repair.svg" (centerX :: alignBottom :: attrs)


verticalAxisRepair : List (Attribute msg) -> Element msg
verticalAxisRepair attrs =
    iconNamed "images/repairs/repair/vertical_axis_repair.svg" (centerX :: centerY :: attrs)
