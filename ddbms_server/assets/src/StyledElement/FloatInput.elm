module StyledElement.FloatInput exposing
    ( FloatInput
    , fromFloat
    , toFloat
    , view
    )

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Errors exposing (InputError)
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
        , errorCaption : Maybe InputError
        , value : FloatInput
        , onChange : FloatInput -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , minimum : Maybe Float
        , maximum : Maybe Float
        }
    -> Element msg
view attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon, minimum, maximum } =
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
                    Maybe.withDefault 100000 maximum

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
                errorCaption
                icon
                attributes
                []

        -- [ Input.button []
        --     { label = Icons.subtract [ width <| px 24, height <| px 24 ]
        --     , onPress = Just (onChange (value - 1))
        --     }
        -- , el [ Background.color (rgba 0 0 0 0.12), width <| px 1, height <| px 20 ] none
        -- , Input.button []
        --     { label = Icons.add [ width <| px 24, height <| px 24 ]
        --     , onPress = Just (onChange (value + 1))
        --     }
        -- , el [ width <| px 0, height <| px 20 ] none
        -- ]
    in
    body
