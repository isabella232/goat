module SelectedAnnotation exposing (..)

import Array.Hamt as Array
import Expect exposing (Expectation)
import Fixtures exposing (end, model, start, aShape, testColor)
import Goat.Model
    exposing
        ( Annotation(..)
        , Drawing(..)
        , LineMode(..)
        , LineType(..)
        , Shape
        , ShapeMode(..)
        , ShapeType(..)
        , StrokeStyle(..)
        )
import Goat.Update exposing (addAnnotation, selectAnnotation, updateAnySelectedAnnotations, updateStrokeColor, updateStrokeStyle, updateFill)
import Test exposing (..)
import TestUtil exposing (getFirstAnnotation)


all : Test
all =
    describe "SelectedAnnotation Updates" [ updateAnySelectedAnnotationsTests ]


updateAnySelectedAnnotationsTests : Test
updateAnySelectedAnnotationsTests =
    describe "updateAnySelectedAnnotations"
        [ test "updates a Selected annotation" <|
            \() ->
                model
                    |> addAnnotation (Lines Arrow aShape)
                    |> selectAnnotation 0
                    |> updateAnySelectedAnnotations (updateStrokeColor testColor)
                    |> getFirstAnnotation
                    |> Maybe.map (Expect.equal (Lines Arrow <| Shape start end testColor model.strokeStyle))
                    |> Maybe.withDefault (Expect.fail "Array missing desired annotation")
        , test "does not update a NotSelected annotation" <|
            \() ->
                model
                    |> addAnnotation (Lines Arrow aShape)
                    |> updateAnySelectedAnnotations (updateStrokeStyle DashedMedium)
                    |> getFirstAnnotation
                    |> Maybe.map (Expect.equal (Lines Arrow aShape))
                    |> Maybe.withDefault (Expect.fail "Array missing desired annotation")
        , test "only updates the Selected annotation" <|
            \() ->
                model
                    |> addAnnotation (Lines Arrow aShape)
                    |> addAnnotation (Shapes Rect (Just testColor) aShape)
                    |> addAnnotation (Shapes Ellipse (Just testColor) aShape)
                    |> selectAnnotation 1
                    |> updateAnySelectedAnnotations (updateFill (Just testColor))
                    |> .edits
                    |> .present
                    |> Array.get 2
                    |> Maybe.map (Expect.equal (Shapes Ellipse (Just testColor) aShape))
                    |> Maybe.withDefault (Expect.fail "Array missing desired annotation")
        ]
