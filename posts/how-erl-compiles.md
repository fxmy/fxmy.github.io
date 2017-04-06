#erl的编译过程#
前天看了sfbay2017Richard Carlsson的[演讲](https://youtu.be/RMKSYWz_nPo)，于是在这里做下笔记。

--------------------
现阶段erl的编译过程大致有：
  1. Decode，负责把各类编码的文件（UTF-8、Latin-1等）解码成charactor序列。
  2. Tokenize，生成一系列的token。
  3. Preprocess，处理宏展开、条件编译等。
  4. Parse，将token序列处理成syntax tree。
  5. Parse-transform，用户有机会在编译时修改生成的syntax tree，[see also here](http://fxmy.herokuapp.com/zh/article/340/parse-tranformationa-c)。
  6. Desugar，将语言转换成更加简单，等价的结构，移除所有语法糖，只留语言原语（language primitive），生成Core syntax tree。
  7. Optimize
  8. Code generation，生成中间代码。
  9. Optimize，清理生成的中间代码。
  10. Target code generation。
  11. Assembly operation。
  12. Encode executable/machine code，生成obj/byte files。

下面是一些细节

--------------------
##运行erlang编译器##
  - 在shell中运行`c(ModuleOrFileName, [Opts])`
    - 其实调用的是`c:c(...)`
    - 成功则会编译并加载模块
  - `compile:file(FileName, [Opts])`
    - 成功时返回`{ok,Module}`，输出.beam文件
    - 并不自动加载模块
  - erlc -DDBUG -I ./include +debug_info + warn_unused_import foo.erl
    - erlc其实是是个调用了`erl -s erl_compile compile_cmdline`的C程序
      - 对于.erl文件会调用`compile:file`
      - 对于其他文件格式会调用相应的后端。（.yrl -> yecc, .mib -> snmp)
    - +...直接传给`compile:file`
    - -...则是简写的flags，会被展开成+...
  - `compile:file(FileName, [..., binary])` -> `{ok,Module, BeamBinary}`，可以配合`code:load_binary(Module,FilePath,BeamBinary)`来直接绕过硬盘更新代码

--------------------
##解码##
  - 将输入的字节流解码成character序列（code points）
  - erlang源文件默认为UTF-8
  - 在源码头部插入`%%-*-coding:latin-1-*-`来改变默认编码

--------------------
##Tokenization: erl_scan##
  - 手写的scanner，并未基于leex
  - 处理integer, float, atom, string, keyword, operator, separator
    转换为形如`{atom, 1, foo} {integer, 1, 42} {case, 1,} {end, 1} {'>', 1}`， 中间的数字代表行号
  - 特殊的Dot token： {dot, 1}
    - erlang中代码以“.空格”的形式分割为`forms`（来自prolog的老传统）
    - erlang shell也以此判断输入结束

--------------------
##Preprocessing: epp##
  - ‘C’风格、token层级的预处理，输入token，输出token
  - 处理头文件：`-include(...) -include_lib("appname/...")`
  - 宏展开：`-define(FOO(X), ...X...) ?FOO(42)`
  - 条件编译：`-ifdef(...) -else -endif`
  - 邻接字符串组合："a" "b" -> "ab"
预处理之后
  - 宏被展开，并没有include ifdef等
  - include的文件现在成了token流的一部分
  - 由于所有文件都成了一个token流，为了区分来自不同文件的内容，会插入位置声明： `-file(Name, Line)`
  - `compile:file(..., [..., 'P'])`生成预处理之后的.P文件

--------------------
##Parsing：erl_parse##
  - 由Yecc grammar `erl_parse.yrl`生成
  - 接受Token流输入
  - 一次处理整个`forms`
  - 输出`"abstract format" syntax tree`，文档[在此](http://erlang.org/doc/apps/erts/absform.html)
  - [syntax_tools app](http://erlang.org/doc/apps/syntax_tools/index.html)有许多处理syntax tree的实用函数

--------------------
##Parse_transform##
  - `-compile({Parse_transform, Module})`编译时会调用`Module:parse_transform(Forms, Opts)`
  - 可多次串行parse_transform

--------------------
##Check for errors: erl_lint##
  - 在syntax tree层面检查代码错误
  - 编译器大部分的警告与错误产生在这里
  - 用-Werror选项使erlc的警告变成错误

--------------------
##Pre-expansion##
  - record展开成tuple
  - 自动加入`module_info/1,2`
  - `-import`的函数展开为full qualified call

--------------------
###关于`debug_info`选项###
  - 在.beam文件中插入了`abstract_code`块
  - 内有整个module的abstract format syntax tree
    - 所以可以用它来编译成.beam
    - 也可以还原源码
  - `debug_info`可以加密来保护源码
    - 参见[compile:file/2](http://erlang.org/doc/man/compile.html#file-2)的`debug_info_key`选项
    - 以及[beam_lib](http://erlang.org/doc/man/beam_lib.html#debug_info)

--------------------
##生成Core erlang##
  - 启发自Standard ML(1983)
    - 包含语言的核心概念，在此之上的都被认作为语法糖
  - erlang层面的语法复杂，写起来爽，自动处理起来麻烦
    - 各种结构内出现的pattern matching/clause
      - function head/fun/case/if/receive/try都有些许差别
    - 看起来相同的表达式的行为有差异
      - `if`与`case`遇到无clause匹配时有会不同的exception
    - 变量作用域/绑定难以追踪/处理
  - 而core erlang层面则很纯粹
    - 结构简单
    - plain nested scopes -> like lambda calculus
    - only new varibales in patterns -> vars considered new unless you import it beforehand
    - 只有`case`和`receive`还有`clause`
    - 几乎没有语法糖，几乎只有一种表达方法
      - atom总是被'atom'
      - `[1,2,3|Rest]`总是`[1,[2,[3|Rest]]]`
      - 支持注释
      - ...(视频32:10起)
  - `erlc +to_core foo.erl`
  - `erlc +from_core <+clint> foo.core`

###Receive is a state machine###
core erlang中`receive`依旧有`clause`，因为`receive`本质上是个状态机，而不单是表达式，例如
```erlang
receive
  P1 when G1 -> B1;
..Pn when Gn -> Bn
after T -> A end
```
其实应该这么处理
```erlang
receive % 初始化timer，设定循环的loop header和信箱的msg pointer
  M when 'true' ->
    case M of
      P1 when G1 -> do primop SELECT() B1; % 从信箱中移除消息，打断timer
    ..Pn when Gn -> do primop SELECT() Bn
      Other when 'true' -> do primop NEXT() % pointer+1，返回loop header
  end
after T -> A end
```
在core erlang这层处理这类问题太复杂了，所以交给了后面的流水线来处理

--------------------
##Core optimization##
  - 常量传递/折叠：`X=17,Y=X+4,f(Y) -> f(21)`
  - 基础类型的类型追踪
  - +inline_list_funcs：把`lists:map(),fold()`等函数inline到module里

--------------------
##Kernel erlang##
从这里开始进入beam层面了
  - `erlc +to_kernel foo.erl`
  - 没有嵌套的表达式
  - only unique variables, variable usage information annotations
  - 尾调用标记有`enter`，其他的都是非尾调用
  - pattern matching编译成decision tree
  - ["lambda lifting"](https://en.wikipedia.org/wiki/Lambda_lifting): funs (and letrecs) converted to top level functions

###Destructive setelement###
在编程kernel erlang之前会有这么一个阶段，功能是提高更新一连串tuple时候的效率
  - sys_core_dsetel: adds destructive updates
  - 更新多个record字段时，会产生一系列的setelement
  - 在第一次setelement之后：
    - 后续setelement无需检查type与size
    - 可以用destructive操作来避免每次都要拷贝tuple
  - 前提要满足多次更新的是同一个tuple
  - 前提要满足多次更新期间不会有GC
    - 这意味着不允许有从old generation到newer generation的指针存在

--------------------
##The BEAM abstract machine##
  - 基于寄存器的VM（不同于基于栈的JAVA）
  - 有X/Y寄存器，对应于CPU上的寄存器（size of one word）/内存中的栈帧
  - 尾调用优化支持（call vs call_last操作）
    - last_call会销毁当前栈帧然后jump走
  - ERTS在加载beam code的时候会把它转换成特殊的内部操作（specialized internal operations），参见6K行的`beam_load.c`
  - 用`erts_debug:df(Module)`来生成`module.dis`来查看一个模块在load到BEAM里之后的样子：
    ```
    00007FD7D86A2BE0: i_func_info_IaaI 0 t microsecond_time 0 
    00007FD7D86A2C08: allocate_tt 0 0 
    00007FD7D86A2C18: call_bif_e erlang:system_time/0 
    00007FD7D86A2C28: i_int_div_jIssd j(0000000000000000) 1 x(0) 1000 x(0) 
    00007FD7D86A2C58: deallocate_return_Q 0 

    00007FD7D86A2C68: i_func_info_IaaI 0 t module_info 0 
    00007FD7D86A2C90: move_cr t r(0) 
    00007FD7D86A2CA0: allocate_tt 0 1 
    00007FD7D86A2CB0: call_bif_e erlang:get_module_info/1 
    00007FD7D86A2CC0: deallocate_return_Q 0 

    00007FD7D86A2CD0: i_func_info_IaaI 0 t module_info 1 
    00007FD7D86A2CF8: move_rx r(0) x(1) 
    00007FD7D86A2D08: move_cr t r(0) 
    00007FD7D86A2D18: allocate_tt 0 2 
    00007FD7D86A2D28: call_bif_e erlang:get_module_info/2 
    00007FD7D86A2D38: deallocate_return_Q 0
    ```

--------------------
##Code generation##
  - 分析变量生命周期
  - insert labels as targets for flow control instructions
  - 为变量分配X寄存器
  - 用X1，X2..来作函数调用传参
  - 在函数调用期间把X寄存器中的参数保存到栈帧（Y寄存器）中（压栈）
  - 插入在堆上申请空间的指令
    - 一个list cell需要2个word
    - 异常处理时需要的tags（try/catch）

--------------------
##Beam level optimizations##
  - Reordering
  - bit syntax optimizations
  - simple type based optimizations (mainly numerical)
  - dead/unreachable code elimination
  - [peephole optimization](https://en.wikipedia.org/wiki/Peephole_optimization)
  - "the ref trick" of receives
  - stack trimming
  - `erlc +to_asm foo.erl`

--------------------
##Beam file generation##
  - Validation (basic sanity checking, don't crash the emulator)
  - 把asm翻译成byte序列
    - 目前约有150个不同的opcode
  - 产出包含有不同chunk的binary encoding
    - bytecode, atom, constant literal, attribute
    - exported function table (entry points)
    - source line table (map bytecode to source line), compilation info, debug info

--------------------
#另参考#
1. [演讲的示例](https://github.com/richcarl/erlang-compiler-demo)
2. [A Peek Inside the Erlang Compiler](http://prog21.dadgum.com/127.html)
3. [Hack your own Erlang VM](http://studzien.github.io/hack-vm/part1.html)

--------------------
#ﾟ ∀ﾟ)ノ#
