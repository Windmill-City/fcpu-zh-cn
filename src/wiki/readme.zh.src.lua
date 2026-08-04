return [==[

# 特性

* 支持蓝图
* 游戏内编辑器(支持复制和粘贴)
* 支持多人游戏
* 支持品质系统
* 支持 [Informatron](https://mods.factorio.com/mod/informatron) 和 [Booktorio](https://mods.factorio.com/mod/Booktorio) 游戏内维基
* 游戏内调试器(支持断点)
* 单程序支持最多 256 条指令
* 64 个通用寄存器
* 最大深度 4096 的栈(用于函数调用和局部变量存储)
* 4 个用于向量处理的内存单元
* 支持访问物流网络
* 50+ 指令
* 丰富的数学指令: 三角函数、取整
* SIMD 指令(`min`、`max`、过滤、比较等)
* 两个输入端口(红、绿)
* 两个输出端口(红、绿)输出相同的信号和数值
* 并行输出, 可同时输出多个信号
* 可通过特殊输入信号(中断)控制
* 1 个 tick 执行 1 条指令(SIMD 指令除外)
* 为极客而生



# 简介
程控运算器 由以下部分组成:

- 程序代码
- 8 个寄存器(用于存储信号/数值)
- 4 个内存单元(用于存储非零信号/数值)
- 指令处理器
- 向量协处理器


## 程序
程序使用简化版汇编语言编写, 由多行组成

一行一条指令
一条指令由`助记符`和`操作数`组成

例如: 
`mov out1 123[item=copper-ore]`
- `mov` - 指令
- `out1`- 操作数 1
- `123[item=copper-ore]` - 操作数 2

这条指令把信号 `123[item=copper-ore]` 发送到输出

以下内容可以用作操作数:

- **信号**: `123[item=copper-ore]`
- **寄存器**: `reg1`, `r2`, ...
- **局部变量**: `var1`, `v2`, ...
- **内存单元**: `mem1`, `m2`, ...
- **物流网络**: `lgn[1]`, `lgn@2`, `logi[34]`, ...
- **输入端口**: `red`, `green`, `red1`, `green@3`, ...
- **输出端口**: `out1`, `out2`, ..., `out256`
- **地址**: 行号 `34`
- **跳转标签**: `:label`, `:anyname`, ...

运算器会按顺序逐行执行程序中的指令


## 寄存器

共有 8 个通用寄存器: **reg1**、...、**reg8**(简写 **r1**、...、**r8**)

每个寄存器存储信号类型和数值(支持浮点数)

例如:
`mov reg2 10[item=iron-plate]`
该指令将 **reg2** 的值设为 *10*, 类型设为 *[item=iron-plate]*

除通用寄存器外, 还有一些只读寄存器:

- **ipt**: 程序计数器(Program Counter - PC指针)
- **clk**: 运行 tick 数, 每过一个 tick 加 1
- **cnr**: 输入端口(红)上的信号种数
- **cng**: 输入端口(绿)上的信号种数
- **cnl**: 物流网络(`lognet`)中的物品种数
- **cnm1**: 内存单元 1 中的信号种数
- **cnm2**: 内存单元 2 中的信号种数
- **cnm3**: 内存单元 3 中的信号种数
- **cnm4**: 内存单元 4 中的信号种数
- **sp**: 栈指针
- **bp**: 基址指针

输出寄存器(只写):

- **out1**、...、**out256**: 输出寄存器(只接受带信号 ID 的整数值, 无类型或数值为零的信号都会被丢弃)


## 栈

栈在内存中**向下增长**(从高地址到低地址)
想知道还剩多少空间? 读取 `sp` 寄存器即可(`mov r1 sp`)
- 类型: LIFO(后进先出)
- 大小: 4096

使用 `push` 和 `pop` 指令压栈和弹栈:
`push r1 r2 r3`
等价于:
```
push r1
push r2
push r3
```


## 函数

通过 `call`、`ret`、`enter`、`leave` 指令支持函数, 语义类似 x86 汇编

`bp`: 存储当前函数栈帧起始处的地址, 从而可以访问局部变量

`call <label/addr>`: 先把返回地址压栈保存, 再跳转到指定标签或地址, 支持嵌套和递归
等价于:
```
  push ipt
  jmp addr offset
```

`ret`: 从栈中弹出返回地址, 并在此处恢复执行, 从而结束当前函数
等价于:
```
  pop <temp>
  jmp <temp>
```

`enter <size>` 为函数建立新的栈帧: 先把当前基址指针压入栈, 再设置新的基址指针, 并可按需为局部变量预留空间
等价于:
```
  push bp        ; 保存上一个基址指针 `bp`
  mov  bp, sp    ; 设置新栈帧的基址 `sp`
  sub  sp, size  ; 为局部变量分配空间
```

`leave` 撤销 `enter` 的操作: 恢复上一个基址指针并调整栈指针, 在返回前清除当前栈帧
等价于:
```
  mov  sp, bp    ; 丢弃局部变量
  pop  bp        ; 恢复上一个基址指针 `bp`
```

多次函数调用之后的栈示意图:
```
4096
| ...         |
| older  ipt  | `call :fn1`
|             | `enter 3`
| old    bp   |
|        var1 | <-- old bp - 1
| ...         |
|        var3 | <-- old bp - 3
| ...         |
| old    ipt  | `call :fnN`
|             | `enter 1`
| actual bp   | <-- `bp`
|        var1 | <-- bp - 1
|             | <-- `sp`
| ...         |
1
```



## 局部变量

局部变量存放在栈顶, 执行 `leave` 之后便无法访问
想为变量建立函数栈帧? 使用 `enter <size>` 即可

例如:
```
enter 3
  mov var1 1
  mov var2 2
  mov var3 3
  mov r4 v1
  mov r5 v2
  mov r6 v3
leave
```


## 内存单元

为了能同时处理多个信号, 程控运算器 配有专门执行 SIMD 指令的向量协处理器

标量操作一次只能处理一个信号, 而向量操作能在同样的时间内处理数百个信号

程控运算器中内存单元的作用与寄存器类似, 但服务于向量指令

有 4 个内存单元可供使用:
`mem1`、`mem2`、`mem3`、`mem4`
访问单个元素: `mem2[44]` 或 `mem1@3`


## 物流网络

它相当于一个额外的内存单元, 区别在于它是只读的
`lgn` 通道可以通过 `xmov` 移入内存单元进行操作


# 数组\间接寻址

每个寄存器、内存单元或物流网络都可以通过直接名称寻址:

* 寄存器: **reg1**、**r2**
* 内存单元: **mem1[32]**、**m4[97]**
* 物流网络: **lgn[43]**、**logi[12]**

也可以使用间接指针:

* 寄存器: **reg@3**、**r@7**
* 内存单元: **mem1@3**、**mem4@8**
* 物流网络: **lgn@2**、**logi@8**

这样, 你就能把寄存器中的值当作**数组**索引来用

例如:
```
mov r1 10[item=iron-plate]
mov r2 20[item=copper-plate]
mov r3 300[item=steel-plate]

mov r5 2
mov r6 r@5 # r6 将等于 r2, 即 20[item=copper-plate]
mov r4 m1@5 # r4 将等于 mem1[2]

mov r5 3
mov r7 r@5 # r7 将等于 r3, 即 300[item=steel-plate]
mov r4 m2@5 # r4 将等于 mem2[3]

mov r5 5
mov r8 r@5 # r8 将等于 r5, 即 5
mov r4 m3@5 # r4 将等于 mem3[5]
```

同样的方法也适用于 `red`、`green` 输入端口和内存单元

例如: `red@1`、`green@8`、`mem1@3`


# 控制信号、中断
除了用 GUI 手动控制程控运算器, 你还可以通过信号来控制它
以下是一些控制信号:
* `[virtual-signal=signal-fcpu-halt]`: 暂停
* `[virtual-signal=signal-fcpu-run]`: 继续
* `[virtual-signal=signal-fcpu-step]`: 单步
* `[virtual-signal=signal-fcpu-sleep]`: 休眠 (在休眠模式下 程控运算器 不处理中断)
* `[virtual-signal=signal-fcpu-jump]`: 跳转

如果程序运行出错, 程控运算器 会输出 `[virtual-signal=signal-fcpu-error]` 信号, 其值即为出错行号


# 指令

这些指令按 tick 逐条执行。每条指令接受一个或多个操作数, 并修改这些操作数或 程控运算器 的状态。  

**图例**

* **V**, 值: 范围在 [-2^31..2^31) 内的整数常量(`-3500`)
* **T**, 类型: 信号类型, 支持指定品质(`[item=iron-ore]`、`[item=copper-plate,quality=rare]`)
* **Q**, 品质: 只表示信号品质(`'epic'`、`[quality=legendary]`) _WIP_
* **VT**, 信号: 由**值**和**类型**组成(`123[item=copper-ore]`、`456[item=iron-plate,quality=uncommon]`)
* **R**, 引用: 寄存器、内存单元、局部变量(`reg1`、`r3`、...、`reg8`;`r@4` 间接记法;单个内存单元 `m1[23]`;单个输入信号 `red34`、`green@3`;局部变量 `var1`、`v2` 等)
* **M**, 内存: 通道(`mem1`、`m2`、...、`mem4`)
* **N**, 物流网络: 通道(`lgn`、`logi`、`lnc`)
* **I**, 端口: 输入端口(`red`、`green`)
* **O**, 端口: 输出缓冲(`out1`、`out2`、...、`out256`、`out`)

- **A**, 地址: 指令地址(`5`)
- **L**, 标签: 指令标签(`:labelname`)
- **S**, 字符串: 用于工具类助记符(`'rotation_speed'`)

`...` - 一个或多个, 可重复指定, 以空格分隔
`?` - 可选参数, 可以省略。  

## 常用

* `nop`
  空操作

* `clr`
  清除所有寄存器、内存单元和输出

* `clr` reg
  清除所有寄存器

* `clr` out
  清除所有输出值

* `clr` mem
  清除所有内存单元

* `clr` dst...[**R**/**M**/**O**]
  清除指定的寄存器、内存单元或输出端口(`mem3`、`r2`、`out4`)

* `mov` dst...[**R**/**O**] src[**V**/**T**/**VT**/**R**]
  将信号从源复制到目标
  *dst... = src*

* `ssv` dst...[**R**/**O**] val[**V**/**R**]
  设置信号值
  *dst... = val*

* `sst` dst...[**R**/**O**] type[**T**/**R**]
  设置信号类型
  *dst... = type*

* `ssq` dst...[**R**/**O**] quality[**T**/**Q**/**R**]
  设置信号品质
  *dst... = quality*

* `fid` dst[**R**/**O**] src[**I**/**M**] type[**T**/**R**]
  在 *src*(内存或红/绿输入端口)中查找 *type* 对应的信号, 并将其类型和数值赋给 *dst*

* `idx` dst[**R**] src[**I**/**M**] type[**T**/**R**]
  在 *src*(内存或红/绿输入端口)中查找 *type* 对应的信号, 并将其在内存或输入端口中的位置索引赋给 *dst*

* `fir` dst[**R**/**O**] type[**T**/**R**]
  `fig` dst[**R**/**O**] type[**T**/**R**]
  `fid ... red ...` 与 `fid ... green ...` 的简写

## 品质

参见 https://lua-api.factorio.com/latest/prototypes/QualityPrototype.html#level

* `qn` dst[**R**/**O**] type[**T**/**R**/**I**]
  品质等级对应的数字(普通=0、罕见=1、稀有=2、史诗=3、传奇=5)
  *dst = type 的品质*


## 交换

* `swp` reg1[**R**] reg2[**R**]
  交换寄存器或内存单元中的信号
* `swpt` reg1[**R**] reg2[**R**]
  交换寄存器或内存单元中的信号类型
* `swpv` reg1[**R**] reg2[**R**]
  交换寄存器或内存单元中的信号值
* `swpq` reg1[**R**] reg2[**R**]
  交换寄存器或内存单元中的信号品质


## 算术

* `add` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src + val*(如果指定了 src)
  *dst = dst + val*
* `sub` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src - val*(如果指定了 src)
  *dst = dst - val*
* `mul` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src \* val*(如果指定了 src)
  *dst = dst \* val*
* `div` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src / val*(如果指定了 src)
  *dst = dst / val*
* `mod` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src % val*(如果指定了 src)
  *dst = dst % val*
* `pow` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  *dst = src ^ val*(如果指定了 src)
  *dst = dst ^ val*  

* `inc` dst[**R**]
  *dst = dst + 1*
* `dec` dst[**R**]
  *dst = dst - 1*

* `subi` dst[**R**] val[**V**/**R**]
  *dst = val - dst*
* `divi` dst[**R**] val[**V**/**R**]
  *dst = val / dst*
* `modi` dst[**R**] val[**V**/**R**]
  *dst = val % dst*
* `powi` dst[**R**] val[**V**/**R**]
  *dst = val ^ dst*

* `rnd` dst[**R**] min[**V**/**R**] max[**V**/**R**]
  在 [*min*, *max*] 范围内(含端点)生成一个伪随机值并赋给 *dst*。  

* `fract` reg[**R**]
  取寄存器中实数的小数部分
* `floor` reg[**R**]
  取不超过寄存器中实数的最大整数
* `round` reg[**R**]
  取最接近寄存器中实数的整数
* `ceil` reg[**R**]
  取不小于寄存器中实数的最小整数。  

* `dig` dst[**R**] num[**V**/**R**]
  取出 *dst* 中第 *num* 位数字并写回 *dst*
  *dst = dst / 10^num % 10*
* `dis` dst[**R**] num[**V**/**R**] val[**V**/**R**]
  将 *dst* 中第 *num* 位的数字设为 *val*
  *dst = dst + (val % 10 - dst / 10^num % 10) * 10^num*


## 栈操作

* `push` src...[**V**/**T**/**VT**/**R**]
* `pop` dst...[**R**/**O**]


## 三角函数

* `cos` dst[**R**] src[**V**/**R**]
  *dst = cos(src)*
* `sin` dst[**R**] src[**V**/**R**]
  *dst = sin(src)*
* `tan` dst[**R**] src[**V**/**R**]
  *dst = tan(src)*
* `atan2` dst[**R**] y[**V**/**R**] x[**V**/**R**]
  *dst = atan2(y, x)*
* `sqrt` dst[**R**] src[**V**/**R**]
  *dst = sqrt(src)*
* `exp` dst[**R**] src[**V**/**R**]
  *dst = exp(src)*
* `ln` dst[**R**] src[**V**/**R**]
  *dst = ln(src)*


## 位运算

* `band` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  与(AND)
  *dst = src & val*(如果指定了 src)
  *dst = dst & val*

* `bor` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  或(OR)
  *dst = src | val*(如果指定了 src)
  *dst = dst | val*

* `bxor` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  异或(XOR)
  *dst = src ^ val*(如果指定了 src)
  *dst = dst ^ val*

* `bnot` dst[**R**] src?[**R**]
  非(NOT)
  *dst = ~src*(如果指定了 src)
  *dst = ~dst*

* `bsl` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  左移
  *dst = src << val*(如果指定了 src)
  *dst = dst << val*

* `bsr` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  右移
  *dst = src >> val*(如果指定了 src)
  *dst = dst >> val*

* `brl` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  循环左移
  *dst = src rot<< val*(如果指定了 src)
  *dst = dst rot<< val*

* `brr` dst[**R**] src?[**V**/**R**] val[**V**/**R**]
  循环右移
  *dst = src rot>> val*(如果指定了 src)
  *dst = dst rot>> val*


# 流程控制

* `lea` dst[**R**/**O**] addr[**L**]
  将标签 *addr* 加载到 *dst*

* `jmp` addr[**V**/**A**/**L**/**R**]
  跳转到地址或标签

* `jmp` addr[**V**/**A**/**L**/**R**] offset[**V**/**R**]
  跳转到地址 + 偏移量或标签 + 偏移量
  例如: `jmp ipt -2`, 跳转到当前指令(`ipt`)前两行

* `hlt`
  *暂停*程序执行, 直到玩家或任意输入端口的 *Run* 信号将其恢复

* `slp` cnt[**V**/**R**]
  休眠指定的 tick 数
  休眠期间 程控运算器 不处理中断

* `call` addr[**V**/**A**/**L**/**R**] offset[**V**/**R**]
  将当前指令指针压入栈, 并跳转到地址 + 偏移量或标签 + 偏移量

* `ret`
  从栈中弹出地址并跳转到该地址

* `enter` count[**V**]
  在栈上为局部变量预留空间

* `leave`
  丢弃栈上的局部变量

## 阻塞执行

条件满足后, 紧随其后的下一条指令会在同一 tick 内立即执行
因此, 它们可以用于把触发继续执行的输入信号原样复制到输出
例如:
```
mov r1 0[virtual-signal=signal-green]
btrc r1
xmov m1 red
```

* `bkr` cnt[**V**/**R**]
  `bkg` cnt[**V**/**R**]
  `bkl` cnt[**V**/**R**]
  阻塞, 直到红/绿端口或物流网络上至少有 *cnt* 个信号

* `btr` type[**T**/**R**]
  `btg` type[**T**/**R**]
  `bti` type[**T**/**R**]
  `btl` type[**T**/**R**]
  阻塞, 直到红、绿、双输入端口或物流网络上出现该信号类型

* `btrc` reg[**R**]
  `btgc` reg[**R**]
  `btic` reg[**R**]
  `btlc` reg[**R**]
  当引用*寄存器*与红、绿、双输入端口或物流网络上的类型-值相同时保持阻塞
  一旦红/绿/输入端口或物流网络的值发生变化, 就把新值赋给*寄存器*并继续执行


## 比较数值

如果比较成功, 则执行下一条指令
你可以添加 `jmp :label` 来实现分支。例如:
```
clr
:counter
inc r1
tlt r1 10
jmp :counter
; r1 现在等于 10
```

* `teq` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  相等
  *a == b*

* `tne` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  不相等
  *a != b*

* `tgt` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  大于
  *a > b*

* `tlt` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  小于
  *a < b*

* `tge` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  大于或等于
  *a >= b*

* `tle` a[**V**/**S**/**R**] b[**V**/**S**/**R**]
  小于或等于
  *a <= b*


## 比较类型

* `tas` a[**T**/**R**] b[**T**/**R**]
  类型相同。  

* `tad` a[**T**/**R**] b[**T**/**R**]
  类型不同。  


## 分支

分支相当于: 先进行比较, 若成功则立即跳转
与比较指令一一对应, 只是把 `t` 换成 `b`, 并额外用一个操作数作为跳转地址

```
clr
:counter
inc r1
blt r1 10 :counter
; r1 现在等于 10
```

* `beq` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  相等
  如果 *a == b* 则 `jmp addr offset`

* `bne` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  不相等
  如果 *a != b* 则 `jmp addr offset`

* `bgt` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  大于
  如果 *a > b* 则 `jmp addr offset`

* `blt` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  小于
  如果 *a < b* 则 `jmp addr offset`

* `bge` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  大于或等于
  如果 *a >= b* 则 `jmp addr offset`

* `ble` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  小于或等于
  如果 *a <= b* 则 `jmp addr offset`

* `bas` a[**T**/**R**] b[**T**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  类型相同时分支。  

* `bad` a[**T**/**R**] b[**T**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]
  类型不同时分支。  


# 其他指令

* `ugpf` dst[**R**] name[**T**/**R**] field[**S**]
  *获取 Prototype 字段*
  按名称 *name* 查找 Prototype, 并把字段 *field* 的值赋给 *dst*(仅支持数字字段)
  该指令依次在以下 Prototype 中检查字段:
    1. https://lua-api.factorio.com/latest/LuaItemPrototype.html
    2. https://lua-api.factorio.com/latest/LuaEntityPrototype.html
  例如:
  - `ugpf r1 [item=inserter] 'inserter_stack_size_bonus'`
  - `ugpf r2 [item=copper-ore] 'stack_size'`(这与 `uiss r1 [item=copper-ore]` 相同)
  - `ugpf r3 [item=buffer-chest] 'get_inventory_size(defines.inventory.item_main)'`

  你还可以用点号 `.` 访问这些 Prototype 内部的字段
  要检查物品是否为科技包, 请使用此示例:
  - `ugpf r1 [item=automation-science-pack] 'subgroup.name'`
    `beq r1 'science-pack' :yeah_science_btch`


# SIMD 指令

到目前为止, 每个游戏 tick 只能执行一条指令, 且每条指令只能处理少量信号
但这远不是极限。程控运算器 支持*单指令多数据*(SIMD)命令, 让单条指令(也就是单个游戏 tick)完成更多计算
与标量指令每次只处理一个信号不同, SIMD 指令会一次并行处理多个信号。  

使用 SIMD 指令时, 应考虑以下特性:
- SIMD 指令不额外占用处理时间, 对 UPS 友好
- 部分向量指令需要多个 tick 才能执行完毕(`xmov mem1 red` 需要 3 个 tick 才能把 `red` 端口的数据载入 `mem1` 通道)
- 必须等向量指令执行完毕后, 才能从受影响的内存中读取有效数据

**图例**
- `dst()`、`src()`: 无序内存(集合)
- `dst[]`、`src[]`: 有序内存(数组)*尚未实现*


## 常用指令

* `xmov` dst[**M**/**O**] src[**I**/**M**/**N**]
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each])*

* `emit` dst[**M**] val...[**V**/**T**/**VT**/**R**]
  把*值*追加到 *dst* 内存中(在 v0.5.0 之前为随机顺序)

* `xuni` dst[**M**/**O**] a[**I**/**M**/**N**] b[**I**/**M**/**N**]
  将两个内存单元合并为一个
  *dst([virtual-signal=signal-each]) = a([virtual-signal=signal-each]) + b([virtual-signal=signal-each])*

* `xflt` dst[**M**/**O**] src?[**I**/**M**/**N**] mask[**I**/**M**/**N**]
  把 *src* 中与 *mask* 白名单匹配的信号全部复制到 *dst*
  *内部设计由 [Halke1986](https://www.reddit.com/user/Halke1986/) 提供*

* `xadd` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst + val*
  *dst([virtual-signal=signal-each]) = src + val*(如果指定了 src)

* `xsub` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst - val*
  *dst([virtual-signal=signal-each]) = src - val*(如果指定了 src)

* `xmul` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst \* val*
  *dst([virtual-signal=signal-each]) = src \* val*(如果指定了 src)

* `xdiv` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst / val*
  *dst([virtual-signal=signal-each]) = src / val*(如果指定了 src)

* `xmod` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst % val*
  *dst([virtual-signal=signal-each]) = src % val*(如果指定了 src)

* `xpow` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**/**I**/**M**]
  *dst([virtual-signal=signal-each]) = dst ^ val*
  *dst([virtual-signal=signal-each]) = src ^ val*(如果指定了 src)


## 比较

将内存中每个信号的值与指定操作数比较, 满足条件的信号才会写入目标
在双操作数版本中, *src* 与 *dst* 相同。  

* `xceq` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  相等
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) == val*

* `xcne` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  不相等
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) != val*

* `xcgt` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  大于
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) > val*

* `xclt` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  小于
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) < val*

* `xcge` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  大于或等于
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) >= val*

* `xcle` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  小于或等于
  *dst([virtual-signal=signal-each]) = src([virtual-signal=signal-each]), 如果 src([virtual-signal=signal-each]) <= val*


## 位运算

* `xand` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  与(AND)
  *dst([virtual-signal=signal-each]) = dst & val* 
  *dst([virtual-signal=signal-each]) = src & val*(如果指定了 src)

* `xor`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  或(OR)
  *dst([virtual-signal=signal-each]) = dst | val* 
  *dst([virtual-signal=signal-each]) = src | val*(如果指定了 src)

* `xxor` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  异或(XOR)
  *dst([virtual-signal=signal-each]) = dst ^ val* 
  *dst([virtual-signal=signal-each]) = src ^ val*(如果指定了 src)

* `xsl`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  左移
  *dst([virtual-signal=signal-each]) = dst << val* 
  *dst([virtual-signal=signal-each]) = src << val*(如果指定了 src)

* `xsr`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  右移
  *dst([virtual-signal=signal-each]) = dst >> val* 
  *dst([virtual-signal=signal-each]) = src >> val*(如果指定了 src)


## 统计

* `xmin` dst[**R**/**O**] src[**I**/**M**/**N**]
  在 `src` 中找出最小信号并复制到 `dst`
* `xmax` dst[**R**/**O**] src[**I**/**M**/**N**]
  在 `src` 中找出最大信号并复制到 `dst`
* `xavg` dst[**R**/**O**] src[**I**/**M**/**N**]
  计算 `src` 中信号的平均值并赋给 `dst`

* `xmini` dst[**R**/**O**] src[**I**/**M**/**N**]
  在 `src` 中找出最小信号, 并将其索引赋给 `dst`
* `xmaxi` dst[**R**/**O**] src[**I**/**M**/**N**]
  在 `src` 中找出最大信号, 并将其索引赋给 `dst`


# 内存

下面解释这个模组是如何与内存配合工作的, 以及为什么要这样设计

每条 Factorio 线缆都能同时承载大量信号(数百个)。这些信号本身没有顺序, 索引实际上是随机的。为了让显示更美观, GUI 面板会按降序对信号排序(电线杆和信息提示中都是如此)

为了高效处理大量信号, 原版运算器在游戏内部是用 C++ 优化的。如果你想在 LUA 模组中处理同等数量的信号, 会带来明显的额外开销和性能损失, 这对任何 Factorio 模组都适用

为解决这个问题, 程控运算器 采用了一个巧妙的做法: 它把程序中的 SIMD 助记符(`x*`)部分编译成由原版运算器组成的隐形电路, 并逐行协调执行。这部分被称为协处理器, 性能比用 LUA 做类似计算更好

寄存器以普通变量的形式实现, 索引始终保留; 而 SIMD 指令使用的内存则是通过原版运算器实现的, 两者有所不同

以下是最重要的部分:
要修改内存, 必须为同一信号类型先减去旧值, 再加上新值
和任何其他原版运算器操作一样, 这会打乱信号的索引


# 用户界面

## 快捷键

* **F5** = 运行
* **Shift** + **F5** = 停止
* **Ctrl** + **Shift** + **F5** = 复位
* **F6** = 暂停
* **F7**、**F11** = 单步进入
* **F8**、**F10** = 单步跳过
