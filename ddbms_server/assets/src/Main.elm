module Main exposing (..)

import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Element exposing (..)
import Html.Attributes exposing (src)
import Json.Decode exposing (Value)
import Models.Bus exposing (LocationUpdate)
import Navigation exposing (Route)
import Page exposing (..)
import Pages.Queries as Queries
import Pages.Setup as Setup
import Style
import Task
import Time
import Url



---- MODEL ----


type alias Model =
    { page : PageModel
    , route : Maybe Route
    , url : Url.Url
    , navKey : Nav.Key
    }


{-| Make sure to extend the updatePage method when you add a page
-}
type PageModel
    = Queries Queries.Model
    | Setup Setup.Model


init : Maybe Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init args url navKey =
    let
        ( model, cmds ) =
            changeRouteTo (Navigation.fromUrl url)
                { page = Queries (Tuple.first Queries.init)
                , route = Nothing
                , url = url
                , navKey = navKey
                }
    in
    ( model
    , Cmd.none
    )



---- UPDATE ----


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | GotSetupMsg Setup.Msg
    | GotQueriesMsg Queries.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Nav.pushUrl model.navKey (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        UrlChanged url ->
            changeRouteTo (Navigation.fromUrl url)
                { model | url = url }

        _ ->
            let
                modelMapper : PageModel -> Model
                modelMapper pageModel =
                    { model | page = pageModel }

                mapModelAndMsg pageModelMapper pageMsgMapper ( subModel, subCmd ) =
                    Page.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )
            in
            case ( msg, model.page ) of
                ( GotSetupMsg pageMsg, Setup pageModel ) ->
                    Setup.update pageMsg pageModel
                        |> mapModelAndMsg Setup GotSetupMsg

                ( GotQueriesMsg pageMsg, Queries pageModel ) ->
                    Queries.update pageMsg pageModel
                        |> mapModelAndMsg Queries GotQueriesMsg

                ( _, _ ) ->
                    ( model, Cmd.none )


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    changeRouteWithUpdatedSessionTo maybeRoute model


changeRouteWithUpdatedSessionTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteWithUpdatedSessionTo maybeRoute model =
    let
        updateWith : (subModel -> PageModel) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( PageModel, Cmd Msg )
        updateWith toModel toMsg ( subModel, subCmd ) =
            ( toModel subModel
            , Cmd.map toMsg subCmd
            )

        ( updatedPage, msg ) =
            case maybeRoute of
                Nothing ->
                    Queries.init
                        |> updateWith Queries GotQueriesMsg

                Just Navigation.Queries ->
                    Queries.init
                        |> updateWith Queries GotQueriesMsg

                Just Navigation.Setup ->
                    Setup.init model.navKey
                        |> updateWith Setup GotSetupMsg
    in
    ( { model | page = updatedPage, route = maybeRoute }, msg )



---- VIEW ----


view : Model -> Browser.Document Msg
view model =
    let
        viewPage pageContents toMsg =
            Page.frame pageContents toMsg (Navigation.fromUrl model.url)

        renderedView =
            case model.page of
                Queries pageModel ->
                    viewPage (Queries.view pageModel) GotQueriesMsg

                Setup pageModel ->
                    viewPage (Setup.view pageModel) GotSetupMsg

        layoutOptions =
            { options =
                [ focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing
                    }
                ]
            }
    in
    { title = "DDBMS Mini Project"
    , body =
        [ Element.layoutWith layoutOptions Style.labelStyle renderedView
        ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model_ =
    case model_.page of
        Queries pageModel ->
            Sub.map GotQueriesMsg (Queries.subscriptions pageModel)

        _ ->
            Sub.none


main : Program (Maybe Value) Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }
