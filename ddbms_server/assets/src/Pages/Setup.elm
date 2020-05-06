module Pages.Setup exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Browser.Navigation as Nav
import Colors
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Errors
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Encode as Encode
import Navigation
import RemoteData exposing (..)
import Set exposing (Set)
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
import StyledElement.FloatInput as FloatInput exposing (FloatInput)
import Task
import Views.DragAndDrop exposing (draggable, droppable)


type alias Model =
    { previousSteps : List Step
    , currentStep : Step
    , nextSteps : List Step
    , typeDropdownState : Dropdown.State Type
    , fields : List Field
    , problems : List String
    , selectedMode : FragmentationMode
    , allocations : Dict String (List Field)
    , conditions : Dict String (Maybe ( Condition, FloatInput ))
    , filterField : Maybe Field
    , requestState : WebData ()
    , key : Nav.Key
    }


type Step
    = GlobalSchema
        { currentField : Field
        , problems : List (Errors.Errors Problem)
        }
    | PartitioningMethod
    | ParticipatingDatabases
        { pickedUpDB : Maybe DB
        }
    | AttributeAllocations
        { pickedUpField : Maybe Field
        , pickedUpCondition : Maybe Condition
        }
    | Summary


type Problem
    = OnlyOnePrimary
    | EmptyField


type Field
    = Field String Type


type Type
    = PrimaryKey
    | Double
    | Integer
    | VarChar


type DB
    = PostgreSQL
    | MySQL
    | MariaDB


type FragmentationMode
    = Horizontal3 ( Maybe DB, Maybe DB, Maybe DB )
    | Vertical2Horizontal1 ( Maybe DB, Maybe DB, Maybe DB )
    | Horizontal2Vertical1 ( Maybe DB, Maybe DB, Maybe DB )
    | Vertical3 ( Maybe DB, Maybe DB, Maybe DB )


type Condition
    = GreaterThan Int
    | GreaterThanOrEqualTo Int
    | LessThan Int
    | LessThanOrEqualTo Int
    | EqualTo Int


init : Nav.Key -> ( Model, Cmd msg )
init key =
    ( { previousSteps = []
      , currentStep =
            GlobalSchema
                { currentField = Field "id" PrimaryKey
                , problems = []
                }
      , nextSteps =
            [ PartitioningMethod
            , ParticipatingDatabases { pickedUpDB = Nothing }
            , AttributeAllocations
                { pickedUpField = Nothing
                , pickedUpCondition = Nothing
                }
            , Summary
            ]
      , typeDropdownState = Dropdown.init "" (Just PrimaryKey)
      , fields = []
      , selectedMode = Vertical3 ( Nothing, Nothing, Nothing )
      , problems = []
      , allocations = Dict.fromList allocationBuilder
      , conditions = Dict.fromList conditionBuilder
      , filterField = Nothing
      , requestState = NotAsked
      , key = key
      }
    , Cmd.none
    )


allocationBuilder : List ( String, List a )
allocationBuilder =
    List.map (\x -> ( dbName x, [] )) allDBs


conditionBuilder : List ( String, Maybe a )
conditionBuilder =
    List.map (\x -> ( dbName x, Nothing )) allDBs



-- UPDATE


