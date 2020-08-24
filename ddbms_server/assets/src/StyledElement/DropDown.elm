module StyledElement.DropDown exposing
    ( State, init
    , Msg
    , Config, basic, filterable
    , withContainerAttributes, withPromptElement, withSelectAttributes, withSearchAttributes, withOpenCloseButtons, withListAttributes
    , update, view
    , dropDownConfig, filterText, selectOption, toDropDownView
    )

{-|


## PaackEng's Elm UI Dropdown with some modifications for visual consistency

Elm UI Dropdown.
MIT License

Copyright (c) 2019 PaackEng

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Sourced from PaackEng/elm-ui-dropdown

@docs State, init
@docs Msg
@docs Config, basic, filterable
@docs withContainerAttributes, withPromptElement, withSelectAttributes, withSearchAttributes, withOpenCloseButtons, withListAttributes
@docs update, view

-}

import Browser.Dom as Dom
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html.Attributes
import Html.Events
import Icons
import Json.Decode as Decode
import Style
import Task


type DropdownType
    = Basic
    | Filterable


type alias InternalState item =
    { id : String
    , isOpen : Bool
    , selectedItem : Maybe item
    , filterText : String
    , focusedIndex : Int
    }


filterText : State a -> String
filterText (State state) =
    state.filterText


{-| Opaque type that holds the current state

    type alias Model =
        { dropdownState : Dropdown.State String
        }

-}
type State item
    = State (InternalState item)


type alias InternalConfig item msg =
    { dropdownType : DropdownType
    , promptElement : Element msg
    , filterPlaceholder : String
    , dropdownMsg : Msg item -> msg
    , onSelectMsg : Maybe item -> msg
    , containerAttributes : List (Attribute msg)
    , selectAttributes : List (Attribute msg)
    , listAttributes : List (Attribute msg)
    , searchAttributes : List (Attribute msg)
    , itemToPrompt : item -> Element msg
    , itemToElement : Bool -> Bool -> item -> Element msg
    , openButton : Element msg
    , closeButton : Element msg
    , itemToText : item -> String
    , icon : Maybe (Element msg)
    , isLoading : Bool
    }


{-| Opaque type that holds the current config

    dropdownConfig =
        Dropdown.basic DropdownMsg OptionPicked Element.text Element.text

-}
type Config item msg
    = Config (InternalConfig item msg)


{-| Opaque type for the internal dropdown messages
-}
type Msg item
    = NoOp
    | OnBlur
    | OnClickPrompt
    | OnSelect item
    | OnFilterTyped String
    | OnKeyDown Key


selectOption item =
    OnSelect item


type Key
    = ArrowDown
    | ArrowUp
    | Enter
    | Esc


{-| Create a new state. You must pass a unique identifier for each dropdown component.

    {
        ...
        dropdownState = Dropdown.init "country-dropdown"
    }

-}
init : String -> Maybe item -> State item
init id item =
    State
        { id = id
        , isOpen = False
        , selectedItem = item
        , filterText = ""
        , focusedIndex = 0
        }


{-| Create a basic configuration. This takes:

    - The message to wrap all the internal messages of the dropdown
    - A message to trigger when an item is selected
    - A function to get the Element to display from an item, to be used in the select part of the dropdown
    - A function to get the Element to display from an item, to be used in the item list of the dropdown

    Dropdown.basic DropdownMsg OptionPicked Element.text Element.text

-}
basic : (Msg item -> msg) -> (Maybe item -> msg) -> (item -> Element msg) -> (Bool -> Bool -> item -> Element msg) -> Config item msg
basic dropdownMsg onSelectMsg itemToPrompt itemToElement =
    Config
        { dropdownType = Basic
        , promptElement = el [ width fill ] (text "-- Select --")
        , filterPlaceholder = "Search..."
        , dropdownMsg = dropdownMsg
        , onSelectMsg = onSelectMsg
        , containerAttributes = []
        , selectAttributes = []
        , listAttributes = []
        , searchAttributes = []
        , itemToPrompt = itemToPrompt
        , itemToElement = itemToElement
        , openButton = text "▼"
        , closeButton = text "▲"
        , itemToText = always ""
        , icon = Nothing
        , isLoading = False
        }


