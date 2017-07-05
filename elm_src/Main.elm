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
/707B FD10 AD37 3137 88AC  0259 BCDD 097D 01E2 D928

-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2

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
2IA=
=uoNM
-----END PGP PUBLIC KEY BLOCK-----
"""
