read_verilog -sv src/top.sv \
                 src/part_01.sv \
                 src/part_02.sv \
                 src/solution2char.sv \
                 src/lib/uart/uart_rx.sv \
                 src/lib/uart/uart_tx.sv \
                 src/lib/mem/mem_arty_full.sv \
                 src/lib/bin2bcd/bin2bcd.sv \

read_xdc fpga/arty-a7-35t/xdc/Arty-A7-35.xdc

synth_design -top top -part xc7a35ticsg324-1L

opt_design
place_design
route_design

write_bitstream -force aoc.bit