module BlogFxmy.PostSkeleton exposing (..)

import Html exposing (..)
import Html.Attributes exposing (href, class, style)
import Material
import Material.Scheme
import Material.Button as Button
import Material.Layout as Layout
import Material.Color as Color
import Markdown


-- MODEL
type alias Model = {
  blog_content : String
  }

model : Model
model = {
  blog_content = """No Gods or Kings, only Man."""
  }


-- INIT
init : ( Model, Cmd Msg )
init =
    ( { model | blog_content = write_here}, Cmd.none )


-- MESSAGES
type Msg =
  NoOp


-- VIEW
view : Model -> Html Msg
view model =
  Markdown.toHtml [] model.blog_content


-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    NoOp ->
      ( model, Cmd.none )


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


-- WRITEHERE
write_here : String
write_here =
  """
  # This is Markdown

[Markdown](http://daringfireball.net/projects/markdown/) lets you
write content in a really natural way.

  * You can have lists, like this one
  * Make things **bold** or *italic*
  * Embed snippets of `code`
  * Create [links](/)
  * ...

The [elm-markdown][] package parses all this content, allowing you
to easily generate blocks of `Element` or `Html`.

[elm-markdown]: http://package.elm-lang.org/packages/evancz/elm-markdown/latest

  """
