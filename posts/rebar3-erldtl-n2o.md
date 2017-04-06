#Rebar3与Erldydtl与N2O#

最近也是尝试了下用rebar3来折腾N2O。结果发现也是够麻烦的，下面来数一数踩的坑。

--------------------
##总览##
首先是rebar3把各种配置都集中在了rebar.config里面。相比之前，rebar.config承载了更多的功能，内容相应的要复杂了许多。

相比以前的大部分是deps的rebar.config，rebar3额外可以设置plugins、provider_hooks、relx等的配置。而像erly_dtl_plugin这类的插件可以额外接受更多的配置（比如erlydtl_opts）。所有的这些全都堆在一个文件里，第一眼看过去给人的感觉就是——乱。_(:3JZ)_

--------------------
##与vim-erlang的冲突##
作为vim的忠实用户，写erlang自然少不了[`vim-erlang`](https://github.com/vim-erlang)的帮助。为了配合rebar3的目录结构`_build/...`来使用自动补全、自动查错等功能需要在rebar.config里配这两行：
```
{lib_dirs,["_build/default/lib"]}.
{deps_dir,"_build/default/lib"}.
```
然而尴尬的是`deps_dir`也会对rebar3有影响，最终的目录会变成`_build/default/lib/_build/default/lib`这样的双层结构，蛋痛。_(:3JZ)_

--------------------
##nitro与erlydtl的配置##
erlydtl提供了Django templates的功能。而负责server side rendering的便是nitro。目前nitro会把dtl生成的beam的扩展后缀设定成[`_view`](https://github.com/synrc/nitro/blob/master/src/elements/element_dtl.erl#L7)，所以要在rebar.config里这么配置：
```
{erlydtl_opts, [{source_ext, ".html"},
                {module_ext, "_view"},
                {auto_escape, false},
                {compiler_options, [report, return, debug_info, verbose]}
                ]
}.
```

--------------------
##诡异的erlydtl编译##
目前erlydtl在rebar3下面编译会时不时的蜜汁出错，具体情况见这个[issue](https://github.com/erlydtl/erlydtl/issues/251)。
真·面向运气编程。_(:3JZ)_

--------------------
##好用的rebar3 relup##
rebar3可以方便的生成relup。需要做的是写好自己的appup.src，然后启用[`appup`](https://www.rebar3.org/docs/using-available-plugins#appup)插件。但是记得在生成relup前要把相邻的两个版本的release准备好。_(:3JZ)_

--------------------
##N2O里的进程泄漏##
前一阵子在[这里](https://github.com/synrc/n2o/pull/271)修复了一个进程泄漏的问题，结果没想到[hex](https://hex.pm/)上最新的版本居然还是比这个早。
由于没有更新版本号可用所以appup并不能走通，这就很尴尬了。最后也是只好强行替换的.beam。_(:3JZ)_

--------------------
##sumo_db##
这次也是尝试了一下sumo_db，单说一下sumo_db的配置，很有意思。
sumo_db的配置是作为application env保存在sys.config里的。
```erlang
[
  {sumo_db, [
  {wpool_opts, [{overrun_warning, 500}]},
  {log_queries, true},
  {query_timeout, 30000},
  {storage_backends, [
    {sumo_blog_backend_mnesia, sumo_backend_mnesia, []}
  ]},
  {stores, [
    {sumo_test_mnesia, sumo_store_mnesia, [
      {workers, 10},
      {disc_copies, here},
      {majority, false}
    ]}
 ]},
 {docs, [
   {express_account, sumo_test_mnesia, #{module => express_deploy_db_account}}
 ]},
{events, [
 %% {post, blog_event_handler}
]}
]}
].
```
sumo_db启动时会根据sys.config里的设置来调用相应的callback module。
```erlang
sumo:create_schema(express_account).
```
相应的callback module：
```erlang
-module(express_deploy_db_account).
-behaviour(sumo_doc).
-spec sumo_schema() -> sumo:schema().
sumo_scheme() ->
  sumo:new_schema(express_account, [...]).
```
application env是个好东西。_(:3JZ)_

##好用的relx##
relx生成的release用起来肥肠方便。
```
_build/default/rel/ExpressDeploy   master  bin/ExpressDeploy
Usage: ExpressDeploy {start|start_boot <file>|foreground|stop|restart|reboot|pid|ping|console|console_clean|console_boot <file>|attach|remote_console|upgrade|downgrade|install|uninstall|versions|escript|rpc|rpcterms|eval}
```

在这里也是回顾一下release的启动流程：
```
start -> run_erl -daemon -> start_erl $ROOTDIR $RELDIR $START_ERL_DATA
```
```
Exec: _build/default/rel/ExpressDeploy/erts-8.1.1/bin/erlexec
-boot _build/default/rel/ExpressDeploy/releases/0.0.2/ExpressDeploy
-mode embedded
-boot_var ERTS_LIB_DIR _build/default/rel/ExpressDeploy/lib
-config _build/default/rel/ExpressDeploy/releases/0.0.2/sys.config
-args_file _build/default/rel/ExpressDeploy/releases/0.0.2/vm.args
-pa -- console
```

--------------------
#ﾟ ∀ﾟ)ノ#