{-| -}
dropDownConfig : (Msg item -> msg) -> (Maybe item -> msg) -> (item -> String) -> Maybe (List (Attribute msg) -> Element msg) -> Bool -> String -> Config item msg
dropDownConfig dropDownMsgWrapper onPickMsg toString icon isLoading prompt =
    let
        containerAttrs =
            [ width fill
            , Background.color (rgb 1 1 1)
            , Font.size 16
            ]

        selectAttrs =
            [ paddingXY 16 8
            , spacing 10
            , height (px 46)
            , width fill
            ]
                ++ Style.inputStyle
                ++ [ Border.width 0 ]

        searchAttrs =
            [ Border.width 0
            , padding 0
            , width fill
            , Background.color (rgba 0 0 0 0)
            ]
                ++ Style.labelStyle

        listAttrs =
            [ Background.color (rgb 1 1 1)
            , Border.shadow
                { offset = ( 0, 8 )
                , size = 0
                , blur = 16
                , color = rgba 0 0 0 0.1
                }
            , width fill
            , clip
            , scrollbarY
            , height (fill |> maximum 210)
            , Border.widthEach
                { bottom = 2
                , left = 0
                , right = 0
                , top = 0
                }
            , Border.color Colors.darkGreen
            ]

        itemToPrompt item =
            el
                Style.labelStyle
                (text (toString item))

        itemToElement selected _ i =
            let
                bgColor =
                    if selected then
                        Colors.withAlpha Colors.teal 0.3

                    else
                        rgb255 255 255 255
            in
            el
                ([ Background.color bgColor
                 , paddingXY 12 12
                 , spacing 10
                 , width fill
                 , Border.color (rgba 0 0 0 0.2)
                 , Border.widthEach
                    { bottom = 1
                    , left = 0
                    , right = 0
                    , top = 0
                    }
                 ]
                    ++ Style.labelStyle
                )
                (text (toString i))
    in
    filterable dropDownMsgWrapper onPickMsg itemToPrompt itemToElement toString icon
        |> withContainerAttributes containerAttrs
        |> withSelectAttributes selectAttrs
        |> withListAttributes listAttrs
        |> withSearchAttributes searchAttrs
        |> withPromptElement (el [ Font.color (rgb255 123 123 123) ] <| text prompt)
        |> withOpenCloseButtons
            { openButton = Icons.chevronDown [ alpha 1 ]
            , closeButton = Icons.chevronDown [ rotate pi, alpha 1 ]
            }
        |> withLoadingStatus isLoading


{-| Create a filterable configuration. This takes:

    - The message to wrap all the internal messages of the dropdown
    - A message to trigger when an item is selected
    - A function to get the Element to display from an item, to be used in the select part of the dropdown
    - A function to get the Element to display from an item, to be used in the item list of the dropdown
    - A function to get the text representation from an item, to be used when filtering elements in the list

    Dropdown.basic DropdownMsg OptionPicked Element.text Element.text

-}
filterable : (Msg item -> msg) -> (Maybe item -> msg) -> (item -> Element msg) -> (Bool -> Bool -> item -> Element msg) -> (item -> String) -> Maybe (List (Attribute msg) -> Element msg) -> Config item msg
filterable dropdownMsg onSelectMsg itemToPrompt itemToElement itemToText icon =
    let
        iconAttrs =
            [ width (px 24), height (px 24) ]
    in
    Config
        { dropdownType = Filterable
        , promptElement = el [ width fill ] (text "-- Select --")
        , filterPlaceholder = "Search..."
        , dropdownMsg = dropdownMsg
        , onSelectMsg = onSelectMsg
        , containerAttributes = []
        , selectAttributes = []
        , listAttributes = []
        , searchAttributes = []
        , itemToPrompt = itemToPrompt
        , itemToElement = itemToElement
        , openButton = text "▼"
        , closeButton = text "▲"
        , itemToText = itemToText
        , icon = Maybe.map (\x -> x iconAttrs) icon
        , isLoading = False
        }


{-| Sets the content of the Select, default is "-- Select --"

    Dropdown.withPromptElement (el [ Font.color (rgb255 123 123 123) ] <| text "Pick one") config

-}
withPromptElement : Element msg -> Config item msg -> Config item msg
withPromptElement promptElement (Config config) =
    Config { config | promptElement = promptElement }


{-| Sets the container visual attributes, default is empty

    Dropdown.withContainerAttributes [ width (px 300) ] config

-}
withContainerAttributes : List (Attribute msg) -> Config item msg -> Config item msg
withContainerAttributes attrs (Config config) =
    Config { config | containerAttributes = attrs }


{-| Sets the select visual attributes, default is empty

    Dropdown.withSelectAttributes [ Border.width 1, Border.rounded 5, paddingXY 16 8 ] config

-}
withSelectAttributes : List (Attribute msg) -> Config item msg -> Config item msg
withSelectAttributes attrs (Config config) =
    Config { config | selectAttributes = attrs }


