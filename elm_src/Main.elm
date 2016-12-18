module BlogFxmy.Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (href, class, style)
import Material
import Material.Scheme
import Material.Button as Button
import Material.Layout as Layout
import Material.Color as Color


-- MODEL
type alias Model = {
  header_content : String,
  mdl : Material.Model,
  tab_selected : Int
  }

model : Model
model = {
  header_content = "No Gods or Kings, only Man.",
  mdl = Material.model,
  tab_selected = 0
  }


-- INIT
init : ( Model, Cmd Msg )
init =
    ( model, Cmd.none )


-- MESSAGES
type Msg =
  Mdl ( Material.Msg Msg)
    | SelectTab Int
    | NoOp


-- VIEW
view : Model -> Html Msg
view model =
  Material.Scheme.topWithScheme Color.Teal Color.Pink <|
    Layout.render Mdl model.mdl
    [ Layout.waterfall True,
      Layout.onSelectTab SelectTab,
      Layout.selectedTab model.tab_selected]
    { header = [ h1[ style[( "padding", "1rem")]] [ text model.header_content]],
      drawer = [],
      tabs = ( [ text "Blog", text "About"], [ Color.background ( Color.color Color.Teal Color.S400)]),
      main = [ view_main model]
    }

-- VIEWMAIN
view_main : Model -> Html Msg
view_main model =
  case model.tab_selected of
    0 ->
      view_blog model
    1 ->
      view_about model
    _ ->
      h3 [ style[ ("margin", "0 24px")]] [ text "404 UCCU σ`∀´)"]

-- VIEWBLOG
view_blog : Model -> Html Msg
view_blog model =
  h3 [ style[ ("margin", "0 24px")]] [ text "此乃蒹葭 (〃∀〃)"]


-- VIEWABOUT
view_about : Model -> Html Msg
view_about model =
  h2 [ style[ ("margin", "0 24px")]] [ text "fxmywc@gmail.com (`ε´ )"]

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    NoOp ->
      ( model, Cmd.none )
    SelectTab num ->
      { model | tab_selected = num} ! []
    Mdl msg_mdl ->
      Material.update msg_mdl model


-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


-- MAIN
main : Program Never Model Msg
main =
  program {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions
    }
