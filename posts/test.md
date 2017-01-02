#Test Lab

测试

`发发饭`

```erlang
#!/usr/bin/env escript
%% -*- erlang -*-
%% %%! -smp enable +pc unicode

-include_lib("kernel/include/file.hrl").
main([FileName]) ->
  case file:open(FileName, [read]) of
    {ok, IoDevice} ->
  process_lines(IoDevice, []);
    {error, Why} ->
      io:format("!!!OPEN: ~p~n", [Why]),
        usage()
  end;
main(_) ->
  usage().

process_lines(IoDevice, Acc) ->
  case io:get_line(IoDevice, "") of
    eof ->
      Items = rss_items(Acc),
      RSS = rss(rss_channel(Items)),
      case file:open("rss.xml", write) of
        {ok, RSSDevice} ->
          io:format(RSSDevice, "~s", [RSS]),
          file:close(RSSDevice);
        {error, Why} ->
          io:format("!!WRITE: ~p~n", [Why])
      end,
      file:close(IoDevice);
        {error, ErrorDes} ->
          io:format("!!ERROR: ~tp~n", [ErrorDes]);
        Data ->
          {Desc, Link} = split_parentheses(Data),
          io:format("!!DES: ~s~n!!LINK: ~s~n~n", [Desc, Link]),
          process_lines(IoDevice, [{Desc, Link}| Acc])
  end.

split_parentheses(Line) when is_list(Line) ->
  split_parentheses(unicode:characters_to_binary(Line));
split_parentheses(Bin) when is_binary(Bin) ->
  [<<>>,Desc,<<>>,Link,_] = re:split(Bin, "(\\[.+\\]|\\(.+\\))"),
  {strip_parentheses(unicode:characters_to_list(Desc)),
   strip_parentheses(unicode:characters_to_list(Link))}.

strip_parentheses([$[|Desc]) when is_list(Desc) ->
  strip_parentheses(Desc,[],desc);
strip_parentheses([$(|Link]) when is_list(Link) ->
  strip_parentheses(Link,[],link).

strip_parentheses([], Acc, _Type) when is_list(Acc) ->
  lists:reverse(Acc);
strip_parentheses([$]|Rest], Acc, desc) when is_list(Rest) ->
  lists:reverse(Acc);
strip_parentheses([$)|Rest], Acc, link) when is_list(Rest) ->
  lists:reverse(Acc);
strip_parentheses(List,Acc, Type) when is_list(List), is_list(Acc) ->
  [H|T] = List,
  strip_parentheses(T,[H|Acc], Type).

rss_items(List) ->
  rss_items(List, []).

rss_items([], Acc) ->
  Acc;
rss_items([{Desc, Link}| Rest], Acc) ->
  Item = "<item><title>"++Desc++"</title><description>"++Desc++"</description><link>https://fxmy.github.io/"++Link++"</link><author>fxmy</author></item>" ++ Acc,
  rss_items(Rest, Item).

rss_channel(Items) ->
  "<channel>"++Items++"</channel>".

rss(Channel) ->
  "<rss version=\"2.0\">"++Channel++"</rss>".

usage() ->
  ScriptName = escript:script_name(),
  io:format("Usage-> "++ScriptName++" filename~n"),
  halt(1).

```

<div id="disqus_thread"></div>
<script>

/**
*  RECOMMENDED CONFIGURATION VARIABLES: EDIT AND UNCOMMENT THE SECTION BELOW TO INSERT DYNAMIC VALUES FROM YOUR PLATFORM OR CMS.
*  *  LEARN WHY DEFINING THESE VARIABLES IS IMPORTANT: https://disqus.com/admin/universalcode/#configuration-variables*/
/*
var disqus_config = function () {
this.page.url = PAGE_URL;  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = PAGE_IDENTIFIER; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};
*/
(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = '//fxmy.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
