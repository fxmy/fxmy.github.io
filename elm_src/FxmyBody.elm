port module FxmyBody exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (style, id, src, href, height, width)
import Markdown
import Debug
import Process
import Task
import Time exposing (Time)
import Json.Decode as Decode
import Json.Decode.Extra as DecodeExtra
import Date
import ElmEscapeHtml exposing (unescape)
import Maybe exposing (Maybe)


-- MODEL
type alias Author = {
  type_ : String,
  displayName : String,
  url : String,
  picture : String
  }

type alias CommentEntry = {
  author : Author,
  content : String,
  date : Date.Date
  }

type alias Model = {
  content_url : String,
  content : String,
  comment_url : String,
  comment : String,
  comment_parsed : List CommentEntry
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
  comment_parsed = []
  }


-- MESSAGES
type Msg =
  LoadURLContent String
    | BlogContent ( Result Http.Error String)
    | CommentContent ( Result Http.Error String)
    | LoadCommentit
    | CommentJson String


-- PORTS
port commentit : String -> Cmd msg
port parse_yml : (String, String) -> Cmd msg

port comments_json : ( String -> msg) -> Sub msg


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
    CommentJson string ->
      let
          commList = --Decode.decodeValue commentDecoder value
            Decode.decodeString commentDecoder string
              |> Result.withDefault (Maybe.Just [])
              |> Maybe.withDefault []
          _ = Debug.log "LENGTH" <| List.length commList
      in
          { model | comment_parsed = List.reverse commList}
          ! []


-- VIEW
view : Model -> Html Msg
view model =
  div [ style[ ("margin", "0 48px"), ("padding", "12px")]] [
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
    div [ id "comments"]
    (List.map comment_entry_view model.comment_parsed)


-- COMMENT_ENTRY_VIEW
comment_entry_view : CommentEntry -> Html Msg
comment_entry_view entry =
  div[]
  [ img [src entry.author.picture, height 40, width 40] []
  , a [ href entry.author.url,style [("margin", "0 6px"), ("padding", "12px")]]
    [ text entry.author.displayName]
  , br [] []
  , span [] [ text <| toString entry.date]
  , br [] []
  , h5 [] [text <| unescape entry.content]
  , hr [] []
    ]

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

authorDecoder : Decode.Decoder Author
authorDecoder =
    Decode.map4 Author
      ( Decode.at ["type"] Decode.string)
      ( Decode.at ["displayName"] Decode.string)
      ( Decode.at ["url"] Decode.string)
      ( Decode.at ["picture"] Decode.string)

commentDecoder : Decode.Decoder (Maybe (List CommentEntry))
commentDecoder =
  (Decode.list <|
    Decode.map3 CommentEntry
    ( Decode.at ["author"] authorDecoder)
    ( Decode.at ["content"] Decode.string)
    ( Decode.at ["date"] DecodeExtra.date))
    |> Decode.maybe
