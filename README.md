Thinpad 模板工程
---------------

工程包含示例代码和所有引脚约束，可以直接编译。

代码中包含中文注释，编码为utf-8，在Windows版Vivado下可能出现乱码问题。  
请用别的代码编辑器打开文件，并将编码改为GBK。

### Readback Capture 演示

修改编译选项，确保生成bitstream的同时生成logic location文件：

`Project Settings` -> `Bitsream` -> `-logic_location_file` 勾选。


Vivado打开Hardware Manager，连接JTAG。需要抓取寄存器状态时，在Tcl Console中：

`source utils/gcap_and_readback.tcl`

所有寄存器状态将会保存到`readback.rbd`文件中。使用工具读取其中的寄存器值：

`utils/rbd-insight.py readback.rbd thinpad_top.runs/impl_1/thinpad_top.ll`
