module Goat.View.DrawingArea exposing (viewDrawingArea, viewAnnotationMenu)

import Array.Hamt as Array exposing (Array)
import Color
import Goat.Annotation exposing (Annotation(Pixelate), Drawing(DrawPixelate), ShapeType, Shape, spotlightToMaskCutout)
import Goat.Annotation.Shared exposing (AnnotationAttributes, DrawingInfo)
import Goat.EditState as EditState exposing (DrawingConfig, EditState)
import Goat.Flags exposing (Image)
import Goat.Update exposing (Msg(..), getFirstSpotlightIndex, isSpotlightDrawing)
import Goat.View.DrawingArea.Annotation as Annotation exposing (viewAnnotation)
import Goat.View.DrawingArea.Definitions as Definitions
import Goat.View.Utils exposing (toPx)
import Html exposing (Attribute, Html, button, div, h2, h3, img, li, p, text, ul)
import Html.Attributes exposing (attribute, class, classList, disabled, id, src, style)
import Html.Events exposing (onClick, onMouseEnter, onWithOptions)
import Mouse exposing (Position)
import Svg exposing (Svg, circle, defs, foreignObject, marker, rect, svg)
import Svg.Attributes as Attr


viewPixelatedImage : Image -> Svg Msg
viewPixelatedImage { width, height, url } =
    Svg.image
        [ Attr.width (toString (round width))
        , Attr.height (toString (round height))
        , Attr.xlinkHref url
        , Attr.filter "url(#pixelate)"
        ]
        []


viewImage : Image -> Svg Msg
viewImage { url, width, height } =
    Svg.image
        [ Attr.class "image-to-annotate"
        , Attr.width (toString (round width))
        , Attr.height (toString (round height))
        , Attr.xlinkHref url
        , Attr.mask "url(#pixelateMask)"
        ]
        []


drawingConfig : DrawingConfig Msg
drawingConfig =
    { startDrawing = StartDrawing
    , continueDrawing = ContinueDrawing
    , finishDrawing = FinishDrawing
    , continueMoving = MoveAnnotation
    , finishMoving = FinishMovingAnnotation
    , continueResizing = ResizeAnnotation
    , finishResizing = FinishResizingAnnotation
    , finishEditingText = FinishEditingText
    , contextMenu = ToggleAnnotationMenu
    }


canvasAttributes : Drawing -> EditState -> List (Svg.Attribute Msg)
canvasAttributes drawing editState =
    [ id "canvas"
    , class "image-edit"
    , Html.Events.onMouseDown CloseDropdown
    , Html.Attributes.contextmenu "annotation-menu"
    ]
        ++ EditState.drawingEvents drawingConfig editState


viewAnnotations : Array Annotation -> List (Svg Msg) -> List (Svg Msg) -> Bool -> List (Svg Msg)
viewAnnotations annotations spotlights nonSpotlights isDrawingSpotlight =
    let
        firstSpotlightIndex =
            getFirstSpotlightIndex annotations
    in
        if isDrawingSpotlight && List.isEmpty spotlights then
            nonSpotlights ++ [ viewMask ]
        else if List.isEmpty spotlights then
            nonSpotlights
        else
            List.take firstSpotlightIndex nonSpotlights
                ++ (viewMask :: List.drop firstSpotlightIndex nonSpotlights)


type alias Spotlights =
    List (Svg Msg)


type alias Pixelates =
    List (Svg Msg)


type alias Annotations =
    List (Svg Msg)


type alias IsInMask =
    Bool


viewDrawingAndAnnotations :
    Image
    -> Spotlights
    -> Pixelates
    -> Annotations
    -> Bool
    -> (IsInMask -> Svg Msg)
    -> List (Svg Msg)
viewDrawingAndAnnotations image spotlights pixelates annotations isSpotlight toDrawing =
    if isSpotlight then
        [ Definitions.view (spotlights ++ [ toDrawing True ]) pixelates ]
            ++ (viewPixelatedImage image :: viewImage image :: annotations)
            ++ [ toDrawing False ]
    else
        [ Definitions.view spotlights pixelates ]
            ++ (viewPixelatedImage image :: viewImage image :: annotations)
            ++ [ toDrawing False ]


