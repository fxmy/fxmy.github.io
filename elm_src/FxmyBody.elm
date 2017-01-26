port module FxmyBody exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (style, id)
import Markdown
import Debug
import Process
import Task
import Time exposing (Time)
import Json.Encode


-- MODEL
type alias Model = {
  content_url : String,
  content : String,
  comment_url : String,
  comment : String,
  comment_parsed : Json.Encode.Value
  }

initModel : Model
initModel = {
  {-- "/" | "/#md_entry_name" | "/link"
  representing
  blog_index | md_blog_entry | rich_js_entry
  respectively
  --}
  content_url = "",
  content = "",
  comment_url = "https://fxmy.github.io/_data/comments.yml",
  comment = "",
  comment_parsed = Json.Encode.null
  }


-- MESSAGES
type Msg =
  LoadURLContent String
    | BlogContent ( Result Http.Error String)
    | CommentContent ( Result Http.Error String)
    | LoadCommentit
    | CommentJson Json.Encode.Value


-- PORTS
port commentit : String -> Cmd msg
port parse_yml : (String, String) -> Cmd msg

port comments_json : ( Json.Encode.Value -> msg) -> Sub msg


-- SUBSCRIPTION
parse_comments : Model -> Sub Msg
parse_comments model =
  comments_json CommentJson


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
          modelNew
            ! [get_content modelNew
            , get_comment modelNew
            , delay ( Time.second*5) <| LoadCommentit]
    LoadCommentit ->
      model ! [ commentit_cmd model]
    CommentContent ( Ok comm) ->
      { model | comment = comm}
      ! [ parse_yml (comm, model.content_url)]
    CommentContent ( Err why) ->
      { model | comment = "(ﾟДﾟ≡ﾟДﾟ) " ++ ( toString why)} ! []
    CommentJson value ->
      let
          _ = Debug.log "haha" "hoho"
      in
          { model | comment_parsed = value}
          ! []


-- VIEW
view : Model -> Html Msg
view model =
  div [] [
    h3 [][ text model.content_url],
    Markdown.toHtml [ style[ ("margin", "0 48px"), ("padding", "12px")]] model.content,
    commentit_view model,
    comment_view model
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


-- GET_COMMENT
get_comment : Model -> Cmd Msg
get_comment model =
  let
      request = Http.getString model.comment_url
  in
      Http.send CommentContent request


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


-- COMMENT_VIEW
comment_view : Model -> Html Msg
comment_view model =
  if model.content_url == "blog" then
    text ""
  else
    h4 [] [ text model.comment]


-- MISC
get_content_url : Model -> String
get_content_url model =
  model.content_url

set_content_url : Model -> String -> Model
set_content_url model url =
  { model | content_url = url}

delay : Time -> msg -> Cmd msg
delay time msg =
  Process.sleep time
    |> Task.andThen (always <| Task.succeed msg)
    |> Task.perform identity
