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
- 在从ports接收JSON的时候Elm会把ISO 8601 date format的字符串悄咪咪的转换成Date类型，然鹅并没有提供Decode.date的方法，编译器仍然认为他的类型是Json.Encode.Value，最后只好用丑陋的`Decode.at ["date"] Decode.value |> Decode.map (\v->toString v)`形式强行按照string显示。
- Elm的架构设计决定了View是在Update之后调用的，那么当Update返回带有副作用的Cmd msg时，如果副作用在View之前执行结束就会出现race condition。一个典型的例子是通过ports加载commentit的时候在墙外会报错找不到commentit的div，而在墙内由于加载速度慢反而不会出现问题（肥肠感谢，GFW）。最后也是采用了延迟加载的办法。

--------------------
##总结##
- Elm很屌的一个地方就是：如果编译能通过，八成执行起来就没问题；如果执行起来有问题，那八成是你自己的代码逻辑有问题。[σ\`∀´) ﾟ∀ﾟ)σ](https://www.destroyallsoftware.com/talks/wat)
- Elm里各种变换、组合一等函数来产生新函数的现象肥肠普遍，甚至比操作数据来的普遍的多。组合、变换来产生完成特定功能的函数的同时还要满足类型签名的要求有点伤脑，就像把章鱼挤进一串硬币大小的洞里最后得到一只吃鱼的兔子一样……
    看一下这个延迟加载的例子：
    ```elm
    Process.sleep : Time -> Task x ()
    always : a -> b -> a
    identity : a -> a
    Task.succeed : a -> Task x a
    Task.andThen : (a -> Task x b) -> Task x a -> Task x b
    Task.perform : (a -> msg) -> Task Never a -> Cmd msg

    delay : Time -> msg -> Cmd msg
    delay time msg =
      Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
    ```
    --------------------------
    ```elm
    Process.sleep time = Task x ()
    (always <| Task.succeed msg) = b -> (Task x msg)
    Task.andThen (b -> (Task x msg)) (Task x ()) = Task x msg
    Task.perform identity (Task x msg) = Cmd msg
    ```
    用的时候像这样：
    ```elm
    -- 5s之后产生一个LoadCommentit消息
    delay ( Time.second*5) <| LoadCommentit
    ```
    真是……严丝合缝啊。( ﾟ∀。)

--------------------
#ﾟ ∀ﾟ)ノ#
