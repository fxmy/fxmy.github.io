port module FxmyBody exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (style, id)
import Markdown


-- MODEL
type alias Model = {
  content_url : String,
  content : String
  }

initModel : Model
initModel = {
  {-- "/" | "/#md_entry_name" | "/link"
  representing
  blog_index | md_blog_entry | rich_js_entry
  respectively
  --}
  content_url = "",
  content = """
  """
  }


-- MESSAGES
type Msg =
  LoadURLContent String
    | BlogContent ( Result Http.Error String)


port commentit : String -> Cmd msg


-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg)
update msg model =
  case msg of
    BlogContent ( Ok blog_content) ->
      { model | content = blog_content} ! []
    BlogContent ( Err why) ->
      { model | content = "(ﾟДﾟ≡ﾟДﾟ) " ++ ( toString why)} ! []
    LoadURLContent url ->
      let
          modelNew = { model | content_url = url}
      in
          modelNew ! [ get_content modelNew, commentit_cmd modelNew]


-- VIEW
view : Model -> Html Msg
view model =
  div [] [
    h3 [][ text model.content_url],
    Markdown.toHtml [ style[ ("margin", "0 48px"), ("padding", "12px")]] model.content,
    commentit_view model
    ]


-- RENDER
render : ( Msg -> a) -> Model -> Html a
render tag model =
  Html.map tag ( view model)


-- GET_CONTENT
get_content : Model -> Cmd Msg
get_content model =
  let
      url_full = "https://fxmy.github.io/" ++ model.content_url
      request = Http.getString url_full
  in
      Http.send BlogContent request


-- SHOW_COMMENTIT
commentit_cmd : Model -> Cmd Msg
commentit_cmd model =
  if model.content_url == "blog" then
    Cmd.none
  else
    commentit model.content_url


-- COMMENTIT_VIEW
commentit_view : Model -> Html Msg
commentit_view model =
  if model.content_url == "blog" then
    text ""
  else
    div [ id "commentit"] []


-- MISC
get_content_url : Model -> String
get_content_url model =
  model.content_url

set_content_url : Model -> String -> Model
set_content_url model url =
  { model | content_url = url}
