module Style exposing
    ( animatesAll
    , animatesAll20Seconds
    , animatesAllDelayed
    , animatesNone
    , animatesShadow
    , blurredStyle
    , borderedContainer
    , captionStyle
    , clipStyle
    , cssResponsive
    , defaultFontFace
    , edges
    , elevated
    , elevated2
    , elevatedTile
    , errorStyle
    , header2Style
    , headerStyle
    , ignoreCss
    , inputStyle
    , labelStyle
    , mobileHidden
    , normalScrolling
    , reverseScrolling
    , stickyStyle
    , tableElementStyle
    , tableHeaderStyle
    )

import Colors exposing (..)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Html.Attributes
import Html.Events
import Json.Decode


elevated : Attr decorative msg
elevated =
    Border.shadow { offset = ( 0, 0 ), size = 0, blur = 5, color = rgba 0 0 0 0.14 }


elevated2 : Attr decorative msg
elevated2 =
    Border.shadow { offset = ( 0, 0 ), size = 0, blur = 10, color = rgba 0 0 0 0.24 }


elevatedTile : Attr decorative msg
elevatedTile =
    Border.shadow { offset = ( 0, 2 ), size = 0, blur = 24, color = Colors.withAlpha Colors.sassyGrey 0.37 }



-- STYLES


borderedContainer : List (Attribute msg)
borderedContainer =
    [ Border.width 1
    , Border.color (rgb255 163 175 190)
    ]


headerStyle : List (Attribute msg)
headerStyle =
    [ Region.heading 1
    , Font.size 31
    , Font.family
        [ Font.typeface "SF Pro Display"
        , Font.sansSerif
        ]
    , paddingXY 0 10
    , Font.bold
    ]


header2Style : List (Attribute msg)
header2Style =
    [ Region.heading 2
    , Font.size 24
    , Font.color (rgb255 51 63 78)
    , Font.family
        [ Font.typeface "SF Pro Display"

        --  Font.typeface "InterUI-Bold"
        , Font.sansSerif
        ]
    , Font.bold
    , paddingXY 0 10
    ]


captionStyle : List (Attribute msg)
captionStyle =
    [ Font.size 15
    , Font.color (Colors.withAlpha (rgb255 4 30 37) 0.69)
    ]
        ++ defaultFontFace


errorStyle : List (Attribute msg)
errorStyle =
    labelStyle ++ [ Font.color errorRed ]


labelStyle : List (Attribute msg)
labelStyle =
    [ Font.size 16
    , Font.color (rgb255 51 63 78)
    ]
        ++ defaultFontFace


inputStyle : List (Attribute msg)
inputStyle =
    [ Background.color (rgb255 245 245 245)
    , Border.color darkGreen
    , Border.widthEach
        { bottom = 2
        , left = 0
        , right = 0
        , top = 0
        }
    , Border.solid
    , Font.size 16
    , height
        (fill
            |> minimum 46
        )
    ]
        ++ defaultFontFace


tableHeaderStyle : List (Attribute msg)
tableHeaderStyle =
    [ Region.heading 4
    , Font.size 14
    , Font.color (rgb255 115 115 115)
    , Font.letterSpacing 0.58
    , Font.bold
    , alignLeft
    ]
        ++ defaultFontFace


tableElementStyle : List (Attribute msg)
tableElementStyle =
    [ Region.heading 4
    , Font.size 18
    , Font.color (rgb255 96 96 96)
    , alignLeft
    ]
        ++ defaultFontFace


{-| Sets Font.family to custom font
-}
defaultFontFace : List (Attribute msg)
defaultFontFace =
    [ Font.family
        [ Font.typeface "SF Pro Text"

        --     Font.typeface "Space Mono"
        -- , Font.typeface "Fira Code"
        , Font.sansSerif
        , Font.monospace
        ]
    ]



-- [ Font.family
--     [
-- Font.typeface "SF Pro Text"
--Font.typeface "Space Mono"
--     , Font.typeface "Fira Code"
--     , Font.monospace
--     ]
-- ]
-- CUSTOMIZATIONS


blurredStyle : Attribute msg
blurredStyle =
    classAttr "blurred"


clipStyle : Attribute msg
clipStyle =
    classAttr "safari-clip"


stickyStyle : Attribute msg
stickyStyle =
    classAttr "sticky"


mobileHidden : Attribute msg
mobileHidden =
    classAttr "mobileHidden"


animatesShadow : Attribute msg
animatesShadow =
    classAttr "animatesShadow"


reverseScrolling : Attribute msg
reverseScrolling =
    htmlAttribute (Html.Attributes.style "direction" "rtl")


normalScrolling : Attribute msg
normalScrolling =
    htmlAttribute (Html.Attributes.style "direction" "ltr")


animatesAll : Attribute msg
animatesAll =
    classAttr "animatesAll"


animatesNone : Attribute msg
animatesNone =
    classAttr "animatesNone"


ignoreCss : Attribute msg
ignoreCss =
    classAttr "ignoreCss"


cssResponsive : Attribute msg
cssResponsive =
    classAttr "cssResponsive"


animatesAll20Seconds : Attribute msg
animatesAll20Seconds =
    classAttr "animatesAll20Seconds"


animatesAllDelayed : Attribute msg
animatesAllDelayed =
    classAttr "animatesAllDelayed"



-- HELPERS


classAttr : String -> Attribute msg
classAttr class =
    Html.Attributes.class class
        |> htmlAttribute



-- idAttr : String -> Attribute msg
-- idAttr id =
--     Html.Attributes.id id
--         |> htmlAttribute


edges : { top : Int, right : Int, bottom : Int, left : Int }
edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }
