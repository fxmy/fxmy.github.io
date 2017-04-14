#调试崩溃的BEAM#
BEAM与C之间有许多交互方法，有些方法使用不当的话经常会搞垮VM。Richard Kallos在这里[总结](https://youtu.be/41hNS39Xi8s)了一些常见的BEAM与C的交互方法，以及出现问题时该如何调试。

---
首先，Erlang与C交互的方法主要有：
  - Ports
  - Port Drivers
  - NIFs
  - C Nodes

---
###Port
Ports在BEAM之外运行了一个独立的程序，通过stdin/stdout与BEAM进行通讯。例子：os:cmd/1
> +--------------------+
> |                    |
> |  BEAM +-------+    |
> |       |  Pid  |    |
> |       |       |    |
> |       +----^--+    |
> |         |  |       |
> |         |  |       |
> |      +--v--+-----+ |
> |      | Port      | |
> |      |           | |
> +------+---+---+---+-+
>            |   ^
>       stdout   | stdin
>            |   |
>       stdin|   | stdout
>            |   |
>        +---v---+---------+
>        | External Program|
>        +-----------------+
由于Ports与BEAM相互隔离，Ports崩溃了对BEAM没有影响。但是序列化输入输出有开销。

---
###Port Driver
Port Driver其实是隐藏在port之内的callback库，编译成.so并加载到BEAM中，BEAM会在适当的时候调用它。例子：inet/efile/zlib。
> +----------------------------------------+
> |                                        |
> | BEAM            +--------------------+ |
> |                 |                    | |
> | +-----+  +------+                    | |
> | | Pid +--> Port |  Linked-in Driver  | |
> | |     <--+      |                    | |
> | +-----+  +------+                    | |
> |                 |                    | |
> |                 +--------------------+ |
> +----------------------------------------+
  - 好处：API丰富
    - Timer functions
    - 异步操作
    - Monitoring processes
  - 坏处：难以调试，一但出错会搞垮整个VM
  - 最好用处：异步操作（I/O）

---
###NIF
NIF(native implemented function)也是被加载到VM里的.so，是取代了普通Erlang函数的native版。例子：crypto/jiffy/re。
> +---------------------------+
> | +------+   +------------+ |
> | | Pid  +---> NIF library| |
> | |      <---+            | |
> | +------+   +------------+ |
> |  BEAM                     |
> +---------------------------+
  - 开销最小
  - 难以调试，一但出错会搞垮整个VM
  - 适用于快速，同步的操作（小于1ms）

---
###NIF和Port Driver的使用建议
  - 测试NIF和Port Driver的运行时间
  - 把工作细分，及早yeild
  - 利用异步线程池与dirty nif/dirty scheduler

---
##当问题出现
作为一个成熟的生态环境，Erlang和C一样有许多工具可用：
- Erlang
  - dbg
  - crashdump_viewer
  - recon
  - redbug
  - ...
- C
  - dbg
  - valgrind
  - afl-fuzz
  - ...
然而许多调试C的工具直接拿来调试BEAM并不适用：
- beam.*有可能并不带调试符号
- 由于Erlang有自己的内存管理，valgrind有时会给出错误的诊断
- BIF和Port driver难以独立运行

---
好消息是我们可以编译出带有调试符号的BEAM，然后可以跑在各种调试工具里。
在编译完毕BEAM的基础上：
```bash
export ERL_TOP=`pwd`
cd $ERL_TOP/erts/emulator
make debug valgrind gcov gprof lcnt icount FLAVOR=smp
```
然后这样启动
```bash
$ERL_TOP/bin/cerl -rgdb # -gdb其实启动了emacs里的GDB GUI..
$ERL_TOP/bin/cerl -valgrind
```
> cerl有许多选项，参见cerl文件

---
###ETP(Emulator Toolbox for Pathologists)
ETP提供了许多可以在GDB内使用的实用命令
> $ERL_TOP/erts/etc/unix/etp_commands.in
可以在GDB内直接查询help
> $ERL_TOP/bin/cerl -rgdb
> [...]
> (gdb) help etp-help
> [...]
> (gdb) break nodes_1
> Breakpoint 1 at 0x52b6d0: file beam/dist.c, line 2965.
> (gdb)run
> Starting program: /home/fxmy/github/otp/bin/x86_64-unknown-linux-gnu/beam.smp -- -root /home/fxmy/github/otp -progname /home/fxmy/github/otp/bin/cerl -- -home /home/fxmy --
> [Thread debugging using libthread_db enabled]
> Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
> [New Thread 0x7fff8effd700 (LWP 11928)]
> [...]
> Erlang/OTP 19 [erts-8.3.1] [source] [64-bit] [smp:2:2] [async-threads:10] [hipe] [kernel-poll:false]
> 
> Eshell V8.3.1  (abort with ^G)
> 1> erlang:nodes({hahaha, badarg}).
> [Switching to Thread 0x7fff8f7fe700 (LWP 11927)]
> 
> Thread 15 "2_scheduler" hit Breakpoint 1, nodes_1 (A__p=0x7fffb6280400, BIF__ARGS=0x7fffb6744180) at beam/dist.c:2965
> 2965    {
> (gdb) etp *A__p
> <0.58.0>.
> (gdb) etp *BIF__ARGS
> {hahaha,badarg}.
> (gdb) etp-process-info A__p
>   Pid: <0.58.0>
>   State: on-heap-msgq | running | active | prq-prio-normal | usr-prio-normal | act-prio-normal
>   Current function: erlang:nodes/1
>   CP: #Cp<erl_eval:do_apply/6+0x1b8>
>   I: #Cp<0xb51cc538>
>   Heap size: 610
>   Old-heap size: 987
>   Mbuf size: 0
>   Msgq len: 0 (inner=0, outer=0)
>   Parent: <0.52.0>
>   Pointer: (Process *) 0x7fffb6280400
> (gdb) c
> Continuing.
> ** exception error: bad argument
>      in function  nodes/1
>              called as nodes({hahaha,badarg})
> 2>
炫酷，这在遇到NIF/Port driver搞崩VM，不一定保证能产生erl_crash.dump的时候尤其有用。

---
###一些示例
- [segfault](https://github.com/studzien/segfault)
    > $ERL_TOP/bin/cerl -rgdb -pa $(rebar3 path)
    > (gdb) r
    > Eshell V8.3.1  (abort with ^G)
    > 1> segfault:generate().

    > Thread 15 "2_scheduler" received signal SIGSEGV, Segmentation fault.
    > [Switching to Thread 0x7fff8f7fe700 (LWP 14297)]
    > 0x00007fff8dcbe79f in generate (env=0x7fff8f7fdde0, argc=0, argv=0x7fffb6744180) at c_src/segfault.c:6
    > 6           *an_integer = 100;
    > 
    > (gdb) etp *argv
    > segfault.
    > (gdb) list
    > 1       #include <erl_nif.h>
    > 2
    > 3       static ERL_NIF_TERM generate(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
    > 4       {
    > 5           int *an_integer = NULL;
    > 6           *an_integer = 100;
    > 7           return enif_make_atom(env, "ok");
    > 8       };
    > 9
    > 10      static int load(ErlNifEnv* env, void **priv, ERL_NIF_TERM info)
    > (gdb)
- [MemLeak](https://youtu.be/41hNS39Xi8s?t=23m42s)
    > VALGRIND_MISC_FLAGS="--leak-check=full" $ERL_TOP/bin/cerl -valgrind -pa $(rebar3 path)

---
另见
  - [niffy](https://github.com/tokenrove/niffy)，一层C wapper来直接运行NIF
  - [bitwise](https://github.com/vinoski/bitwise)，一些搞乱scheduler的NIF示例
  - [如何分析BEAM的core dump](https://www.erlang-solutions.com/blog/how-to-analyse-a-beam-core-dump.html)

---
#ﾟ ∀ﾟ)ノ