{-| Sets the search visual attributes, default is empty

    Dropdown.withSearchAttributes [ Border.width 0, padding 0 ] config

-}
withSearchAttributes : List (Attribute msg) -> Config item msg -> Config item msg
withSearchAttributes attrs (Config config) =
    Config { config | searchAttributes = attrs }


{-| Sets the open and close buttons' visual attributes, default is empty

    Dropdown.withOpenCloseButtons { openButton = text "+", closeButton = "-" } config

-}
withOpenCloseButtons : { openButton : Element msg, closeButton : Element msg } -> Config item msg -> Config item msg
withOpenCloseButtons { openButton, closeButton } (Config config) =
    Config { config | openButton = openButton, closeButton = closeButton }


{-| Sets the whether or not to display a loading animation, default is false

    Dropdown.withLoadingStatus True config

-}
withLoadingStatus : Bool -> Config item msg -> Config item msg
withLoadingStatus isLoading (Config config) =
    Config { config | isLoading = isLoading }


{-| Sets the item list visual attributes, default is empty

    Dropdown.withListAttributes [ Border.width 1, Border.rounded ] config

-}
withListAttributes : List (Attribute msg) -> Config item msg -> Config item msg
withListAttributes attrs (Config config) =
    Config { config | listAttributes = attrs }


{-| Update the component state

    DropdownMsg subMsg ->
        let
            ( updated, cmd ) =
                Dropdown.update dropdownConfig subMsg model.dropdownState model.items
        in
            ( { model | dropdownState = updated }, cmd )

-}
update : Config item msg -> Msg item -> State item -> List item -> ( State item, Cmd msg )
update (Config config) msg (State state) data =
    let
        ( newState, newCommand ) =
            case msg of
                NoOp ->
                    ( state, Cmd.none )

                OnBlur ->
                    ( { state | isOpen = False }, Cmd.none )

                OnClickPrompt ->
                    let
                        isOpen =
                            not state.isOpen

                        cmd =
                            if isOpen then
                                Task.attempt (always NoOp) (Dom.focus (state.id ++ "input-search"))

                            else
                                Cmd.none
                    in
                    ( { state | isOpen = isOpen, focusedIndex = 0, filterText = "" }, Cmd.map config.dropdownMsg cmd )

                OnSelect item ->
                    let
                        cmd =
                            Task.succeed (Just item)
                                |> Task.perform config.onSelectMsg
                    in
                    ( { state | isOpen = False, selectedItem = Just item }, cmd )

                OnFilterTyped val ->
                    ( { state | filterText = val }, Cmd.none )

                OnKeyDown key ->
                    let
                        newIndex =
                            case key of
                                ArrowUp ->
                                    if state.focusedIndex > 0 then
                                        state.focusedIndex - 1

                                    else
                                        0

                                ArrowDown ->
                                    if state.focusedIndex < List.length data - 1 then
                                        state.focusedIndex + 1

                                    else
                                        List.length data - 1

                                _ ->
                                    state.focusedIndex

                        isOpen =
                            case key of
                                Esc ->
                                    False

                                Enter ->
                                    False

                                _ ->
                                    True

                        focusedItem =
                            data
                                |> List.indexedMap (\i item -> ( i, item ))
                                |> List.filter (\( i, _ ) -> i == state.focusedIndex)
                                |> List.head
                                |> Maybe.map Tuple.second

                        ( cmd, newSelectedItem ) =
                            case key of
                                Enter ->
                                    ( Task.succeed focusedItem
                                        |> Task.perform config.onSelectMsg
                                    , focusedItem
                                    )

                                _ ->
                                    ( Cmd.none, state.selectedItem )
                    in
                    ( { state | selectedItem = newSelectedItem, focusedIndex = newIndex, isOpen = isOpen }, cmd )
    in
    ( State newState, newCommand )


{-| Render the view

    Dropdown.view dropdownConfig model.dropdownState model.items

-}
view : Config item msg -> State item -> List item -> Element msg
view (Config config) (State state) data =
    let
        containerAttrs =
            [ idAttr state.id
            , below body
            ]
                ++ config.containerAttributes

        filter item =
            String.contains (state.filterText |> String.toLower)
                (item |> config.itemToText |> String.toLower)

        filteredData =
            data
                |> List.filter filter

        trigger =
            triggerView config state

        body =
            bodyView config state filteredData
    in
    column
        containerAttrs
        [ el [ width fill, below body ] trigger
        ]


