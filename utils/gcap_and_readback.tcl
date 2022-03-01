set GCAP 0000000400000004300000008001000C0000000466AA9955FFFFFFFF
set IR_CFG_IN   5
set IR_CFG_OUT  4

close_hw_target [current_hw_target]
open_hw_target -jtag_mode true

scan_ir_hw_jtag 6 -tdi $IR_CFG_IN 
scan_dr_hw_jtag 224 -tdi $GCAP;# Capture the state of all registers 

close_hw_target [current_hw_target]
open_hw_target -jtag_mode false

readback_hw_device [current_hw_device] -readback_file readback.rbd -force
