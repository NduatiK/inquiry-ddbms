module Utils.Validator exposing (isValidEmail, isValidImei, isValidNumberPlate, isValidPhoneNumber)

import Regex


matchOnPattern pattern =
    Regex.fromString pattern
        |> Maybe.withDefault Regex.never
        |> Regex.contains


isValidEmail : String -> Bool
isValidEmail =
    let
        pattern =
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
    in
    matchOnPattern pattern


isValidPhoneNumber : String -> Bool
isValidPhoneNumber =
    let
        pattern =
            "^(?:254|\\+254|0)?(7[0-9]{8})$"
    in
    matchOnPattern pattern


isValidNumberPlate : String -> Bool
isValidNumberPlate =
    let
        letters =
            "ABCDEFGHJKLMNPQRSTUVWXYZ"

        pattern =
            "^K[" ++ letters ++ "]{2}\\d{3}[" ++ letters ++ "]{0,1}$"
    in
    matchOnPattern pattern


isValidImei : String -> Bool
isValidImei imei =
    let
        imei_lengths =
            [ 15, 17 ]

        is_valid_length =
            List.member (String.length imei) imei_lengths

        luhns_sum int =
            luhns_sum_ (String.fromInt int) 0 True

        luhns_sum_ : String -> Int -> Bool -> Int
        luhns_sum_ array sum oddPosition =
            case String.uncons array of
                Nothing ->
                    sum

                Just ( head, tail ) ->
                    if oddPosition then
                        case String.toInt (String.fromChar head) of
                            Nothing ->
                                luhns_sum_ tail sum (not oddPosition)

                            Just int ->
                                luhns_sum_ tail (sum + int) (not oddPosition)

                    else
                        case String.toInt (String.fromChar head) of
                            Nothing ->
                                luhns_sum_ tail sum (not oddPosition)

                            Just int ->
                                luhns_sum_ tail (sum + sum_of_double int) (not oddPosition)

        sum_of_double x =
            let
                sum_of_double_ char acc =
                    case String.toInt (String.fromChar char) of
                        Nothing ->
                            acc

                        Just int ->
                            acc + int
            in
            (x * 2) |> String.fromInt |> String.foldl sum_of_double_ 0
    in
    -- Regex.contains regex email
    case String.toInt imei of
        Just imei_number ->
            is_valid_length && (imei_number |> luhns_sum |> Basics.remainderBy 10) == 0

        Nothing ->
            False
