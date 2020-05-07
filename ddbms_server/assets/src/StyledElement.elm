module StyledElement exposing
    ( button
    , buttonLink
    , dropDown
    , emailInput
    , ghostButton
    , ghostButtonLink
    , hoverButton
    , hoverLink
    , iconButton
    , multilineInput
    , plainButton
    , textInput
    , textLink
    , unstyledIconButton
    , wrappedInput
    )

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (node)
import Html.Attributes exposing (id)
import Http
import Icons exposing (IconBuilder)
import Json.Encode as Encode
import Navigation
import Regex
import Style exposing (..)
import StyledElement.DropDown as Dropdown


ghostButtonLink :
    List (Attribute msg)
    -> { title : String, route : Navigation.Route }
    -> Element msg
ghostButtonLink attrs { title, route } =
    buttonLink
        ([ Border.width 3, Border.color Colors.purple, Background.color Colors.white ] ++ attrs)
        { label =
            row [ spacing 8 ]
                [ el [ centerY, Font.color Colors.purple ] (text title)
                , Icons.chevronDown [ alpha 1, Colors.fillPurple, rotate (-pi / 2), centerY ]
                ]
        , route = route
        }


buttonLink :
    List (Attribute msg)
    -> { label : Element msg, route : Navigation.Route }
    -> Element msg
buttonLink attributes config =
    Element.link
        ([ Background.color Colors.purple
         , htmlAttribute (Html.Attributes.class "button-link")

         -- Primarily controlled by css
         , height (px 46)
         , Font.color (Element.rgb 1 1 1)
         , Font.size 18
         , Border.rounded 3
         , Style.animatesAll
         , Style.cssResponsive
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 0, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ Style.defaultFontFace
            ++ attributes
        )
        { url = Navigation.href config.route
        , label = el [ centerY ] config.label
        }


hoverLink :
    List (Attribute msg)
    -> { title : String, route : Navigation.Route, rotation : Float }
    -> Element msg
hoverLink attrs { title, route, rotation } =
    buttonLink
        ([ Background.color Colors.white
         , centerY
         , Font.color Colors.purple
         , mouseOver [ Background.color (Element.rgb255 222 220 252) ]
         ]
            ++ attrs
        )
        { label =
            row [ spacing 8 ]
                (if rotation < 0 then
                    [ el [ centerY, Font.color Colors.purple, moveDown 1 ] (text title)
                    , Icons.chevronDown [ alpha 1, Colors.fillPurple, rotate rotation, centerY ]
                    ]

                 else
                    [ Icons.chevronDown [ alpha 1, Colors.fillPurple, rotate rotation, centerY ]
                    , el [ centerY, Font.color Colors.purple, moveDown 1 ] (text title)
                    ]
                )
        , route = route
        }


textLink : List (Attribute msg) -> { label : Element msg, route : Navigation.Route } -> Element msg
textLink attributes config =
    link
        (defaultFontFace
            ++ [ Font.color Colors.purple
               , Font.size 18
               , Border.rounded 3
               , Element.mouseOver
                    [ alpha 0.9 ]
               ]
            ++ attributes
        )
        { url = Navigation.href config.route
        , label = config.label
        }


plainButton :
    List (Attribute msg)
    -> { label : Element msg, onPress : Maybe msg }
    -> Element msg
plainButton attributes config =
    Input.button
        attributes
        { onPress = config.onPress
        , label = config.label
        }


button :
    List (Attribute msg)
    -> { label : Element msg, onPress : Maybe msg }
    -> Element msg
button attributes config =
    plainButton
        ([ Background.color Colors.purple
         , height (px 46)
         , Font.color (Element.rgb 1 1 1)
         , Font.size 18
         , Style.cssResponsive
         , Border.rounded 3
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 0, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ Style.defaultFontFace
            ++ attributes
        )
        config


hoverButton :
    List (Attribute msg)
    -> { title : String, onPress : Maybe msg, icon : Maybe (IconBuilder msg) }
    -> Element msg
hoverButton attrs { title, onPress, icon } =
    button
        ([ Background.color Colors.white
         , centerY
         , Font.color Colors.purple
         , mouseOver [ Background.color (Element.rgb255 222 220 252) ]
         ]
            ++ attrs
        )
        { label =
            row [ spacing 8 ]
                [ Maybe.withDefault (always none) icon [ Colors.fillPurple ]
                , el [ centerY ] (text title)
                ]
        , onPress = onPress
        }


ghostButton :
    List (Attribute msg)
    -> { title : String, onPress : Maybe msg, icon : Icons.IconBuilder msg }
    -> Element msg
ghostButton attrs { title, onPress, icon } =
    button
        ([ Border.width 3, Border.color Colors.purple, Background.color Colors.white, Font.color Colors.purple ] ++ attrs)
        { label =
            row [ spacing 8 ]
                [ icon [ alpha 1, Colors.fillErrorRed ]
                , el [ centerY ] (text title)
                ]
        , onPress = onPress
        }


unstyledIconButton :
    List (Attribute msg)
    ->
        { icon : IconBuilder msg
        , iconAttrs : List (Attribute msg)
        , onPress : Maybe msg
        }
    -> Element msg
unstyledIconButton attributes { onPress, iconAttrs, icon } =
    Input.button
        ([ padding 12
         , alignBottom
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ attributes
        )
        { onPress = onPress
        , label = icon iconAttrs
        }


iconButton :
    List (Attribute msg)
    ->
        { icon : IconBuilder msg
        , iconAttrs : List (Attribute msg)
        , onPress : Maybe msg
        }
    -> Element msg
iconButton attributes { onPress, iconAttrs, icon } =
    Input.button
        ([ padding 12
         , alignBottom
         , Background.color Colors.purple
         , Border.rounded 8
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ attributes
        )
        { onPress = onPress
        , label = icon iconAttrs
        }


textInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
textInput attributes { title, caption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.text
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0), htmlAttribute (id (String.replace " " "-" (String.toLower ariaLabel))) ])
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }
    in
    wrappedInput input title caption icon attributes []


multilineInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
multilineInput attributes { title, caption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.multiline
                (Style.labelStyle ++ [ height fill, centerY, Border.width 0, Background.color (rgba 0 0 0 0), htmlAttribute (id (String.replace " " "-" (String.toLower ariaLabel))) ] ++ attributes)
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                , spellcheck = True
                }
    in
    input


emailInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
emailInput attributes { title, caption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.email
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0), htmlAttribute (id (String.replace " " "-" (String.toLower ariaLabel))) ])
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }
    in
    wrappedInput input title caption icon attributes []


