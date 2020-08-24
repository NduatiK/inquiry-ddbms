module Navigation exposing (Route(..), fromUrl, href, pushUrl, replaceUrl, rerouteTo)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, oneOf, s)


{-|

    A module for moving between pages by changing the URL

-}
type Route
    = Queries
    | Setup


pageParser : Parser (Route -> a) a
pageParser =
    oneOf
        (Parser.map Queries Parser.top
            :: parsersFor [ Queries, Setup ]
        )


parsersFor : List Route -> List (Parser (Route -> c) c)
parsersFor routes =
    List.map buildParser routes


buildParser route =
    Parser.map route (s (routeName route))



-- PUBLIC HELPERS


href : Route -> String
href targetRoute =
    routeToString targetRoute


{-| replaceUrl : Key -> String -> Cmd msg
Change the URL, but do not trigger a page load.

This will not add a new entry to the browser history.

This can be useful if you have search box and you want the ?search=hats in
the URL to match without adding a history entry for every single key
stroke. Imagine how annoying it would be to click back
thirty times and still be on the same page!

-}
replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


{-| Change the URL, but do not trigger a page load.

This will add a new entry to the browser history.

**Note:** If the user has gone `back` a few pages, there will be &ldquo;future
pages&rdquo; that the user can go `forward` to. Adding a new URL in that
scenario will clear out any future pages. It is like going back in time and
making a different choice.

-}
pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (routeToString route)


parseUrl : Url -> Url
parseUrl url =
    let
        parts =
            case url.fragment of
                Just fragment ->
                    String.split "?" fragment

                Nothing ->
                    [ "", "" ]

        query =
            Maybe.withDefault "" (List.head (List.drop 1 parts))

        path =
            Maybe.withDefault "" (List.head parts)
    in
    { url | path = path, fragment = Nothing, query = Just query }


fromUrl : Url -> Maybe Route
fromUrl url =
    let
        newUrl =
            parseUrl url

        route =
            Parser.parse pageParser newUrl
    in
    route


rerouteTo : Nav.Key -> Route -> Cmd msg
rerouteTo navKey route =
    Nav.pushUrl
        navKey
        (routeToString route)



-- INTERNAL


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Queries ->
                    []

                Setup ->
                    [ "setup" ]
    in
    "#/" ++ String.join "/" pieces


routeName : Route -> String
routeName page =
    case page of
        Queries ->
            ""

        Setup ->
            "setup"
