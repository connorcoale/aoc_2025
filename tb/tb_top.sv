// Attribution: This IP is licensed freely under the MIT license by Ben Marshall
// Link to source repo: https://github.com/ben-marshall/uart/tree/master

// 
// Module: tb
// 
// Notes:
// - Top level simulation testbench.
// - Modified by Connor Coale

`timescale 1ns/1ns

module tb_top;
  // ---------------------------------------------
  // Clock & UART Inputs
  // ---------------------------------------------
  reg clock;
  reg resetn;
  reg uart_rxd;

  // ---------------------------------------------
  // Clock parameters
  // ---------------------------------------------
  localparam CLK_MHZ  = 100; // arty a7 has 100MHz clock
  // localparam CLK_HZ   = CLK_MHZ * 1_000_000;
  localparam CLK_HZ  = 2_500_000; // let's scale it down 50x to make the sim run faster
  localparam CLK_P  = 1_000_000_000 / CLK_HZ;   // ns per cycle

  // UART bitrate
  localparam BIT_RATE   = 115200;
  localparam CLK_PER_BAUD = CLK_HZ / BIT_RATE;

  // ---------------------------------------------
  // Dumpfile
  // ---------------------------------------------
  initial begin
  $dumpfile("sim/trace/trace_tb_top.vcd");
  $dumpvars(1, tb_top);
  end

  // ---------------------------------------------
  // Clock generation
  // ---------------------------------------------
  initial clock = 1'b0;
  always #(CLK_P/2) clock = ~clock;

  // ---------------------------------------------
  // Baud tick generator (1-cycle tick)
  // ---------------------------------------------
  int cnt;
  reg baud;

  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      cnt  <= 0;
      baud <= 0;
    end else begin
      if (cnt == (CLK_PER_BAUD - 1)) begin
      cnt  <= 0;
      baud <= 1;
      end else begin
      cnt  <= cnt + 1;
      baud <= 0;
      end
    end
  end

  // ---------------------------------------------
  // UART send-byte task
  // ---------------------------------------------
  task send_byte(input byte b);
    int i;
    begin
      // start bit
      @(posedge baud);
      uart_rxd = 1'b0;

      // 8 data bits
      for (i = 0; i < 8; i++) begin
      @(posedge baud);
      uart_rxd = b[i];
      end

      // stop bit
      @(posedge baud);
      uart_rxd = 1'b1;
    end
  endtask

  // ---------------------------------------------
  // Send input file line-by-line as bytes
  // ---------------------------------------------
  task send_input(input string fname);
    int fd;
    string line;

    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $fatal("Failed to open file: %s", fname);
    end

    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      foreach (line[i]) begin
      send_byte(line[i]);
      end
    end

    // Send EOT (Ctrl-D)
    // send_byte(8'h04);

    $fclose(fd);
  endtask

  task send_input_backdoor(input string fname);
    int fd;
    string line;
    int unsigned addr = 0;
    int unsigned day_mem_ptr = 1;

    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $fatal("Failed to open file: %s", fname);
    end

    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      foreach (line[i]) begin
        if (addr != 0) i_dut.mem.tb_write(addr-1, line[i]);
        if (line[i] == 8'h03) begin
          i_dut.day_mem_addr[day_mem_ptr] = addr;
          day_mem_ptr++;
        end
        addr++;
      end
    end

    $display("Backdoor load complete: %0d bytes written", addr);
    $fclose(fd);
  endtask

  // ---------------------------------------------
  // Test sequence
  // ---------------------------------------------
  initial begin
  uart_rxd      = 1'b1;
  resetn        = 1'b0;
  print_input_n = 1'b1;
  solve_day_n   = 1'b1;
  print_soln_n  = 1'b1;
  sw            = '0;

  // Let the clock/baud settle
  repeat (10) @(posedge clock);
  resetn = 1'b1;

  // Wait a little before sending data
  repeat (20) @(posedge clock);

  // send_input("sim/stimulus/example_transmission.bin");
  // send_input("sim/stimulus/transmission.bin");
  // send_input("sim/stimulus/transmission1-2.bin");
  send_input_backdoor("sim/stimulus/transmission1-2.bin");
  repeat (100) @(posedge clock);
  print_input_n = 1'b0;
  @(posedge clock);
  print_input_n = 1'b1;
  repeat (100) @(posedge clock);


  repeat (50000) @(posedge clock);
  sw = 4'd01;
  solve_day_n = 1'b0;
  @(posedge clock);
  solve_day_n = 1'b1;
  repeat (50000) @(posedge clock);

  sw = 4'd1;
  print_soln_n = 1'b0;
  @(posedge clock);
  print_soln_n = 1'b1;
  @(posedge clock);

  repeat (10000) @(posedge clock);

  sw = 4'd02;
  solve_day_n = 1'b0;
  @(posedge clock);
  solve_day_n = 1'b1;
  repeat (2500000) @(posedge clock);

  sw = 4'd2;
  print_soln_n = 1'b0;
  @(posedge clock);
  print_soln_n = 1'b1;
  @(posedge clock);

  repeat (50000) @(posedge clock);


  $display("Simulation finished at time %t", $time);
  $finish;
  end

  // ---------------------------------------------
  // DUT
  // ---------------------------------------------
  wire uart_txd;
  logic print_input_n;
  logic solve_day_n;
  logic print_soln_n;
  logic [3:0] sw;

  top #(
  .BIT_RATE      (BIT_RATE),
  .CLK_HZ        (CLK_HZ)
  ) i_dut (
  .clock         (clock),
  .resetn        (resetn),
  .print_input_n (print_input_n),
  .solve_day_n   (solve_day_n),
  .print_soln_n  (print_soln_n),
  .sw            (sw),
  .uart_rxd      (uart_rxd),
  .uart_txd      (uart_txd)
  );
endmodule