dropDown :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , options : List item
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , dropDownMsg : Dropdown.Msg item -> msg
        , onSelect : Maybe item -> msg
        , toString : item -> String
        , dropdownState : Dropdown.State item
        , isLoading : Bool
        , prompt : Maybe String
        }
    -> ( Element msg, Dropdown.Config item msg, List item )
dropDown attributes { title, caption, dropdownState, dropDownMsg, onSelect, options, ariaLabel, icon, toString, isLoading, prompt } =
    let
        config : Dropdown.Config item msg
        config =
            Dropdown.dropDownConfig dropDownMsg onSelect toString icon isLoading (Maybe.withDefault "Pick one" prompt)

        input =
            Dropdown.view config dropdownState options

        body =
            wrappedInput input title caption Nothing (attributes ++ [ Border.width 0 ]) []
    in
    ( body, config, options )


errorBorder : Bool -> List (Attribute msg)
errorBorder hideBorder =
    if hideBorder then
        []

    else
        [ Border.color Colors.errorRed, Border.solid, Border.width 2 ]


{-| wrappedInput input title caption icon attributes trailingElements
-}
wrappedInput : Element msg -> String -> Maybe String -> Maybe (IconBuilder msg) -> List (Attribute msg) -> List (Element msg) -> Element msg
wrappedInput input title caption icon attributes trailingElements =
    let
        captionLabel =
            case caption of
                Just captionText ->
                    Element.paragraph captionStyle [ text captionText ]

                Nothing ->
                    none

        textBoxIcon =
            case icon of
                Just iconElement ->
                    iconElement [ centerY, paddingEach { edges | left = 12 } ]

                Nothing ->
                    none
    in
    Element.column
        ([ spacing 6
         , width fill
         , height
            shrink
         ]
            ++ attributes
        )
        [ if title /= "" then
            el Style.labelStyle (text title)

          else
            none
        , row
            (spacing 12 :: width fill :: centerY :: Style.inputStyle)
            ([ textBoxIcon
             , input
             ]
                ++ trailingElements
            )
        , captionLabel
        ]
