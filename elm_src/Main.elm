module FxmyHeader exposing (..)

import Html exposing (..)
import Html.Attributes exposing (href, class, style)
import Material
--import Material.Scheme
--import Material.Button as Button
import Material.Layout as Layout
import Material.Color as Color
import Material.Options as Options exposing (css)
import Material.Grid as Grid

import Navigation
import RouteUrl as Routing

import FxmyBody as Body


-- MODEL
type alias Model = {
  header_content : String,
  mdl : Material.Model,
  tab_selected : Int,
  body : Body.Model
  }

initModel : Model
initModel = {
  header_content = "No Gods or Kings, only Man.",
  mdl = Material.model,
  tab_selected = 0,
  body = Body.initModel
  }


-- MESSAGES
type Msg =
  Mdl ( Material.Msg Msg)
    | SelectTab Int
    | BodyMsg Body.Msg
    | DisplayTab Int
{-- DispalyTab is side effect free, while
    SelectTab fires xhr http request via Cmd
--}


-- VIEW
view : Model -> Html Msg
view model =
  --Material.Scheme.topWithScheme Color.Teal Color.Pink <|
    Layout.render Mdl model.mdl
    [ Layout.fixedHeader,
      Layout.waterfall True,
      Layout.onSelectTab SelectTab,
      Layout.selectedTab model.tab_selected]
    { header = [ Layout.row[ css "height" "152px", css "transition" "height 333ms ease-in-out 500ms"]
                           [ h1[ style[( "padding", "1rem")]]
                               [ text model.header_content],
                             Layout.spacer,
                             Layout.navigation[]
                                              [ Layout.link[ Layout.href "https://fxmy.github.io/rss.xml"]
                                                           [ h5[][text "RSS"]]
                                              ]
                            ]
                ],
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
  Body.render BodyMsg model.body


-- VIEWABOUT
view_about : Model -> Html Msg
view_about model =
  div [] [
    h2 [ style[ ("margin", "0 24px")]]
      [
        p [] [],
        text "fxmywc@gmail.com (`ε´ )"
        ]
    , p [] []
    , [ Grid.cell[ Grid.size Grid.All 4 ][ pre [class "gpg"] [text pub_key]]]
    |> Grid.grid []
    ]


-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    SelectTab 0 ->
      let
          bodyNew = Body.set_content_url model.body "blog"
      in
          { model | tab_selected = 0, body = bodyNew}
          ! [ Cmd.map BodyMsg (Body.get_content bodyNew)]
    SelectTab num ->
      { model | tab_selected = num} ! []
    DisplayTab num ->
      { model | tab_selected = num} ! []
    Mdl msg_mdl ->
      Material.update msg_mdl model
    BodyMsg msg_body ->
      let
          ( newBodyModel, bodyCmd) =
            Body.update msg_body model.body
      in
          { model | body = newBodyModel} ! [ Cmd.map BodyMsg bodyCmd]

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ Sub.map BodyMsg ( Body.parse_comments model.body)]


-- ROUTING
delta2url : Model -> Model -> Maybe Routing.UrlChange
delta2url modelOld modelNew =
  if modelOld.tab_selected /= modelNew.tab_selected then
    let
        urlNew =
          case modelNew.tab_selected of
            0 ->
              "#blog"-- ++ Body.get_content_url modelNew.body
            1 ->
              "#about"
            _ ->
              "https://www.destroyallsoftware.com/talks/wat"
    in
        Just { entry = Routing.NewEntry, url = urlNew}
  else if modelNew.tab_selected == 0 && Body.get_content_url modelOld.body /= Body.get_content_url modelNew.body then
    let
        urlNew = "#" ++ Body.get_content_url modelNew.body
    in
        Just { entry = Routing.NewEntry, url = urlNew}
  else
    Nothing

location2messages : Navigation.Location -> List Msg
location2messages location =
  case String.dropLeft 1 location.hash of
    "" ->
      [ SelectTab 0]
    "about" ->
      [ SelectTab 1]
    str ->
      [ BodyMsg (Body.LoadURLContent str), DisplayTab 0]


-- MAIN
main : Routing.RouteUrlProgram Never Model Msg
main =
  Routing.program {
    delta2url = delta2url,
    location2messages = location2messages,
    init = ( initModel, Cmd.none),
    view = view,
    update = update,
    subscriptions = subscriptions
    }


pub_key : String
pub_key =
  """
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2

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
g5c0hFX4ocqTYSkc2uG/Ls+ncfw=
=0Ak9
-----END PGP PUBLIC KEY BLOCK-----
  """
