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
> |       +--^----+    |
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
