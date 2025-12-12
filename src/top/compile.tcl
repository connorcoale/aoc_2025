read_verilog -sv top.sv \
 ../lib/uart/uart_rx.sv \
 ../lib/uart/uart_tx.sv \
 ../01/src/top_01.sv

read_xdc ./xdc/Arty-A7-35.xdc

synth_design -top top -part xc7a35ticsg324-1L

opt_design
place_design
route_design

write_bitstream -force aoc.bit