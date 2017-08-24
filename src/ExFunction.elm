module ExFunction exposing (..)

import Ast.Expression exposing (..)
import ExContext exposing (Context, Parser, inArgs, indent)
import Dict
import Helpers exposing (..)
import ExVariable exposing (rememberVariables)


genElixirFunc :
    Context
    -> Parser
    -> String
    -> List Expression
    -> Int
    -> Expression
    -> String
genElixirFunc c elixirE name args missingArgs body =
    case ( operatorType name, args ) of
        ( Builtin, [ l, r ] ) ->
            [ (ind c.indent)
            , "def"
            , privateOrPublic c name
            , " "
            , elixirE (c |> rememberVariables [ l ]) l
            , " "
            , translateOperator name
            , " "
            , elixirE (rememberVariables [ r ] c) r
            , " do"
            , (ind <| c.indent + 1)
            , elixirE (indent c |> rememberVariables args) body
            , ind c.indent
            , "end"
            ]
                |> String.join ""

        ( Custom, _ ) ->
            [ (ind c.indent)
            , "def"
            , privateOrPublic c name
            , " "
            , translateOperator name
            , "("
            , (args
                |> List.map (c |> rememberVariables args |> elixirE)
                |> flip (++) (generateArguments missingArgs)
                |> String.join ", "
              )
            , ") do"
            , (ind <| c.indent + 1)
            , elixirE (indent c |> rememberVariables args) body
            , (generateArguments missingArgs
                |> List.map (\a -> ".(" ++ a ++ ")")
                |> String.join ""
              )
            , ind c.indent
            , "end"
            ]
                |> String.join ""

        ( Builtin, _ ) ->
            Debug.crash
                ("operator " ++ name ++ " has to have 2 arguments but has " ++ toString args)

        ( None, _ ) ->
            let
                missing =
                    generateArguments missingArgs

                wrapIfMiss s =
                    if List.length missing > 0 then
                        s
                    else
                        ""

                missingVarargs =
                    List.map (List.singleton >> Variable) missing
            in
                [ ind c.indent
                , "def"
                , privateOrPublic c name
                , " "
                , toSnakeCase True name
                , "("
                , args
                    ++ missingVarargs
                    |> List.map (c |> inArgs |> elixirE)
                    |> String.join ", "
                , ") do"
                , ind <| c.indent + 1
                , wrapIfMiss "("
                , elixirE (indent c |> rememberVariables (args ++ missingVarargs)) body
                , wrapIfMiss ")"
                , missing
                    |> List.map (\a -> ".(" ++ a ++ ")")
                    |> String.join ""
                , ind c.indent
                , "end"
                ]
                    |> String.join ""


privateOrPublic : Context -> String -> String
privateOrPublic context name =
    if ExContext.isPrivate context name then
        "p"
    else
        ""


functionCurry : Context -> Parser -> String -> Int -> String
functionCurry c elixirE name arity =
    case ( arity, ExContext.hasFlag "nocurry" name c ) of
        ( 0, _ ) ->
            ""

        ( _, True ) ->
            ""

        ( arity, False ) ->
            let
                resolvedName =
                    if isCustomOperator name then
                        translateOperator name
                    else
                        toSnakeCase True name
            in
                [ (ind c.indent)
                , "curry"
                , privateOrPublic c name
                , " "
                , resolvedName
                , "/"
                , toString arity
                ]
                    |> String.join ""


genFunctionDefinition :
    Context
    -> Parser
    -> String
    -> List Expression
    -> Expression
    -> String
genFunctionDefinition c elixirE name args body =
    let
        typeDef =
            c.definitions |> Dict.get name

        arity =
            typeDef |> Maybe.map .arity |> Maybe.withDefault 0
    in
        if ExContext.hasFlag "nodef" name c then
            functionCurry c elixirE name arity
        else
            functionCurry c elixirE name arity
                ++ genElixirFunc c elixirE name args (arity - List.length args) body
                ++ "\n"


genOverloadedFunctionDefinition :
    Context
    -> Parser
    -> String
    -> List Expression
    -> Expression
    -> List ( Expression, Expression )
    -> String
genOverloadedFunctionDefinition c elixirE name args body expressions =
    let
        typeDef =
            c.definitions |> Dict.get name

        arity =
            typeDef |> Maybe.map .arity |> Maybe.withDefault 0
    in
        if ExContext.hasFlag "nodef" name c then
            functionCurry c elixirE name arity
        else
            functionCurry c elixirE name arity
                ++ (expressions
                        |> List.map
                            (\( left, right ) ->
                                genElixirFunc c elixirE name [ left ] (arity - 1) right
                            )
                        |> List.foldr (++) ""
                        |> flip (++) "\n"
                   )


combineComas : Context -> Parser -> Expression -> String
combineComas c elixirE e =
    flattenCommas e
        |> List.map (elixirE c)
        |> String.join ", "


flattenCommas : Expression -> List Expression
flattenCommas e =
    case e of
        Tuple kvs ->
            kvs

        a ->
            [ a ]
