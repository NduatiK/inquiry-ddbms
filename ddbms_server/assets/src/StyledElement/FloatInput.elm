module StyledElement.FloatInput exposing
    ( FloatInput
    , fromFloat
    , toFloat
    , view
    )

{-| A specialization of a StyledElement that allows the input of floats

    Why make an input for floats?
    So that I can keep track of text like "0." while
    making sure that only numbers are entered

    Text | Number
    --- | ---
    0.1 | 0.1
    0. | 0
    .3 | 0.3

    This helps prevent impossible inputs such as 100..0 while
    not falling into the trap of converting the input into a float and back into a string
    which could destroy meaningfull data

    So instead of
    Input ->  Storage ->  View Update Text
    "10." ->     10      ->  "10"

    which would make it impossible to input decimal values
    ie 10.1 would become 101

    We do
    Input ->  Storage    ->  View Update Text
    "10." ->  ("10.",10) ->  "10."
    Which would prevent invalid internal float values
    while allowing the user to input anything that can be parsed into a float

    Also, floats are bounded to 2 dp

-}

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Icons exposing (IconBuilder)
import Regex
import Style exposing (..)
import StyledElement exposing (wrappedInput)


type FloatInput
    = FloatInput Float String


fromFloat : Float -> FloatInput
fromFloat float =
    FloatInput float (String.fromFloat float)


toFloat : FloatInput -> Float
toFloat floatInput_ =
    case floatInput_ of
        FloatInput float _ ->
            float


view :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , value : FloatInput
        , onChange : FloatInput -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , minimum : Maybe Float
        , maximum : Maybe Float
        }
    -> Element msg
view attributes { title, caption, value, onChange, placeholder, ariaLabel, icon, minimum, maximum } =
    let
        ( originalValue, floatString ) =
            case value of
                FloatInput v s ->
                    ( v, s )

        userFind : String -> String -> String
        userFind userRegex string =
            case Regex.fromString userRegex of
                Nothing ->
                    ""

                Just regex ->
                    let
                        matches =
                            Regex.findAtMost 1 regex string
                    in
                    case List.head matches of
                        Just match ->
                            match.match

                        Nothing ->
                            ""

        onlyFloat str =
            userFind "^[0-9]*\\.?[0-9]{0,2}" str

        onChangeWithMaxAndMin =
            let
                minimumValue =
                    Maybe.withDefault 0 minimum

                maximumValue =
                    Maybe.withDefault 10000000 maximum

                newFloatInput cleanedStr =
                    let
                        newValue : Float
                        newValue =
                            cleanedStr |> String.toFloat |> Maybe.withDefault originalValue |> Basics.clamp minimumValue maximumValue
                    in
                    if cleanedStr == "" then
                        FloatInput 0 cleanedStr

                    else if Just newValue == String.toFloat cleanedStr then
                        -- The string is valid, just use it
                        FloatInput newValue cleanedStr

                    else
                        -- The string is invalid, so reset it to the value in float
                        FloatInput newValue (String.fromFloat newValue)
            in
            onlyFloat
                >> newFloatInput
                >> onChange

        textField =
            Input.text
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0) ])
                { onChange = onChangeWithMaxAndMin
                , text = floatString
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }

        body : Element msg
        body =
            wrappedInput textField
                title
                caption
                icon
                attributes
                []
    in
    body
