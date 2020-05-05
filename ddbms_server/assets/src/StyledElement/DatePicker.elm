module StyledElement.DatePicker exposing (update, view)

import Browser.Dom as Dom
import Colors
import Date
import DatePicker
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Errors exposing (InputError)
import Html
import Html.Attributes exposing (id)
import Icons exposing (IconBuilder)
import Style
import StyledElement exposing (wrappedInput)


config : DatePicker.Settings
config =
    let
        default =
            DatePicker.defaultSettings
    in
    { default
        | dateFormatter = Date.format "yyyy-MM-dd"
        , placeholder = "Select a date eg 2020-12-31"
        , parser = Date.fromIsoString
    }


update :
    DatePicker.Msg
    -> DatePicker.DatePicker
    -> ( DatePicker.DatePicker, DatePicker.DateEvent )
update =
    DatePicker.update config


view :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe InputError
        , icon : Maybe (IconBuilder msg)
        , onChange : DatePicker.Msg -> msg
        , value : Maybe Date.Date
        , state : DatePicker.DatePicker
        }
    -> Element msg
view attributes { title, caption, errorCaption, value, onChange, state, icon } =
    let
        input =
            el [ paddingXY 12 0, width fill, htmlAttribute (Html.Attributes.class "focus-within") ]
                (html
                    (DatePicker.view value config state
                        |> Html.map onChange
                    )
                )
    in
    wrappedInput input title caption errorCaption icon attributes []