type Msg
    = NoOp
    | GoBack
    | GoForward
    | TypeDropdownMsg (Dropdown.Msg Type)
    | TypeChanged Type
    | UpdatedFieldName String
    | AddField
    | SetMode FragmentationMode
    | SetFragmentDB Int
    | ClearSlot Int
    | PickedUpDB (Maybe DB)
    | PickedUpField (Maybe Field)
    | AssignFieldToDB DB
    | AssignFieldToDBs (List DB)
    | RemoveAllocation Field
    | PickedUpCondition (Maybe Condition)
    | SetFilterField
    | ClearFilterField
    | UpdatedConditionValue (List DB) FloatInput
    | SetCondition (List DB)
    | Save
    | ServerResponse (WebData ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model_ =
    let
        model =
            { model_ | problems = [] }
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        TypeDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    typeDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.typeDropdownState options
            in
            ( { model | typeDropdownState = state }, cmd )

        AddField ->
            case model.currentStep of
                GlobalSchema data ->
                    if fieldToType data.currentField == PrimaryKey && List.any (\x -> fieldToType x == PrimaryKey) model.fields then
                        ( { model
                            | currentStep =
                                GlobalSchema { data | problems = Errors.toClientSideErrors [ ( OnlyOnePrimary, "There can only be one" ) ] ++ data.problems }
                          }
                        , Cmd.none
                        )

                    else if fieldName data.currentField == "" || List.any (\x -> fieldName x == fieldName data.currentField) model.fields then
                        ( { model
                            | currentStep =
                                GlobalSchema { data | problems = Errors.toClientSideErrors [ ( EmptyField, "Unique non-empty value required" ) ] ++ data.problems }
                          }
                        , Cmd.none
                        )

                    else
                        ( { model
                            | fields = model.fields ++ [ data.currentField ]
                            , currentStep =
                                GlobalSchema
                                    { currentField = Field "" VarChar
                                    , problems = []
                                    }
                          }
                        , Task.succeed (TypeDropdownMsg (Dropdown.selectOption VarChar)) |> Task.perform identity
                        )

                _ ->
                    ( model, Cmd.none )

        UpdatedFieldName newName ->
            case model.currentStep of
                GlobalSchema data ->
                    ( { model
                        | currentStep =
                            GlobalSchema
                                { currentField = Field newName (fieldToType data.currentField)
                                , problems = []
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetMode mode ->
            case model.currentStep of
                PartitioningMethod ->
                    ( { model
                        | selectedMode = mode
                        , conditions = Dict.fromList conditionBuilder
                        , allocations = Dict.fromList allocationBuilder
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetFragmentDB slot ->
            case model.currentStep of
                ParticipatingDatabases data ->
                    ( { model
                        | selectedMode =
                            let
                                ( db1, db2, db3 ) =
                                    modeToDBs model.selectedMode
                            in
                            case ( data.pickedUpDB, slot ) of
                                ( Nothing, _ ) ->
                                    model.selectedMode

                                ( _, 1 ) ->
                                    setDBs model.selectedMode ( data.pickedUpDB, db2, db3 )

                                ( _, 2 ) ->
                                    setDBs model.selectedMode ( db1, data.pickedUpDB, db3 )

                                ( _, _ ) ->
                                    setDBs model.selectedMode ( db1, db2, data.pickedUpDB )
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ClearSlot slot ->
            case model.currentStep of
                ParticipatingDatabases data ->
                    let
                        ( db1, db2, db3 ) =
                            modeToDBs model.selectedMode
                    in
                    ( { model
                        | selectedMode =
                            case ( data.pickedUpDB, slot ) of
                                ( _, 1 ) ->
                                    setDBs model.selectedMode ( Nothing, db2, db3 )

                                ( _, 2 ) ->
                                    setDBs model.selectedMode ( db1, Nothing, db3 )

                                ( _, _ ) ->
                                    setDBs model.selectedMode ( db1, db2, Nothing )
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        PickedUpDB db ->
            case model.currentStep of
                ParticipatingDatabases data ->
                    ( { model
                        | currentStep =
                            ParticipatingDatabases { data | pickedUpDB = db }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        PickedUpField db ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | currentStep =
                            AttributeAllocations { data | pickedUpField = db }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        PickedUpCondition condition ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | currentStep =
                            AttributeAllocations { data | pickedUpCondition = condition }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        AssignFieldToDB db ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | allocations =
                            let
                                ( db1, db2, db3 ) =
                                    modeToDBs model.selectedMode

                                mapDB db_ field =
                                    case Dict.get (dbName db_) model.allocations of
                                        Just found ->
                                            Dict.insert (dbName db) (field :: found) model.allocations

                                        Nothing ->
                                            model.allocations
                            in
                            case ( data.pickedUpField, db ) of
                                ( Nothing, _ ) ->
                                    model.allocations

                                ( Just field, _ ) ->
                                    mapDB db field
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetCondition dbs ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | conditions =
                            case data.pickedUpCondition of
                                Nothing ->
                                    model.conditions

                                Just condition ->
                                    List.foldl
                                        (\db acc ->
                                            Dict.insert (dbName db) (Just ( condition, FloatInput.fromFloat 0 )) acc
                                        )
                                        model.conditions
                                        dbs
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        UpdatedConditionValue dbs input ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | conditions =
                            List.foldl
                                (\db acc ->
                                    case Maybe.withDefault Nothing (Dict.get (dbName db) acc) of
                                        Just ( condition, _ ) ->
                                            Dict.insert (dbName db)
                                                (Just
                                                    ( applyValue condition (truncate (FloatInput.toFloat input))
                                                    , input |> FloatInput.toFloat |> truncate |> toFloat |> FloatInput.fromFloat
                                                    )
                                                )
                                                acc

                                        Nothing ->
                                            acc
                                )
                                model.conditions
                                dbs
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        AssignFieldToDBs dbs ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | allocations =
                            let
                                ( db1, db2, db3 ) =
                                    modeToDBs model.selectedMode

                                mapDB db_ field allocations =
                                    case Dict.get (dbName db_) model.allocations of
                                        Just found ->
                                            Dict.insert (dbName db_) (field :: found) allocations

                                        Nothing ->
                                            allocations
                            in
                            case data.pickedUpField of
                                Nothing ->
                                    model.allocations

                                Just field ->
                                    List.foldl (\db acc -> mapDB db field acc) model.allocations dbs
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        RemoveAllocation field ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | allocations =
                            Dict.map (\k v -> List.filter (\f -> f /= field) v) model.allocations
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        TypeChanged newType ->
            case model.currentStep of
                GlobalSchema data ->
                    ( { model
                        | currentStep =
                            GlobalSchema
                                { currentField = Field (fieldName data.currentField) newType
                                , problems = []
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetFilterField ->
            case model.currentStep of
                AttributeAllocations data ->
                    ( { model
                        | filterField = data.pickedUpField
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ClearFilterField ->
            case model.currentStep of
                AttributeAllocations _ ->
                    ( { model
                        | filterField = Nothing
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        GoBack ->
            case ( List.take (List.length model.previousSteps - 1) model.previousSteps, List.head (List.drop (List.length model.previousSteps - 1) model.previousSteps) ) of
                ( previousSteps, Just tail ) ->
                    ( { model
                        | previousSteps = previousSteps
                        , currentStep = tail
                        , nextSteps = model.currentStep :: model.nextSteps
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        GoForward ->
            let
                problems =
                    case model.currentStep of
                        GlobalSchema _ ->
                            if model.fields == [] then
                                [ "Please provide at least one field" ]

                            else if not (List.member PrimaryKey (List.map fieldToType model.fields)) then
                                [ "Please provide a primary key field" ]

                            else
                                []

                        ParticipatingDatabases _ ->
                            if List.member Nothing (model.selectedMode |> modeToDBs |> dbTupleToList) then
                                [ "Please fill all the slots" ]

                            else
                                []

                        AttributeAllocations _ ->
                            let
                                assignedFields =
                                    Set.fromList (List.map fieldName (List.concat (Dict.values model.allocations)))
                            in
                            if List.member [] (Dict.values model.allocations) then
                                [ "Each fragment must have at least one field allocated to it" ]

                            else if Set.size assignedFields + 1 /= List.length model.fields then
                                [ "Each field must be assigned" ]

                            else if not (validStrategy model.selectedMode (List.map Tuple.first (List.filterMap identity (Dict.values model.conditions)))) then
                                [ "The conditions you provided do not cater for the full range of possible values or overlaps ranges" ]

                            else
                                []

                        _ ->
                            []
            in
            if problems == [] then
                case ( List.head model.nextSteps, List.drop 1 model.nextSteps ) of
                    ( Just head, nextSteps ) ->
                        ( { model
                            | previousSteps = model.previousSteps ++ [ model.currentStep ]
                            , currentStep = head
                            , nextSteps = nextSteps
                            , problems = []
                          }
                        , Cmd.none
                        )

                    _ ->
                        ( model, Cmd.none )

            else
                ( { model | problems = problems }, Cmd.none )

        Save ->
            ( model, uploadSettings model )

        ServerResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success () ->
                    ( newModel, Cmd.none )

                -- ( newModel, Navigation.rerouteTo model.key Navigation.Queries )
                Failure error ->
                    ( { newModel | problems = [ "Server error" ] }, Cmd.none )

                _ ->
                    ( { newModel | problems = [] }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    Element.column
        [ width fill, height fill, spacing 40, paddingXY 24 16, scrollbarY ]
        [ viewHeading model
        , case model.currentStep of
            GlobalSchema data ->
                viewGlobalSchema model data

            PartitioningMethod ->
                viewPartitionModes model

            ParticipatingDatabases data ->
                viewDBSelection model

            AttributeAllocations _ ->
                viewAllocations model

            Summary ->
                el [ centerX, centerY ]
                    (StyledElement.button []
                        { label = text "Save"
                        , onPress = Just Save
                        }
                    )
        ]


viewHeading : Model -> Element Msg
viewHeading model =
    column [ width fill ]
        [ el [ width fill ]
            (column [ centerX, padding 8, Font.center, Background.color (Colors.withAlpha Colors.errorRed 0.2), transparent (List.isEmpty model.problems) ]
                (List.map (\x -> text x) model.problems)
            )
        , row
            [ width fill ]
            [ StyledElement.hoverButton [ transparent (model.previousSteps == []) ]
                { title = "Back"
                , onPress = Just GoBack
                , icon = Nothing
                }
            , Element.column [ centerX ]
                [ el
                    (Style.headerStyle ++ [ centerX ])
                    (text (stepToString model.currentStep |> Tuple.first))
                , el
                    (Style.captionStyle ++ [ Font.center, centerX ])
                    (text (stepToString model.currentStep |> Tuple.second))
                ]
            , StyledElement.hoverButton
                [ alignRight
                , transparent (model.nextSteps == [])
                ]
                { title = "Next"
                , onPress = Just GoForward
                , icon = Nothing
                }
            ]
        ]


viewGlobalSchema : Model -> { a | currentField : Field, problems : List (Errors.Errors Problem) } -> Element Msg
viewGlobalSchema model { currentField, problems } =
    let
        tableHeader text =
            el
                Style.tableHeaderStyle
                (Element.text text)
    in
    column [ centerX, spacing 20 ]
        [ row [ spacing 20 ]
            [ StyledElement.textInput
                [ width
                    (fill
                        |> minimum 240
                        |> maximum 240
                    )
                ]
                { title = "Name"
                , caption = Nothing
                , errorCaption = Errors.inputErrorsFor problems "field_name" [ EmptyField ]
                , value = fieldName currentField
                , onChange = UpdatedFieldName
                , placeholder = Nothing
                , ariaLabel = ""
                , icon = Nothing
                }
            , viewTypeDropDown model
            , StyledElement.iconButton []
                { icon = Icons.add
                , iconAttrs = [ Colors.fillWhite ]
                , onPress = Just AddField
                }
            ]
        , Element.table
            [ spacing 15 ]
            { data = model.fields
            , columns =
                [ { header = tableHeader "NAME"
                  , width = fill
                  , view =
                        \field ->
                            el
                                ([ width (fill |> minimum 220) ]
                                    ++ Style.tableElementStyle
                                )
                                (Element.text (fieldName field))
                  }
                , { header = tableHeader "TYPE"
                  , width = fill
                  , view =
                        \field ->
                            el
                                ([ width (fill |> minimum 220) ]
                                    ++ Style.tableElementStyle
                                )
                                (Element.text (typeToString <| fieldToType <| field))
                  }
                ]
            }
        ]


viewTypeDropDown : Model -> Element Msg
viewTypeDropDown model =
    Dropdown.toDropDownView (typeDropDown model)


typeDropDown : Model -> ( Element Msg, Dropdown.Config Type Msg, List Type )
typeDropDown model =
    let
        problems =
            case model.currentStep of
                GlobalSchema data ->
                    data.problems

                _ ->
                    []

        types =
            [ PrimaryKey, VarChar, Double, Integer ]
    in
    StyledElement.dropDown
        [ width
            (fill
                |> minimum 250
                |> maximum 250
            )
        , alignTop
        ]
        { ariaLabel = "Select bus dropdown"
        , caption = Nothing
        , prompt = Nothing
        , dropDownMsg = TypeDropdownMsg
        , dropdownState = model.typeDropdownState
        , errorCaption = Errors.inputErrorsFor problems "primary" [ OnlyOnePrimary ]
        , icon = Nothing
        , onSelect =
            \x ->
                case x of
                    Just newType ->
                        TypeChanged newType

                    _ ->
                        NoOp
        , options = types
        , title = "Type"
        , toString = typeToString
        , isLoading = False
        }


viewPartitionModes : Model -> Element Msg
viewPartitionModes model =
    row [ width fill, height fill ]
        [ el [ width (px 200), height fill ] none
        , wrappedRow [ spacing 32, width fill, height fill, centerX ]
            [ viewMode model (Horizontal3 ( Nothing, Nothing, Nothing ))
            , viewMode model (Vertical3 ( Nothing, Nothing, Nothing ))
            , viewMode model (Vertical2Horizontal1 ( Nothing, Nothing, Nothing ))
            , viewMode model (Horizontal2Vertical1 ( Nothing, Nothing, Nothing ))
            ]
        , el [ width (px 200) ] none
        ]


viewMode : Model -> FragmentationMode -> Element Msg
viewMode model mode =
    let
        selected =
            modeToString mode == modeToString model.selectedMode

        selectedAttr =
            if selected then
                [ Border.color Colors.darkGreen
                , Border.width 1
                , Border.shadow { offset = ( 0, 12 ), size = 0, blur = 16, color = Colors.withAlpha Colors.darkGreen 0.3 }
                ]

            else
                [ Border.color (rgb 1 1 1) ]
    in
    column
        (padding 16
            :: Border.color Colors.white
            :: Border.width 1
            :: spacing 10
            :: Events.onClick (SetMode mode)
            :: Style.animatesAll
            :: selectedAttr
        )
        [ el (Style.header2Style ++ [ centerX ]) (text (modeToString mode))
        , viewMethod mode 0 False model
        ]


viewMethod : FragmentationMode -> Int -> Bool -> Model -> Element Msg
viewMethod mode scale showFieldSlots model =
    let
        borderStyle =
            if showFieldSlots then
                [ Border.solid, Border.width 2 ]

            else
                [ Border.dashed, Border.width 3 ]

        textForDB db =
            case db of
                Just db_ ->
                    el [ centerX, centerY, paddingXY 4 0 ] (text (dbName db_))

                Nothing ->
                    none

        eventsForSlot slot =
            pointer :: Events.onClick (ClearSlot slot) :: droppable { onDrop = SetFragmentDB slot, onDragOver = NoOp }

        fieldSlotsFor db_ =
            case db_ of
                Just db ->
                    fieldSlotsForDBs [ db ] db

                Nothing ->
                    []

        fieldSlotsForMaybeDBs : List (Maybe DB) -> Maybe DB -> List (Element Msg)
        fieldSlotsForMaybeDBs dbs showDB_ =
            case showDB_ of
                Just showDB ->
                    fieldSlotsForDBs
                        (List.concatMap
                            (\db ->
                                db
                                    |> Maybe.andThen (List.singleton >> Just)
                                    |> Maybe.withDefault []
                            )
                            dbs
                        )
                        showDB

                Nothing ->
                    []

        fieldSlotsForDBs : List DB -> DB -> List (Element Msg)
        fieldSlotsForDBs dbs showDB =
            let
                emptySlot =
                    el
                        ([ Border.dashed, Border.width 2, paddingXY 40 20 ]
                            ++ droppable { onDrop = AssignFieldToDBs dbs, onDragOver = NoOp }
                        )
                        (el [ width (px 1) ] none)

                matching =
                    let
                        matchingWithRepeats =
                            List.concatMap (\db -> Maybe.withDefault [] (Dict.get (dbName db) model.allocations)) [ showDB ]
                    in
                    List.foldl
                        (\match acc ->
                            if List.member match acc then
                                acc

                            else
                                match :: acc
                        )
                        []
                        matchingWithRepeats
            in
            case matching of
                [] ->
                    List.repeat (List.length model.fields - 1) emptySlot

                fields ->
                    List.map
                        (\field ->
                            el
                                [ Border.solid
                                , Border.width 2
                                , paddingXY 40 12
                                , Events.onClick (RemoveAllocation field)
                                ]
                                (text (fieldName field))
                        )
                        fields
                        ++ List.repeat (List.length model.fields - List.length fields - 1)
                            emptySlot

        slotRow =
            wrappedRow [ paddingXY 10 0, spacing 4 ]
    in
    case mode of
        Horizontal3 ( db1, db2, db3 ) ->
            column
                ([ width (px (200 + 3 * scale))
                 , spacing -3
                 ]
                    ++ (if showFieldSlots then
                            [ above (slotRow (fieldSlotsForMaybeDBs [ db1, db2, db3 ] db1)) ]

                        else
                            []
                       )
                )
                [ el
                    (borderStyle
                        ++ eventsForSlot 1
                        ++ [ width fill
                           , height (px (80 + scale))
                           ]
                    )
                    (textForDB db1)
                , el
                    (borderStyle
                        ++ eventsForSlot 2
                        ++ [ width fill, height (px (80 + scale)) ]
                     -- ++ (if showFieldSlots then
                     --         [ onRight (slotRow (fieldSlotsFor db2)) ]
                     --     else
                     --         []
                     --    )
                    )
                    (textForDB db2)
                , el
                    (borderStyle
                        ++ eventsForSlot 3
                        ++ [ width fill, height (px (80 + scale)) ]
                     -- ++ (if showFieldSlots then
                     --         [ onRight (slotRow (fieldSlotsFor db3)) ]
                     --     else
                     --         []
                     --    )
                    )
                    (textForDB db3)
                ]

        Vertical3 ( db1, db2, db3 ) ->
            row [ height (px (200 + scale)), spacing -3 ]
                [ el
                    (borderStyle
                        ++ eventsForSlot 1
                        ++ [ width (px (100 + scale)), height fill ]
                        ++ (if showFieldSlots then
                                [ above (slotRow (fieldSlotsFor db1)), width (px (100 + scale + 30)) ]

                            else
                                []
                           )
                    )
                    (textForDB db1)
                , el
                    (borderStyle
                        ++ [ width (px (100 + scale)), height fill ]
                        ++ (if showFieldSlots then
                                [ above (slotRow (fieldSlotsFor db2)), width (px (100 + scale + 30)) ]

                            else
                                []
                           )
                        ++ eventsForSlot 2
                    )
                    (textForDB db2)
                , el
                    (borderStyle
                        ++ [ width (px (100 + scale)), height fill ]
                        ++ (if showFieldSlots then
                                [ above (slotRow (fieldSlotsFor db3)), width (px (100 + scale + 30)) ]

                            else
                                []
                           )
                        ++ eventsForSlot 3
                    )
                    (textForDB db3)
                ]

        Vertical2Horizontal1 ( db1, db2, db3 ) ->
            column [ height (px (200 + scale)), spacing -3 ]
                [ row [ height (px (100 + scale)), spacing -3 ]
                    [ el
                        (borderStyle
                            ++ (if showFieldSlots then
                                    [ above (slotRow (fieldSlotsForMaybeDBs [ db1, db3 ] db1)) ]

                                else
                                    []
                               )
                            ++ eventsForSlot 1
                            ++ [ width (px (100 + scale)), height fill ]
                        )
                        (textForDB db1)
                    , el
                        (borderStyle
                            ++ (if showFieldSlots then
                                    [ above (slotRow (fieldSlotsForMaybeDBs [ db2, db3 ] db2)) ]

                                else
                                    []
                               )
                            ++ eventsForSlot 2
                            ++ [ width (px (100 + scale)), height fill ]
                        )
                        (textForDB db2)
                    ]
                , el (borderStyle ++ eventsForSlot 3 ++ [ width fill, height (px (100 + scale)) ]) (textForDB db3)
                ]

        Horizontal2Vertical1 ( db1, db2, db3 ) ->
            row [ height (px (160 - 3 + scale * 2)), spacing -3 ]
                [ el
                    (borderStyle
                        ++ eventsForSlot 1
                        ++ [ width (px (100 + scale)), height fill ]
                        ++ (if showFieldSlots then
                                [ above (slotRow (fieldSlotsFor db1)) ]

                            else
                                []
                           )
                    )
                    (textForDB db1)
                , column
                    ([ width (px (150 + scale)), spacing -3 ]
                        ++ (if showFieldSlots then
                                [ above (slotRow (fieldSlotsForMaybeDBs [ db2, db3 ] db2)) ]

                            else
                                []
                           )
                    )
                    [ el (borderStyle ++ eventsForSlot 2 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db2)
                    , el (borderStyle ++ eventsForSlot 3 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db3)
                    ]
                ]


viewDBSelection : Model -> Element Msg
viewDBSelection model =
    let
        dbs =
            List.filter
                (\x -> not (List.member (Just x) (model.selectedMode |> modeToDBs |> dbTupleToList)))
                allDBs
    in
    column [ width fill, height fill, padding 40 ]
        [ el [ centerX ] (viewMethod model.selectedMode 40 False model)
        , row [ centerX, alignBottom, spacing 10 ]
            (List.map
                (\db ->
                    el
                        (Style.header2Style
                            ++ [ paddingXY 36 8
                               , Border.width 1
                               , Font.color Colors.darkness
                               , Border.color (Colors.withAlpha Colors.darkness 0.5)
                               ]
                            ++ draggable
                                { onDragEnd = PickedUpDB Nothing
                                , onDragStart = PickedUpDB (Just db)
                                }
                        )
                        (text (dbName db))
                )
                dbs
            )
        ]


viewAllocations : Model -> Element Msg
viewAllocations model =
    let
        allocatedFields =
            List.concat (Dict.values model.allocations)

        visibleFields =
            List.filter (\f -> not (List.member f allocatedFields) && not (fieldToType f == PrimaryKey)) model.fields
    in
    row [ width fill, height fill ]
        [ viewSplitStrategySelection model
        , column [ width fill, height fill, padding 40 ]
            [ el [ height (px 100) ] none
            , el [ centerX ] (viewMethod model.selectedMode 40 True model)
            , row [ centerX, alignBottom, spacing 10 ]
                (List.map
                    (\field ->
                        el
                            (Style.header2Style
                                ++ [ paddingXY 36 8
                                   , Border.width 1
                                   , Font.color Colors.darkness
                                   , Border.color (Colors.withAlpha Colors.darkness 0.5)
                                   ]
                                ++ draggable
                                    { onDragEnd = PickedUpField Nothing
                                    , onDragStart = PickedUpField (Just field)
                                    }
                            )
                            (text (fieldName field))
                    )
                    visibleFields
                )
            ]
        ]


viewSplitStrategySelection model =
    let
        allocatedFields =
            List.concat (Dict.values model.allocations)

        visibleFields =
            List.filter (\f -> not (fieldToType f == PrimaryKey)) model.fields
    in
    case model.selectedMode of
        Vertical3 _ ->
            none

        _ ->
            let
                filterableFields =
                    List.filter (\x -> (fieldToType x == Integer || fieldToType x == Double) && Just x /= model.filterField) visibleFields
            in
            column [ width fill, height fill, padding 40, spacing 10 ]
                [ el [ height (px 10) ] none
                , case model.filterField of
                    Nothing ->
                        el ([ Border.dashed, Border.width 1, paddingXY 40 10, centerX ] ++ droppable { onDrop = SetFilterField, onDragOver = NoOp }) (text "Filter field")

                    Just field ->
                        el ([ Border.width 1, paddingXY 40 10, centerX, Events.onClick ClearFilterField ] ++ droppable { onDrop = SetFilterField, onDragOver = NoOp }) (text (fieldName field))
                , el [ centerX, centerY ] (viewStrategy model.selectedMode 40 True model)
                , row [ centerX, alignBottom, spacing 10 ]
                    (List.map
                        (\cond ->
                            el
                                (Style.header2Style
                                    ++ [ paddingXY 36 8
                                       , Border.width 1
                                       , Font.color Colors.darkness
                                       , Border.color (Colors.withAlpha Colors.darkness 0.5)
                                       , Style.monospace
                                       ]
                                    ++ draggable
                                        { onDragEnd = PickedUpCondition Nothing
                                        , onDragStart = PickedUpCondition (Just cond)
                                        }
                                )
                                (text (conditionToString cond))
                        )
                        (case model.selectedMode of
                            Horizontal3 _ ->
                                [ LessThan 0, EqualTo 0, GreaterThan 0 ]

                            _ ->
                                [ LessThan 0, LessThanOrEqualTo 0, EqualTo 0, GreaterThanOrEqualTo 0, GreaterThan 0 ]
                        )
                    )
                , el [ height (px 1), Background.color Colors.darkness, width fill ] none
                , row [ centerX, alignBottom, spacing 10 ]
                    (List.map
                        (\field ->
                            el
                                (Style.header2Style
                                    ++ [ paddingXY 36 8
                                       , Border.width 1
                                       , Font.color Colors.darkness
                                       , Border.color (Colors.withAlpha Colors.darkness 0.5)
                                       ]
                                    ++ draggable
                                        { onDragEnd = PickedUpField Nothing
                                        , onDragStart = PickedUpField (Just field)
                                        }
                                )
                                (text (fieldName field))
                        )
                        filterableFields
                    )
                ]


viewStrategy : FragmentationMode -> Int -> Bool -> Model -> Element Msg
viewStrategy mode scale showFieldSlots model =
    let
        borderStyle =
            if showFieldSlots then
                [ Border.solid, Border.width 2 ]

            else
                [ Border.dashed, Border.width 3 ]

        textForDB db =
            case db of
                Just db_ ->
                    el [ centerX, centerY, paddingXY 4 0 ] (text (dbName db_))

                Nothing ->
                    none

        conditionSlotsForDBs : Maybe DB -> Float -> Element Msg
        conditionSlotsForDBs db_ offset =
            conditionSlotsForMultipleMaybeDBs db_ [ db_ ] offset

        conditionSlotsForMultipleMaybeDBs db_ dbs offset =
            conditionSlotsForMultipleDBs db_ (List.filterMap identity dbs) offset

        conditionSlotsForMultipleDBs : Maybe DB -> List DB -> Float -> Element Msg
        conditionSlotsForMultipleDBs db_ dbs offset =
            case db_ of
                Just db ->
                    let
                        emptyConditionSlot =
                            case Maybe.withDefault Nothing (Dict.get (dbName db) model.conditions) of
                                Just ( cond, _ ) ->
                                    el
                                        ([ Border.solid
                                         , paddingXY 12 13
                                         , Border.width 2
                                         , Border.color Colors.darkGreen
                                         , Style.monospace

                                         -- , Events.onClick (RemoveAllocation field)
                                         ]
                                            ++ droppable { onDrop = SetCondition dbs, onDragOver = NoOp }
                                        )
                                        (text (conditionToString cond))

                                Nothing ->
                                    el
                                        ([ Border.dashed, Border.width 2, paddingXY 40 20 ]
                                            ++ droppable { onDrop = SetCondition dbs, onDragOver = NoOp }
                                        )
                                        (el [ width (px 1) ] none)

                        emptyValueSlot =
                            case Maybe.withDefault Nothing (Dict.get (dbName db) model.conditions) of
                                Just ( _, value ) ->
                                    FloatInput.view
                                        [ width
                                            (fill
                                                |> minimum 100
                                                |> maximum 100
                                            )
                                        , alignTop
                                        ]
                                        { title = ""
                                        , caption = Nothing
                                        , errorCaption = Nothing
                                        , value = value
                                        , onChange = UpdatedConditionValue dbs
                                        , placeholder = Nothing
                                        , ariaLabel = ""
                                        , icon = Nothing
                                        , minimum = Nothing
                                        , maximum = Nothing
                                        }

                                Nothing ->
                                    none
                    in
                    row [ moveRight offset ]
                        [ emptyConditionSlot
                        , emptyValueSlot
                        ]

                Nothing ->
                    none

        slotRow =
            wrappedRow [ paddingXY 10 0, spacing 4 ]
    in
    case mode of
        Horizontal3 ( db1, db2, db3 ) ->
            column
                [ width (px (200 + 3 * scale))
                , spacing -3
                ]
                [ el
                    (borderStyle
                        ++ [ width fill
                           , height (px (80 + scale))
                           ]
                        ++ (if showFieldSlots then
                                [ onLeft (conditionSlotsForDBs db1 -10) ]

                            else
                                []
                           )
                    )
                    (textForDB db1)
                , el
                    (borderStyle
                        ++ [ width fill, height (px (80 + scale)) ]
                        ++ (if showFieldSlots then
                                [ onLeft (conditionSlotsForDBs db2 -10) ]

                            else
                                []
                           )
                    )
                    (textForDB db2)
                , el
                    (borderStyle
                        ++ [ width fill, height (px (80 + scale)) ]
                        ++ (if showFieldSlots then
                                [ onLeft (conditionSlotsForDBs db3 -10) ]

                            else
                                []
                           )
                    )
                    (textForDB db3)
                ]

        Vertical3 _ ->
            none

        Vertical2Horizontal1 ( db1, db2, db3 ) ->
            column [ height (px (200 + scale)), spacing -3 ]
                [ row
                    ([ height (px (100 + scale)), spacing -3 ]
                        ++ (if showFieldSlots then
                                [ onLeft (conditionSlotsForMultipleMaybeDBs db1 [ db1, db2 ] -10) ]

                            else
                                []
                           )
                    )
                    [ el
                        (borderStyle
                            ++ [ width (px (100 + scale)), height fill ]
                        )
                        (textForDB db1)
                    , el
                        (borderStyle
                            ++ [ width (px (100 + scale)), height fill ]
                        )
                        (textForDB db2)
                    ]
                , el
                    (borderStyle
                        ++ [ width fill, height (px (100 + scale)) ]
                        ++ (if showFieldSlots then
                                [ onLeft (conditionSlotsForDBs db3 -10) ]

                            else
                                []
                           )
                    )
                    (textForDB db3)
                ]

        Horizontal2Vertical1 ( db1, db2, db3 ) ->
            row [ height (px (160 - 3 + scale * 2)), spacing -3 ]
                [ el
                    (borderStyle
                        ++ [ width (px (100 + scale)), height fill ]
                    )
                    (textForDB db1)
                , column
                    [ width (px (150 + scale)), spacing -3 ]
                    [ el (borderStyle ++ [ width fill, height (px (80 + scale)), onRight (conditionSlotsForDBs db2 10) ]) (textForDB db2)
                    , el (borderStyle ++ [ width fill, height (px (80 + scale)), onRight (conditionSlotsForDBs db3 10) ]) (textForDB db3)
                    ]
                ]


modeToString mode =
    case mode of
        Horizontal3 _ ->
            "Horizontal"

        Vertical3 _ ->
            "Vertical"

        Vertical2Horizontal1 _ ->
            "Hybrid 1"

        Horizontal2Vertical1 _ ->
            "Hybrid 2"


setDBs mode dbs =
    case mode of
        Horizontal3 _ ->
            Horizontal3 dbs

        Vertical3 _ ->
            Vertical3 dbs

        Vertical2Horizontal1 _ ->
            Vertical2Horizontal1 dbs

        Horizontal2Vertical1 _ ->
            Horizontal2Vertical1 dbs


modeToDBs mode =
    case mode of
        Horizontal3 dbs ->
            dbs

        Vertical3 dbs ->
            dbs

        Vertical2Horizontal1 dbs ->
            dbs

        Horizontal2Vertical1 dbs ->
            dbs


type Range
    = Inclusive Float
    | Exclusive Float


conditionToRange condition =
    let
        infinity =
            1 / 0
    in
    case condition of
        LessThan max ->
            ( Inclusive -infinity, Exclusive (toFloat max) )

        GreaterThan min ->
            ( Exclusive (toFloat min), Inclusive infinity )

        LessThanOrEqualTo max ->
            ( Inclusive -infinity, Inclusive (toFloat max) )

        GreaterThanOrEqualTo min ->
            ( Inclusive (toFloat min), Inclusive infinity )

        EqualTo value ->
            ( Inclusive (toFloat value), Inclusive (toFloat value) )


validStrategy mode conditions_ =
    let
        compareRangeMin min1 min2 =
            case ( min1, min2 ) of
                ( Inclusive min1_, Inclusive min2_ ) ->
                    compare min1_ min2_

                ( Inclusive min1_, Exclusive min2_ ) ->
                    if min1_ > min2_ then
                        GT

                    else
                        LT

                ( Exclusive min2_, Inclusive min1_ ) ->
                    if min1_ > min2_ then
                        LT

                    else
                        GT

                ( Exclusive min1_, Exclusive min2_ ) ->
                    compare min1_ min2_

        compareRangeMax min1 min2 =
            case ( min1, min2 ) of
                ( Inclusive min1_, Inclusive min2_ ) ->
                    compare min1_ min2_

                ( Inclusive min1_, Exclusive min2_ ) ->
                    if min1_ >= min2_ then
                        GT

                    else
                        LT

                ( Exclusive min2_, Inclusive min1_ ) ->
                    if min1_ >= min2_ then
                        LT

                    else
                        GT

                ( Exclusive min1_, Exclusive min2_ ) ->
                    compare min1_ min2_

        rangeValue x =
            case x of
                Exclusive y ->
                    y

                Inclusive y ->
                    y

        compareConditions : Condition -> Condition -> Order
        compareConditions cond1 cond2 =
            let
                ( min1, max1 ) =
                    conditionToRange cond1

                ( min2, max2 ) =
                    conditionToRange cond2
            in
            case compareRangeMin min1 min2 of
                EQ ->
                    compareRangeMax max1 max2

                _ ->
                    compareRangeMin min1 min2

        isComplete conditions =
            let
                sortedConditions =
                    Debug.log "sortedConditions"
                        (List.map conditionToRange (List.sortWith compareConditions conditions))

                _ =
                    Debug.log "sortedConditions" sortedConditions
            in
            List.foldl
                (\( minValue, maxValue ) ( ( oldMin, oldMax ), overlaps ) ->
                    let
                        newMin =
                            if compareRangeMin oldMin minValue /= LT && compareRangeMin oldMin maxValue /= GT then
                                minValue

                            else
                                oldMin

                        newMax =
                            if compareRangeMax oldMax maxValue /= GT && compare (rangeValue oldMax) (rangeValue minValue) /= LT then
                                maxValue

                            else
                                oldMax

                        default =
                            ( ( newMin, newMax )
                            , overlaps
                                || (case ( oldMax, minValue ) of
                                        ( Exclusive val, Inclusive val2 ) ->
                                            val > val2

                                        ( Inclusive val, Exclusive val2 ) ->
                                            val < val2

                                        _ ->
                                            True
                                   )
                            )
                    in
                    case oldMin of
                        Exclusive val ->
                            if isNaN val then
                                ( ( minValue, maxValue )
                                , False
                                )

                            else
                                default

                        _ ->
                            default
                )
                ( ( Exclusive (0 / 0), Exclusive (0 / 0) ), False )
                sortedConditions
                |> (\( ( newMin, newMax ), overlapping ) ->
                        let
                            fullRange =
                                newMin == Inclusive (-1 / 0) && newMax == Inclusive (1 / 0)
                        in
                        fullRange && not overlapping
                   )
    in
    case mode of
        Horizontal3 _ ->
            if List.length conditions_ /= 3 then
                False

            else
                isComplete conditions_

        Vertical3 _ ->
            True

        Vertical2Horizontal1 _ ->
            if List.length conditions_ /= 3 then
                False

            else
                isComplete (List.drop 1 conditions_)

        Horizontal2Vertical1 _ ->
            if List.length conditions_ /= 2 then
                False

            else
                isComplete conditions_


dbTupleToList ( db1, db2, db3 ) =
    [ db1, db2, db3 ]


typeToString fieldType =
    case fieldType of
        PrimaryKey ->
            "PrimaryKey"

        Double ->
            "Double"

        Integer ->
            "Integer"

        VarChar ->
            "String"


stepToString : Step -> ( String, String )
stepToString step =
    case step of
        GlobalSchema _ ->
            ( "Global Schema"
            , "Please provide your table's fields"
            )

        PartitioningMethod ->
            ( "Partitioning Method"
            , "Please select your preferred fragmentation method"
            )

        ParticipatingDatabases _ ->
            ( "Participating Databases"
            , "Drag and drop the databases you wish to use, tap to clear a slot"
            )

        AttributeAllocations _ ->
            ( "Attribute Allocations"
            , "Place the fields in the desired fragment.\nIf necessary, provide the horizontal fragmentation criteria"
            )

        Summary ->
            ( "Summary"
            , "Confirm your setup and save"
            )


fieldName (Field name _) =
    name


fieldToType (Field _ fieldType) =
    fieldType


dbName db =
    case db of
        PostgreSQL ->
            "Postgres"

        MySQL ->
            "MySQL"

        MariaDB ->
            "MariaDB"


allDBs : List DB
allDBs =
    [ MariaDB, PostgreSQL, MySQL ]


conditionToString condition =
    case condition of
        GreaterThan _ ->
            ">"

        LessThan _ ->
            "<"

        EqualTo _ ->
            "=="

        LessThanOrEqualTo _ ->
            "<="

        GreaterThanOrEqualTo _ ->
            ">="


applyValue condition value =
    case condition of
        GreaterThan _ ->
            GreaterThan value

        LessThan _ ->
            LessThan value

        EqualTo _ ->
            EqualTo value

        LessThanOrEqualTo _ ->
            LessThanOrEqualTo value

        GreaterThanOrEqualTo _ ->
            GreaterThanOrEqualTo value


uploadSettings : Model -> Cmd Msg
uploadSettings model =
    let
        databases =
            let
                encoder db =
                    Encode.object
                        [ ( "name", Encode.string (String.toLower (dbName db)) )

                        -- , ( "fieldType", Encode.string (fieldType field) )
                        ]
            in
            Encode.list encoder (model.selectedMode |> modeToDBs |> dbTupleToList |> List.filterMap identity)

        primaryKeyField =
            List.filter (\x -> fieldToType x == PrimaryKey) model.fields

        partitioning =
            Encode.list
                (\( k, v ) ->
                    Encode.object
                        [ ( "db", Encode.string (String.toLower k) )
                        , ( "fields", encodeFields (primaryKeyField ++ v) )
                        , ( "conditions"
                          , Dict.get k model.conditions
                                |> Maybe.withDefault Nothing
                                |> encodeConditions
                          )
                        ]
                )
                (Dict.toList
                    model.allocations
                )

        encodeConditions condition_ =
            case condition_ of
                Just ( condition, floatInput ) ->
                    Encode.object
                        [ ( "field", Encode.string (conditionToString condition) )
                        , ( "value", Encode.int (round (FloatInput.toFloat floatInput)) )
                        ]

                Nothing ->
                    Encode.object []

        encodeFields fields =
            let
                encoder field =
                    Encode.object
                        [ ( "name", Encode.string (fieldName field) )
                        , ( "fieldType", Encode.string (typeToString <| fieldToType <| field) )
                        ]
            in
            Encode.list encoder fields

        params =
            Encode.object
                [ ( "databases", databases )
                , ( "partitioning", partitioning )
                , ( "all_fields", encodeFields model.fields )
                , ( "primary_key", Encode.string (Maybe.withDefault "" (Maybe.andThen (fieldName >> Just) (List.head primaryKeyField))) )
                ]
                |> Http.jsonBody
    in
    Api.post Endpoint.setup params decoder
        |> Cmd.map ServerResponse


decoder =
    Decode.succeed ()
