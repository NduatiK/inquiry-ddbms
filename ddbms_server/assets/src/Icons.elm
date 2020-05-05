module Icons exposing (..)

import Element exposing (Attribute, Element, alpha, height, image, px, width)
import Html.Attributes


type alias IconBuilder msg =
    List (Attribute msg) -> Element msg


iconNamed : String -> List (Attribute msg) -> Element msg
iconNamed name attrs =
    image (alpha 0.54 :: Element.htmlAttribute (Html.Attributes.style "pointer-events" "none") :: attrs)
        { src = name, description = "" }


bus : List (Attribute msg) -> Element msg
bus attrs =
    image
        -- ([ width <| px 437, height <| px 137 ]
        ([ width <| px 218, height <| px 68 ]
            ++ attrs
        )
        { src = "images/busOutlines/bus.svg", description = "" }


van : List (Attribute msg) -> Element msg
van attrs =
    image
        -- ([ width <| px 246, height <| px 113 ]
        ([ width <| px 123, height <| px 56 ]
            ++ attrs
        )
        { src = "images/busOutlines/van.svg", description = "" }


shuttle : List (Attribute msg) -> Element msg
shuttle attrs =
    image
        -- ([ width <| px 332, height <| px 126 ]
        ([ width <| px 176, height <| px 73 ]
            ++ attrs
        )
        { src = "images/busOutlines/shuttle.svg", description = "" }


qrBox : List (Attribute msg) -> Element msg
qrBox attrs =
    image
        ([ width <| px 506, height <| px 286 ]
            ++ attrs
        )
        { src = "images/qrBox.svg", description = "" }


add : List (Attribute msg) -> Element msg
add attrs =
    iconNamed "images/add.svg" (alpha 1 :: attrs)


print : List (Attribute msg) -> Element msg
print attrs =
    iconNamed "images/card.svg" (alpha 1 :: attrs)


edit : List (Attribute msg) -> Element msg
edit attrs =
    iconNamed "images/edit.svg" (alpha 1 :: attrs)


subtract : List (Attribute msg) -> Element msg
subtract attrs =
    iconNamed "images/subtract.svg" (alpha 1 :: attrs)


steeringWheel : List (Attribute msg) -> Element msg
steeringWheel attrs =
    iconNamed "images/stearing_wheel.svg" (alpha 1 :: attrs)


camera : List (Attribute msg) -> Element msg
camera attrs =
    iconNamed "images/camera.svg" (alpha 1 :: attrs)


cameraOff : List (Attribute msg) -> Element msg
cameraOff attrs =
    iconNamed "images/camera_off.svg" (alpha 1 :: attrs)


chevronDown : List (Attribute msg) -> Element msg
chevronDown =
    iconNamed "images/chevron_down.svg"


dashboard : List (Attribute msg) -> Element msg
dashboard =
    iconNamed "images/dashboard.svg"


filter : List (Attribute msg) -> Element msg
filter =
    iconNamed "images/filter.svg"


pin : List (Attribute msg) -> Element msg
pin =
    iconNamed "images/pin.svg"


seat : List (Attribute msg) -> Element msg
seat =
    iconNamed "images/seat.svg"


people : List (Attribute msg) -> Element msg
people =
    iconNamed "images/people.svg"


phone : List (Attribute msg) -> Element msg
phone =
    iconNamed "images/phone.svg"


email : List (Attribute msg) -> Element msg
email =
    iconNamed "images/email.svg"


show : List (Attribute msg) -> Element msg
show =
    iconNamed "images/show.svg"


trash : List (Attribute msg) -> Element msg
trash =
    iconNamed "images/trash.svg"


info : List (Attribute msg) -> Element msg
info =
    iconNamed "images/info.svg"


help : List (Attribute msg) -> Element msg
help =
    iconNamed "images/help.svg"


loading : List (Attribute msg) -> Element msg
loading attrs =
    iconNamed "images/loading.svg" (width (px 48) :: height (px 48) :: attrs)


timeline : List (Attribute msg) -> Element msg
timeline =
    iconNamed "images/timeline.svg"


repairs : List (Attribute msg) -> Element msg
repairs =
    iconNamed "images/repairs.svg"


hardware : List (Attribute msg) -> Element msg
hardware =
    iconNamed "images/hardware.svg"


refresh : List (Attribute msg) -> Element msg
refresh =
    iconNamed "images/refresh.svg"


search : List (Attribute msg) -> Element msg
search =
    iconNamed "images/search.svg"


check : List (Attribute msg) -> Element msg
check attrs =
    iconNamed "images/check.svg" (alpha 1 :: attrs)


done : List (Attribute msg) -> Element msg
done attrs =
    iconNamed "images/done.svg" (alpha 1 :: attrs)


vehicle : List (Attribute msg) -> Element msg
vehicle =
    iconNamed "images/shuttle.svg"


home_pin : List (Attribute msg) -> Element msg
home_pin =
    iconNamed "images/home_pin.svg"


fuel : List (Attribute msg) -> Element msg
fuel =
    iconNamed "images/fuel.svg"


emptySeat : List (Attribute msg) -> Element msg
emptySeat =
    iconNamed "images/seat-empty.svg"


occupiedSeat : List (Attribute msg) -> Element msg
occupiedSeat =
    iconNamed "images/seat-occupied.svg"


dashedBox : List (Attribute msg) -> Element msg
dashedBox =
    iconNamed "images/dotted_box.svg"


close : List (Attribute msg) -> Element msg
close =
    iconNamed "images/close.svg"


box : List (Attribute msg) -> Element msg
box =
    iconNamed "images/solid_box.svg"


save : List (Attribute msg) -> Element msg
save =
    iconNamed "images/save.svg"
