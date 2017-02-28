#Rebar3与Erldydtl与N2O#

最近也是尝试了下用rebar3来折腾N2O。结果发现也是够麻烦的，下面来数一数踩的坑。

--------------------
##总览##
首先是rebar3把各种配置都集中在了rebar.config里面。相比之前，rebar.config承载了更多的功能，内容相应的要复杂了许多。

相比以前的大部分是deps的rebar.config，rebar3额外可以设置plugins、provider_hooks、relx等的配置。而像erly_dtl_plugin这类的插件可以额外接受更多的配置（比如erlydtl_opts）。所有的这些全都堆在一个文件里，第一眼看过去给人的感觉就是——乱。_(:3JZ)_

--------------------
##与vim-erlang的冲突##
作为vim的忠实用户，写erlang自然少不了[vim-erlang](https://github.com/vim-erlang)的帮助。为了配合rebar3的目录结构`_build/...`来使用自动补全、自动查错等功能需要在rebar.config里配这两行：
```
{lib_dirs,["_build/default/lib"]}.
{deps_dir,"_build/default/lib"}.
```
然而尴尬的是`deps_dir`也会对rebar3有影响，最终的目录会变成`_build/default/lib/_build/default/lib`这样的双层结构，蛋痛。_(:3JZ)_

--------------------
##nitro与erlydtl的配置##
erlydtl提供了Django templates的功能。而负责server side rendering的便是nitro。目前nitro会把dtl生成的beam的扩展后缀设定成[_view](https://github.com/synrc/nitro/blob/master/src/elements/element_dtl.erl#L7)，所以要在rebar.config里这么配置：
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
