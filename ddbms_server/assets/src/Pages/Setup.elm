module Pages.Setup exposing (Model, Msg, init, update, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Errors
import Icons
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
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
    | Bool


type DB
    = PostgreSQL
    | MySQL
    | MariaDB


type FragmentationMode
    = Horizontal3 ( Maybe DB, Maybe DB, Maybe DB )
    | Vertical3 ( Maybe DB, Maybe DB, Maybe DB )
    | Vertical2Horizontal1 ( Maybe DB, Maybe DB, Maybe DB )
    | Horizontal2Vertical1 ( Maybe DB, Maybe DB, Maybe DB )


init : ( Model, Cmd msg )
init =
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
            , Summary
            ]
      , typeDropdownState = Dropdown.init "" (Just PrimaryKey)
      , fields = []
      , selectedMode = Vertical3 ( Nothing, Nothing, Nothing )
      , problems = []
      }
    , Cmd.none
    )



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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
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
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetFragmentDB slot ->
            let
                _ =
                    Debug.log "SetFragmentDB" slot

                _ =
                    Debug.log "SetFragmentDB" model.selectedMode
            in
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
                ParticipatingDatabases _ ->
                    ( { model
                        | currentStep =
                            ParticipatingDatabases { pickedUpDB = db }
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

            _ ->
                el [] (text "Welcome")
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
            [ PrimaryKey, VarChar, Double, Integer, Bool ]
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


viewPartitionModes : { a | selectedMode : FragmentationMode } -> Element Msg
viewPartitionModes { selectedMode } =
    row [ width fill ]
        [ el [ width fill ] none
        , wrappedRow [ spacing 32, width fill ]
            [ viewMode (Horizontal3 ( Nothing, Nothing, Nothing )) selectedMode
            , viewMode (Vertical3 ( Nothing, Nothing, Nothing )) selectedMode
            , viewMode (Vertical2Horizontal1 ( Nothing, Nothing, Nothing )) selectedMode
            , viewMode (Horizontal2Vertical1 ( Nothing, Nothing, Nothing )) selectedMode
            ]
        , el [ width fill ] none
        ]


viewMode mode selectedMode =
    let
        selected =
            modeToString mode == modeToString selectedMode

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
        , viewMethod mode 0
        ]


viewMethod mode scale =
    let
        borderStyle =
            [ Border.dashed
            , Border.width 3
            ]

        textForDB db =
            case db of
                Just db_ ->
                    el [ centerX, centerY, paddingXY 4 0 ] (text (dbName db_))

                Nothing ->
                    none

        eventsForSlot slot =
            pointer :: Events.onClick (ClearSlot slot) :: droppable { onDrop = SetFragmentDB slot, onDragOver = NoOp }
    in
    case mode of
        Horizontal3 ( db1, db2, db3 ) ->
            column [ width (px (200 + 3 * scale)), spacing -3 ]
                [ el (borderStyle ++ eventsForSlot 1 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db1)
                , el (borderStyle ++ eventsForSlot 2 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db2)
                , el (borderStyle ++ eventsForSlot 3 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db3)
                ]

        Vertical3 ( db1, db2, db3 ) ->
            row [ height (px (200 + scale)), spacing -3 ]
                [ el (borderStyle ++ eventsForSlot 1 ++ [ width (px (100 + scale)), height fill ]) (textForDB db1)
                , el (borderStyle ++ eventsForSlot 2 ++ [ width (px (100 + scale)), height fill ]) (textForDB db2)
                , el (borderStyle ++ eventsForSlot 3 ++ [ width (px (100 + scale)), height fill ]) (textForDB db3)
                ]

        Vertical2Horizontal1 ( db1, db2, db3 ) ->
            column [ height (px (200 + scale)), spacing -3 ]
                [ el (borderStyle ++ eventsForSlot 1 ++ [ width fill, height (px (100 + scale)) ]) (textForDB db1)
                , row [ height (px (100 + scale)), spacing -3 ]
                    [ el (borderStyle ++ eventsForSlot 2 ++ [ width (px (100 + scale)), height fill ]) (textForDB db2)
                    , el (borderStyle ++ eventsForSlot 3 ++ [ width (px (100 + scale)), height fill ]) (textForDB db3)
                    ]
                ]

        Horizontal2Vertical1 ( db1, db2, db3 ) ->
            row [ height (px (160 - 3 + scale * 2)), spacing -3 ]
                [ el
                    (borderStyle
                        ++ eventsForSlot 1
                        ++ [ width (px (100 + scale)), height fill ]
                    )
                    (textForDB db1)
                , column
                    [ width (px (150 + scale)), spacing -3 ]
                    [ el (borderStyle ++ eventsForSlot 2 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db2)
                    , el (borderStyle ++ eventsForSlot 3 ++ [ width fill, height (px (80 + scale)) ]) (textForDB db3)
                    ]
                ]


viewDBSelection { selectedMode } =
    let
        dbs =
            List.filter
                (\x -> not (List.member (Just x) (selectedMode |> modeToDBs |> dbTupleToList)))
                [ MariaDB, PostgreSQL, MySQL ]
    in
    column [ width fill, height fill, padding 40 ]
        [ el [ centerX ] (viewMethod selectedMode 40)
        , el [ centerX, padding 20 ] (text "Tap to clear a slot")
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


viewAllocations { selectedMode } =
    let
        dbs =
            List.filter
                (\x -> not (List.member (Just x) (selectedMode |> modeToDBs |> dbTupleToList)))
                [ MariaDB, PostgreSQL, MySQL ]

        _ =
            Debug.log "" dbs
    in
    column [ width fill, height fill, padding 40 ]
        [ el [ centerX ] (viewMethod selectedMode 40)
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

        Bool ->
            "Bool"


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
            , "Drag and drop the databases you wish to use"
            )

        AttributeAllocations ->
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
            "PostgreSQL"

        MySQL ->
            "MySQL"

        MariaDB ->
            "MariaDB"