insertIfPixelate : Array Annotation -> List (Svg Msg) -> List (Svg Msg) -> Drawing -> DrawingInfo -> ( Array Annotation, List (Svg Msg) )
insertIfPixelate annotations spotlights nonSpotlights drawing { start, curPos } =
    case drawing of
        DrawPixelate ->
            ( Array.push (Pixelate start curPos) annotations
            , viewAnnotations annotations spotlights nonSpotlights (isSpotlightDrawing drawing)
            )

        _ ->
            ( annotations, viewAnnotations annotations spotlights nonSpotlights (isSpotlightDrawing drawing) )


viewSpotlights : EditState -> Array Annotation -> List (Svg Msg)
viewSpotlights editState annotations =
    annotations
        |> Array.toIndexedList
        |> List.filterMap (Maybe.map (viewMaskCutOut editState) << spotlightToMaskCutout)


viewMaskCutOut : EditState -> ( Int, ShapeType, Shape ) -> Svg Msg
viewMaskCutOut editState ( index, shapeType, shape ) =
    Annotation.viewShape (EditState.annotationEvents (Annotation.annotationConfig index) index editState) shapeType (Just Color.black) shape


viewNonSpotlightAnnotations : EditState -> Array Annotation -> List (Svg Msg)
viewNonSpotlightAnnotations editState annotations =
    let
        annotationsAndVertices =
            annotations
                |> Array.toList
                |> List.indexedMap (Annotation.viewAnnotation editState)
    in
        List.map Tuple.first annotationsAndVertices
            ++ List.filterMap Tuple.second annotationsAndVertices


viewPixelates : EditState -> Array Annotation -> List (Svg Msg)
viewPixelates editState annotations =
    annotations
        |> Array.toIndexedList
        |> List.filterMap (uncurry (Annotation.viewPixelate editState))
        |> List.concat


viewDrawingArea : Annotation.DrawingModifiers -> Array Annotation -> AnnotationAttributes -> Image -> Html Msg
viewDrawingArea ({ drawing, constrain, editState } as drawingModifiers) annotations annotationAttrs image =
    let
        toDrawing =
            Annotation.viewDrawing editState drawingModifiers annotationAttrs

        spotlights =
            viewSpotlights editState annotations

        ( pixelates, svgAnnotations ) =
            editState
                |> EditState.viewDrawing (insertIfPixelate annotations spotlights nonSpotlights drawing)
                |> Maybe.withDefault ( annotations, viewAnnotations annotations spotlights nonSpotlights False )
                |> Tuple.mapFirst (viewPixelates editState)

        nonSpotlights =
            viewNonSpotlightAnnotations editState annotations
    in
        div
            (canvasAttributes drawing editState)
            [ svg
                [ Attr.id "drawing"
                , Attr.class "drawing"
                , Attr.width (toString (round image.width))
                , Attr.height (toString (round image.height))
                , attribute "xmlns" "http://www.w3.org/2000/svg"
                ]
                (viewDrawingAndAnnotations image spotlights pixelates svgAnnotations (isSpotlightDrawing drawing) toDrawing)
            ]


viewMask : Svg msg
viewMask =
    rect
        [ Attr.x "0"
        , Attr.y "0"
        , Attr.height "100%"
        , Attr.width "100%"
        , Attr.mask "url(#Mask)"
        , Attr.style "pointer-events: none;"
        ]
        []


viewAnnotationMenu : Position -> Maybe Int -> Html Msg
viewAnnotationMenu pos selectedIndex =
    div
        [ id "annotation-menu"
        , class "annotation-menu"
        , style
            [ ( "top", toPx pos.y )
            , ( "left", toPx pos.x )
            ]
        ]
        [ ul [ class "annotation-menu__list" ]
            (case selectedIndex of
                Just index ->
                    [ viewAnnotationMenuItem (BringAnnotationToFront index) "Bring to Front"
                    , viewAnnotationMenuItem (SendAnnotationToBack index) "Send to Back"
                    ]

                Nothing ->
                    [ viewDisabledAnnotationMenuItem "Bring to Front"
                    , viewDisabledAnnotationMenuItem "Send to Back"
                    ]
            )
        ]


viewDisabledAnnotationMenuItem : String -> Html Msg
viewDisabledAnnotationMenuItem buttonText =
    li [ class "annotation-menu__item" ]
        [ button
            [ class "annotation-menu__button"
            , disabled True
            ]
            [ text buttonText ]
        ]


viewAnnotationMenuItem : Msg -> String -> Html Msg
viewAnnotationMenuItem msg buttonText =
    li [ class "annotation-menu__item" ]
        [ button
            [ class "annotation-menu__button"
            , onClick msg
            ]
            [ text buttonText ]
        ]
