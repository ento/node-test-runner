module Test.Reporter.Console.Format exposing (format, highlightEqual)

import Test.Reporter.Highlightable as Highlightable exposing (Highlightable)
import Test.Runner.Failure exposing (InvalidReason(BadDescription), Reason(..))


format :
    (List (Highlightable String) -> List (Highlightable String) -> ( String, String ))
    -> String
    -> Reason
    -> String
format formatEquality description reason =
    case reason of
        Custom ->
            description

        Equality expected actual ->
            case highlightEqual expected actual of
                Nothing ->
                    verticalBar description expected actual

                Just ( highlightedExpected, highlightedActual ) ->
                    let
                        ( formattedExpected, formattedActual ) =
                            formatEquality highlightedExpected highlightedActual
                    in
                    verticalBar description formattedExpected formattedActual

        Comparison first second ->
            verticalBar description first second

        TODO ->
            description

        Invalid BadDescription ->
            if description == "" then
                "The empty string is not a valid test description."
            else
                "This is an invalid test description: " ++ description

        Invalid _ ->
            description

        ListDiff expected actual ->
            listDiffToString 0
                description
                { expected = expected
                , actual = actual
                }
                { originalExpected = expected
                , originalActual = actual
                }

        CollectionDiff { expected, actual, extra, missing } ->
            let
                extraStr =
                    if List.isEmpty extra then
                        ""
                    else
                        "\nThese keys are extra: "
                            ++ (extra |> String.join ", " |> (\d -> "[ " ++ d ++ " ]"))

                missingStr =
                    if List.isEmpty missing then
                        ""
                    else
                        "\nThese keys are missing: "
                            ++ (missing |> String.join ", " |> (\d -> "[ " ++ d ++ " ]"))
            in
            String.join ""
                [ verticalBar description expected actual
                , "\n"
                , extraStr
                , missingStr
                ]


highlightEqual : String -> String -> Maybe ( List (Highlightable String), List (Highlightable String) )
highlightEqual expected actual =
    if expected == "\"\"" || actual == "\"\"" then
        -- Diffing when one is the empty string looks silly. Don't bother.
        Nothing
    else if isFloat expected && isFloat actual then
        -- Diffing numbers looks silly. Don't bother.
        Nothing
    else
        let
            expectedChars =
                String.toList expected

            actualChars =
                String.toList actual
        in
        Just
            ( Highlightable.diffLists expectedChars actualChars
                |> List.map (Highlightable.map String.fromChar)
            , Highlightable.diffLists actualChars expectedChars
                |> List.map (Highlightable.map String.fromChar)
            )


isFloat : String -> Bool
isFloat str =
    case String.toFloat str of
        Ok _ ->
            True

        Err _ ->
            False


listDiffToString :
    Int
    -> String
    -> { expected : List String, actual : List String }
    -> { originalExpected : List String, originalActual : List String }
    -> String
listDiffToString index description { expected, actual } originals =
    case ( expected, actual ) of
        ( [], [] ) ->
            [ "Two lists were unequal previously, yet ended up equal later."
            , "This should never happen!"
            , "Please report this bug to https://github.com/elm-community/elm-test/issues - and include these lists: "
            , "\n"
            , toString originals.originalExpected
            , "\n"
            , toString originals.originalActual
            ]
                |> String.join ""

        ( first :: _, [] ) ->
            verticalBar (description ++ " was shorter than")
                (toString originals.originalExpected)
                (toString originals.originalActual)

        ( [], first :: _ ) ->
            verticalBar (description ++ " was longer than")
                (toString originals.originalExpected)
                (toString originals.originalActual)

        ( firstExpected :: restExpected, firstActual :: restActual ) ->
            if firstExpected == firstActual then
                -- They're still the same so far; keep going.
                listDiffToString (index + 1)
                    description
                    { expected = restExpected
                    , actual = restActual
                    }
                    originals
            else
                -- We found elements that differ; fail!
                String.join ""
                    [ verticalBar description
                        (toString originals.originalExpected)
                        (toString originals.originalActual)
                    , "\n\nThe first diff is at index "
                    , toString index
                    , ": it was `"
                    , firstActual
                    , "`, but `"
                    , firstExpected
                    , "` was expected."
                    ]


verticalBar : String -> String -> String -> String
verticalBar comparison expected actual =
    [ actual
    , "╷"
    , "│ " ++ comparison
    , "╵"
    , expected
    ]
        |> String.join "\n"
