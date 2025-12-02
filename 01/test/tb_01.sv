module tb_01 ();
logic in1;
logic out1;
top_01 dut (
  .in1(in1),
  .out1(out1)
);
initial begin
  in1 = 1'b0;
  #10
  in1 = 1'b1;
  #10
  in1 = 1'b0;
  $finish;
end
endmodule