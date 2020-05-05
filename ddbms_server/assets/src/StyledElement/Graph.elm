module StyledElement.Graph exposing (view)

import Axis
import Colors
import Element exposing (..)
import Html.Attributes exposing (id)
import Icons exposing (IconBuilder)
import Path exposing (Path)
import Scale exposing (ContinuousScale)
import Shape
import StyledElement exposing (wrappedInput)
import Time
import TypedSvg exposing (g, svg)
import TypedSvg.Attributes exposing (class, fontFamily, stroke, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (strokeWidth)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (Paint(..), Transform(..))


{-| Adapted from <https://elm-visualization.netlify.app/linechart/>
-}
w : Float
w =
    700


h : Float
h =
    300


padding : Float
padding =
    30


xScaleBuilder : Int -> Int -> Time.Zone -> ContinuousScale Time.Posix
xScaleBuilder min max timezone =
    Scale.time timezone ( 0, w - 2 * padding ) ( Time.millisToPosix min, Time.millisToPosix max )


yScaleBuilder : Float -> ContinuousScale Float
yScaleBuilder max =
    Scale.linear ( h - 2 * padding, 0 ) ( max * 1.5, 0 )


xAxis : List a -> ContinuousScale Time.Posix -> Svg msg
xAxis model xScale =
    Axis.bottom [ Axis.tickCount (List.length model) ] xScale


yAxis : ContinuousScale Float -> Svg msg
yAxis yScale =
    Axis.left [ Axis.tickCount 5 ] yScale


transformToLineData : ContinuousScale Time.Posix -> ContinuousScale Float -> ( Time.Posix, Float ) -> Maybe ( Float, Float )
transformToLineData xScale yScale ( x, y ) =
    Just ( Scale.convert xScale x, Scale.convert yScale y )


line : List ( Time.Posix, Float ) -> ContinuousScale Time.Posix -> ContinuousScale Float -> Path
line model xScale yScale =
    List.map (transformToLineData xScale yScale) model
        |> Shape.line Shape.monotoneInXCurve


viewOutlierLines :
    { a | mean : Float, stdDev : Float }
    -> List Int
    -> Int
    -> Int
    -> ContinuousScale Time.Posix
    -> ContinuousScale Float
    -> List (Svg msg)
viewOutlierLines stats distances min max xScale yScale =
    let
        validThreshholds : List ( Int, Float )
        validThreshholds =
            List.filter (\x -> Tuple.second x > 0)
                (List.map (\x -> ( x, stats.mean - (toFloat x * stats.stdDev) )) distances)
    in
    List.map
        (\( distance, threshold ) ->
            g [ transform [ Translate padding padding ], class [ "series" ] ]
                [ Path.element
                    (line
                        [ ( Time.millisToPosix min, threshold )
                        , ( Time.millisToPosix max, threshold )
                        ]
                        xScale
                        yScale
                    )
                    (if distance == 0 then
                        [ stroke <|
                            Paint <|
                                Colors.toSVGColor Colors.sassyGrey
                        , strokeWidth 1
                        , TypedSvg.Attributes.fill PaintNone
                        ]

                     else
                        [ stroke <|
                            Paint <|
                                Colors.toSVGColor Colors.errorRed
                        , strokeWidth (toFloat distance)
                        , TypedSvg.Attributes.fill PaintNone
                        ]
                    )
                , g
                    [ transform
                        [ Translate (w - 2 * padding + 10) (Scale.convert yScale threshold + padding - 30)
                        ]
                    ]
                    [ TypedSvg.text_
                        []
                        [ TypedSvg.Core.text
                            (case distance of
                                0 ->
                                    "Average"

                                1 ->
                                    "High"

                                2 ->
                                    "Very High"

                                _ ->
                                    "Extremely High"
                            )
                        ]
                    ]
                ]
        )
        validThreshholds


view : List ( Time.Posix, Float, Float ) -> Maybe { a | mean : Float, stdDev : Float } -> Time.Zone -> Element msg
view chartData statistics timezone =
    let
        times =
            List.map
                ((\( a, _, _ ) -> a) >> Time.posixToMillis)
                chartData

        min =
            Maybe.withDefault 0 (List.minimum times)

        max =
            Maybe.withDefault (1000 * 3600 * 24) (List.maximum times)

        ( xScale, yScale ) =
            ( xScaleBuilder min max timezone
            , yScaleBuilder (Maybe.withDefault 3 (List.maximum (List.map (\( _, b, _ ) -> b) chartData)))
            )
    in
    el [ width fill, height fill ]
        (html
            (svg
                [ viewBox 0 0 (w + padding) h
                ]
                ([ g
                    [ transform [ Translate (padding - 1) (h - padding) ]
                    ]
                    [ xAxis chartData xScale ]
                 , g
                    [ transform [ Translate (padding - 1) padding ]
                    ]
                    [ yAxis yScale ]
                 , g
                    [ transform [ Translate padding padding ]
                    , class [ "series" ]
                    ]
                    [ Path.element (line (List.map (\( a, b, _ ) -> ( a, b )) chartData) xScale yScale)
                        [ stroke <|
                            Paint <|
                                Colors.toSVGColor Colors.darkGreen
                        , strokeWidth 2
                        , TypedSvg.Attributes.fill PaintNone
                        ]
                    ]
                 , g
                    [ transform [ Translate padding padding ]
                    , class [ "series" ]
                    ]
                    [ Path.element (line (List.map (\( a, _, c ) -> ( a, c )) chartData) xScale yScale)
                        [ stroke <|
                            Paint <|
                                Colors.toSVGColor Colors.sassyGrey
                        , strokeWidth 2
                        , TypedSvg.Attributes.fill PaintNone
                        ]
                    ]
                 ]
                    ++ (case List.head (List.reverse chartData) of
                            Just ( _, _, consumption ) ->
                                [ g
                                    [ transform
                                        [ Translate (w - 2 * padding + 10) (Scale.convert yScale consumption + padding - 25)
                                        ]
                                    ]
                                    [ TypedSvg.text_
                                        []
                                        [ TypedSvg.Core.text "Running Average"
                                        ]
                                    ]
                                , g
                                    [ transform
                                        [ Translate (w - 2 * padding + 10) (Scale.convert yScale consumption + padding - 15)
                                        ]
                                    ]
                                    [ TypedSvg.text_
                                        []
                                        [ TypedSvg.Core.text (String.fromFloat (round100 consumption) ++ " km/l")
                                        ]
                                    ]
                                ]

                            Nothing ->
                                []
                       )
                    ++ (case statistics of
                            Just stats ->
                                viewOutlierLines stats [ 0, 1, 2, 3 ] min max xScale yScale

                            Nothing ->
                                []
                       )
                )
            )
        )


round100 : Float -> Float
round100 float =
    toFloat (round (float * 100)) / 100
