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
Port Driver其实是隐藏在port之内的callback库，编译成.so并加载到BEAM中，BEAM会在适当的时候调用它。例子：inet/efile/zlib
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
$ERL_TOP/bin/cerl -rgdb # -gdb其实启动emacs里的GDB GUI..
$ERL_TOP/bin/cerl -valgrind
```
> cerl有许多选项，参见cerl文件
15:52
