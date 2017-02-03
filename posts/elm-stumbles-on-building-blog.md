#Elm: 从无到有撸出博客时踩的那些坑#
最近也是终于把博客的评论功能折腾完了，由于站点是放在Github Pages上的，而且并没有采用Jekyll的那一套路子，要想显示评论的话就不可避免的需要借助一些外部的服务。没错，你们可能想到了Disqus。然鹅，Disqus是被墙的。(*ﾟーﾟ)

--------------------
于是再一番谷歌之后发现了这么个东西[commentit.io](https://commentit.io/)。这货的特点是它会把所有的评论以PullRequest的形式提交给你自己的repo，以merge/cherry-pick/rebase -i的形式来控制评论的感觉很赞。而且由于评论直接存在于repo里，_完全不需要备份_，爽到。

--------------------
###然鹅###
这意味着得手工写一点JS了。淦！(|||ﾟдﾟ)

--------------------
作为编译到JS的Elm自然有[与原生JS交互](https://guide.elm-lang.org/interop/javascript.html)的能力，然鹅Elm作为一个以强类型为特点的语言，与JS交互起来有着诸多的限制，例如从Elm向JS传参的时候不能传递多个，如果需要多个的话需要把参数打包进tuple里等。
废话不多说，对比一下原版和Elm版加载commentit的代码。

--------------------
```javascript
<div id="commentit"></div>
<script type="text/javascript">
/** CONFIGURATION VARIABLES **/
var commentitUsername = 'fxmy';
var commentitRepo = 'fxmy/fxmy.github.io';
var commentitPath = '{{ page.path }}';

/** DON'T EDIT FOLLOWING LINES **/
(function() {
  var commentit = document.createElement('script');
  commentit.type = 'text/javascript';
  commentit.async = true;
  commentit.src = 'https://commentit.io/static/embed/dist/commentit.js';
  (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(commentit);
  })();
</script>
```
在这里区分每篇文章的关键就是`commentitPath`。

--------------------
Elm版：
```elm
port commentit : String -> Cmd msg

update : Msg -> Model -> ( Model, Cmd Msg)
update msg model =
  case msg of
    LoadCommentit ->
      model ! [ commentit_cmd model]

-- COMMENTIT_VIEW
commentit_view : Model -> Html Msg
commentit_view model =
  if model.content_url == "blog" then
    text ""
  else
    div [ id "commentit"] []

-- SHOW_COMMENTIT
commentit_cmd : Model -> Cmd Msg
commentit_cmd model =
  if model.content_url == "blog" then
    Cmd.none
  else
    commentit model.content_url
```
以及相应的JS端
```javascript
app.ports.commentit.subscribe(function(commId){
  var old = document.getElementById('commentit');
  if( old == undefined) {
  } else {
    if(old.childNodes[0] != undefined) {
      while (old.hasChildNodes()) {
        old.removeChild(old.lastChild);
      }
    }
  }
  commentitUsername = 'fxmy';
  commentitRepo = 'fxmy/fxmy.github.io';
  commentitId = commId;
  var commentit = document.createElement('script');
  commentit.type = 'text/javascript';
  commentit.async = true;
  commentit.src = 'https://commentit.io/static/embed/dist/commentit.js';
  (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(commentit);
});
```
之所以会有辣么多的条件判断是因为在SPA下每次跳转到新文章都会加载新的评论框。所以需要把旧的清除。

--------------------
###显示评论###
评论是以YAML的格式存储的，然鹅Elm目前并没有解析YAML的库|д\` )，需要再次和JS打交道，把YAML解析成JSON。
```elm
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
    CommentContent ( Ok comm) ->
      { model | comment = comm}
      ! [ parse_yml (comm, model.content_url)]
    CommentJson value ->
      let
          commList =
            Decode.decodeValue commentDecoder value
              |> Result.withDefault []
          _ = Debug.log "LENGTH" <| List.length commList
      in
          { model | comment_parsed = List.reverse commList}
          ! []
```

--------------------
####于是到了本篇的重点： __Decode JSON in ELM__####
Elm里解析JSON的办法对于我这种不熟悉haskell的人来说显的非常的反直觉，这里并没有诸如`.`、`[]`之类直接调用的操作符，取而代之的是你需要在语言提供的一些基本Decoder的帮助下搭建出自己的Decoder，_把作为一等公民的function进行各种组合变换来达到想要的效果_，[这篇文章说的好，像搭积木一样。](https://www.brianthicks.com/post/2016/10/17/composing-decoders-like-lego/)
```elm
type alias Author = {
  type_ : String,
  displayName : String,
  url : String,
  picture : String
  }

type alias CommentEntry = {
  author : Author,
  content : String,
  date : String
  }

authorDecoder : Decode.Decoder Author
authorDecoder =
    Decode.map4 Author
      ( Decode.at ["type"] Decode.string)
      ( Decode.at ["displayName"] Decode.string)
      ( Decode.at ["url"] Decode.string)
      ( Decode.at ["picture"] Decode.string)

commentDecoder : Decode.Decoder (List CommentEntry)
commentDecoder =
  Decode.list <|
    Decode.map3 CommentEntry
    ( Decode.at ["author"] authorDecoder)
    ( Decode.at ["content"] Decode.string)
    ( Decode.at ["date"] Decode.value |> Decode.map (\v->toString v))
```
自然，作为强类型的语言，Elm对于解析之后的结果必须做好两手准备，所以运行Decoder所得的结果都属于[`Result`](https://guide.elm-lang.org/error_handling/result.html)类型。

--------------------
##然后说一下在此过程中踩到的坑##
- Turns ISO 8601 date format strings into Date.Date silently while still tags it as Json.Encode.Value when receiving JSON from ports.
- View is called after Update leads to possible race condition when a Cmd finished even before View is called while the result of the Cmd depends on the result of View. Case : initing commentit. Solution : delayed initialization of commentit.

--------------------
##WARP UP##
- One of the awesomeness of Elm is that if it compiles, it works. If it doesn't work, then there maybe logic flaws in your code.
- Need to get used to manipulating & composing functions to achieve your goal. Composing/manipulating/chaining first classed functions together into a new function is bit like squeezing octopus through coin-sized hole, doable, but brain hurting. But as long as it's done, you've got yourself a specialized hammer for this special problem, then all you need is just to BAM/SMACK/POW.