triggerView : InternalConfig item msg -> InternalState item -> Element msg
triggerView config state =
    let
        selectAttrs =
            [ onClick (config.dropdownMsg OnClickPrompt)
            , onKeyDown (config.dropdownMsg << OnKeyDown)
            , tabIndexAttr 0
            , referenceAttr state
            ]
                ++ (if config.dropdownType == Basic then
                        [ onBlurAttribute config state ]

                    else
                        []
                   )
                ++ config.selectAttributes

        prompt =
            el [ width fill ] <|
                case state.selectedItem of
                    Just selectedItem ->
                        config.itemToPrompt selectedItem

                    Nothing ->
                        config.promptElement

        wrapView wrappedView =
            row [ width fill, spacing 16 ]
                [ Maybe.withDefault none config.icon
                , wrappedView
                ]

        search =
            case config.dropdownType of
                Basic ->
                    prompt

                Filterable ->
                    Input.search
                        ([ idAttr (state.id ++ "input-search")
                         , focused []
                         , onClickNoPropagation (config.dropdownMsg NoOp)
                         , onBlurAttribute config state
                         ]
                            ++ config.searchAttributes
                        )
                        { onChange = config.dropdownMsg << OnFilterTyped
                        , text = state.filterText
                        , placeholder = Just <| Input.placeholder [] (text config.filterPlaceholder)
                        , label = Input.labelHidden "Search..."
                        }

        ( promptOrSearch, button ) =
            if state.isOpen then
                ( wrapView search, el [] config.closeButton )

            else
                ( wrapView prompt, el [] config.openButton )
    in
    row selectAttrs [ promptOrSearch, button ]


bodyView : InternalConfig item msg -> InternalState item -> List item -> Element msg
bodyView config state data =
    if state.isOpen then
        let
            items =
                column
                    config.listAttributes
                    (List.concat
                        [ List.indexedMap (itemView config state) data
                        , if config.isLoading then
                            [ Icons.loading [ centerX ] ]

                          else
                            []
                        ]
                    )

            body =
                el
                    [ height shrink
                    , width fill
                    ]
                    items
        in
        body

    else
        none


itemView : InternalConfig item msg -> InternalState item -> Int -> item -> Element msg
itemView config state i item =
    let
        itemAttrs =
            [ onClick <| config.dropdownMsg (OnSelect item)
            , referenceAttr state
            , tabIndexAttr -1
            , width fill
            ]

        selected =
            state.selectedItem == Just item

        highlighed =
            i == state.focusedIndex
    in
    el
        itemAttrs
        (config.itemToElement selected highlighed item)



-- helpers


idAttr : String -> Attribute msg
idAttr id =
    Html.Attributes.id id
        |> htmlAttribute


tabIndexAttr : Int -> Attribute msg
tabIndexAttr tabIndex =
    Html.Attributes.tabindex tabIndex
        |> htmlAttribute


referenceDataName : String
referenceDataName =
    "data-dropdown-id"


referenceAttr : InternalState item -> Attribute msg
referenceAttr model =
    Html.Attributes.attribute referenceDataName model.id
        |> htmlAttribute


onClick : msg -> Attribute msg
onClick message =
    Events.onClick message


onClickNoPropagation : msg -> Attribute msg
onClickNoPropagation msg =
    Html.Events.custom "click"
        (Decode.succeed
            { message = msg
            , stopPropagation = True
            , preventDefault = True
            }
        )
        |> htmlAttribute


onKeyDown : (Key -> msg) -> Attribute msg
onKeyDown msg =
    let
        stringToKey str =
            case str of
                "ArrowDown" ->
                    Decode.succeed ArrowDown

                "ArrowUp" ->
                    Decode.succeed ArrowUp

                "Enter" ->
                    Decode.succeed Enter

                "Escape" ->
                    Decode.succeed Esc

                _ ->
                    Decode.fail "not used key"

        keyDecoder =
            Decode.field "key" Decode.string
                |> Decode.andThen stringToKey
    in
    Html.Events.on "keydown" (Decode.map msg keyDecoder)
        |> htmlAttribute


onBlurAttribute : InternalConfig item msg -> InternalState item -> Attribute msg
onBlurAttribute config state =
    let
        -- relatedTarget only works if element has tabindex
        dataDecoder =
            Decode.at [ "relatedTarget", "attributes", referenceDataName, "value" ] Decode.string

        attrToMsg attr =
            if attr == state.id then
                config.dropdownMsg NoOp

            else
                config.dropdownMsg OnBlur

        blur =
            Decode.maybe dataDecoder
                |> Decode.map (Maybe.map attrToMsg)
                |> Decode.map (Maybe.withDefault <| config.dropdownMsg OnBlur)
    in
    Html.Events.on "blur" blur
        |> htmlAttribute


toDropDownView : ( Element msg, Config item msg, List item ) -> Element msg
toDropDownView aDropdown =
    case aDropdown of
        ( view_, _, _ ) ->
            view_
