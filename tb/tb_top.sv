// Attribution: This IP is licensed freely under the MIT license by Ben Marshall
// Link to source repo: https://github.com/ben-marshall/uart/tree/master

//
// Module: tb
//
// Notes:
// - Top level simulation testbench.
// - Modified by Connor Coale
//

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
  .solve_day_n   (solve_day_n),
  .print_soln_n  (print_soln_n),
  .sw            (sw),
  .uart_rxd      (uart_rxd),
  .uart_txd      (uart_txd)
  );

  int pass_count;
  int fail_count;

  // Module-scope so VCD tracing can see them
  string exp_msg;
  string got_msg;
  logic [255:0] exp_msg_flat;
  logic [255:0] got_msg_flat;
  logic [7:0] dig_a[12], dig_b[12];
  longint expected_a, expected_b;

  // ---------------------------------------------
  // Dumpfile (disabled for performance — enable by defining TRACE)
  // ---------------------------------------------
`ifdef TRACE
  initial begin
  $dumpfile("sim/trace/trace_tb_top.vcd");
  $dumpvars(1, tb_top);
  end
`endif

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

    $fclose(fd);
  endtask

  // ---------------------------------------------
  // UART receive-byte task (samples uart_txd at baud rate)
  // ---------------------------------------------
  task recv_byte(output byte b);
    int timeout;
    // Wait for start bit (poll uart_txd to avoid hierarchical event issues)
    timeout = 0;
    while (uart_txd) begin
      @(posedge clock);
      if (timeout > CLK_PER_BAUD * 100) begin
        $display("[TB] recv_byte timeout waiting for start bit");
        return;
      end
      timeout++;
    end
    // Wait 1.5 bit periods to align with center of bit 0
    repeat ((CLK_PER_BAUD * 3) / 2) @(posedge clock);
    for (int i = 0; i < 8; i++) begin
      b[i] = uart_txd;
      if (i < 7) repeat (CLK_PER_BAUD) @(posedge clock);
    end
    // Skip stop bit
    repeat (CLK_PER_BAUD) @(posedge clock);
  endtask

  // ---------------------------------------------
  // Receive a 32-byte message from UART
  // ---------------------------------------------
  task recv_message(output string msg);
    byte b;
    msg = "";
    for (int i = 0; i < 32; i++) begin
      recv_byte(b);
      msg = {msg, string'(b)};
    end
  endtask

  // ---------------------------------------------
  // Convert a 64-bit integer to 12 ASCII digit bytes
  // (MSD-first: digits[0] = most significant digit)
  // ---------------------------------------------
  function automatic void longint_to_digits(input longint val, output logic [7:0] digits[12]);
    logic [7:0] tmp[12];
    for (int i = 0; i < 12; i++) begin
      tmp[i] = (val % 10) + 8'd48;
      val = val / 10;
    end
    // Reverse so digits[0] = MSD, digits[11] = LSD
    for (int i = 0; i < 12; i++) begin
      digits[i] = tmp[11 - i];
    end
  endfunction

  // ---------------------------------------------
  // Build expected message in format "DD: SSSSSSSSSSSS,TTTTTTTTTTTT\0\0\0"
  // Matching solution2char's output format
  // ---------------------------------------------
  function automatic string build_expected_message(input [3:0] d, input logic [7:0] sa[12],
                                                       input logic [7:0] sb[12]);
    string exp;
    exp = {string'(8'((d > 9) ? 1 : 0) + 8'd48),
           string'(8'((d > 9) ? d - 10 : d) + 8'd48),
           ":", " "};
    for (int i = 0; i < 12; i++) exp = {exp, string'(sa[i])};
    exp = {exp, ","};
    for (int i = 0; i < 12; i++) exp = {exp, string'(sb[i])};
    for (int i = 0; i < 3; i++)  exp = {exp, string'(8'h00)};
    return exp;
  endfunction

  // ---------------------------------------------
  // Read reference CSV for a given day
  // Returns 1 if found, 0 if not
  // ---------------------------------------------
  function int read_ref_csv(input int day, output longint a, output longint b);
    int fd;
    string hdr;
    fd = $fopen($sformatf("sim/results/ref_%02d.csv", day), "r");
    if (fd != 0) begin
      void'($fgets(hdr, fd));  // skip CSV header
      void'($fscanf(fd, "%d,%d", a, b));
      $fclose(fd);
      return 1;
    end
    return 0;
  endfunction

  // ---------------------------------------------
  // Compare received message against expected
  // ---------------------------------------------
  task compare_message(input int day, input string got, input string exp);
    int mismatch;
    mismatch = -1;
    for (int i = 0; i < 32; i++) begin
      if (got[i] != exp[i]) begin
        mismatch = i;
        break;
      end
    end

    if (mismatch == -1) begin
      $display("\033[0;32mPASS:\033[0m day=%0d", day);
      pass_count++;
    end else begin
      $display("\033[0;31mFAIL:\033[0m day=%0d byte %0d: got 0x%0h ('%c'), exp 0x%0h ('%c')",
               day, mismatch, got[mismatch], got[mismatch], exp[mismatch], exp[mismatch]);
      fail_count++;
    end
  endtask

  // ---------------------------------------------
  // Backdoor load: write transmission data directly to memory
  // bypassing UART RX. Also sets up day_mem_addr registers.
  // ---------------------------------------------
  task send_input_backdoor(input string fname);
    int fd;
    logic [7:0] byte_val;
    int addr;
    int day_mem_ptr;

    fd = $fopen(fname, "rb");
    if (fd == 0) $fatal("Failed to open: %s", fname);

    addr = 0;
    day_mem_ptr = 1;

    // Read file byte by byte, skipping the first (STX)
    while (1) begin
      int r;
      r = $fread(byte_val, fd);
      if (r == 0) break;

      if (addr != 0) begin
        i_dut.mem.tb_write(addr - 1, byte_val);
        if (byte_val == 8'h03) begin
          i_dut.tb_set_day_addr(day_mem_ptr, addr);
          day_mem_ptr++;
        end else if (byte_val == 8'h04) begin
          break;
        end
      end
      addr++;
    end

    $fclose(fd);
    $display("Backdoor load: %0d bytes, %0d days", addr - 1, day_mem_ptr - 1);
  endtask

  // ---------------------------------------------
  // Test sequence
  // ---------------------------------------------
  initial begin
    pass_count = 0;
    fail_count = 0;

    uart_rxd      = 1'b1;
    resetn        = 1'b0;
    solve_day_n   = 1'b1;
    print_soln_n  = 1'b1;
    sw            = '0;

    // Let the clock settle
    repeat (10) @(posedge clock);
    resetn = 1'b1;
    repeat (20) @(posedge clock);

`ifdef BACKDOOR_LOAD
    send_input_backdoor("sim/stimulus/transmission1-2.bin");
    repeat (10) @(posedge clock);
`else
    $display("[TB] Loading transmission via UART...");
    send_input("sim/stimulus/transmission1-2.bin");
    // Wait for UART load to finish
    repeat (50000) @(posedge clock);
`endif
    $display("[TB] Transmission loaded, starting solve checks...");

    // ======== Test sequence with timeout ========
    fork begin : test_seq
      // Test days that have both HW instantiated and reference CSVs
      for (int d = 1; d <= 2; d++) begin
      if (read_ref_csv(d, expected_a, expected_b)) begin
        // Build expected message from reference
        longint_to_digits(expected_a, dig_a);
        longint_to_digits(expected_b, dig_b);
        exp_msg = build_expected_message(d[3:0], dig_a, dig_b);

        // Solve day d
        $display("[TB] Solving day %0d...", d);
        sw = d[3:0];
        solve_day_n = 1'b0;
        @(posedge clock);
        @(posedge clock);
        solve_day_n = 1'b1;

        // Wait for the part module to finish solving (poll with timeout)
        for (int timeout = 0; timeout < 10_000_000; timeout++) begin
          if (i_dut.solution_valid[d-1]) break;
          @(posedge clock);
        end
        if (!i_dut.solution_valid[d-1]) begin
          $display("\033[0;31m[TB] TIMEOUT waiting for day %0d solution_valid\033[0m", d);
          $finish;
        end
        @(posedge clock);
        $display("[TB] Day %0d solved, capturing output...", d);

        // Print solution and capture output
`ifdef BACKDOOR_READ
        // Pulse print, wait for TX done, read message directly
        sw = d[3:0];
        print_soln_n = 1'b0;
        @(posedge clock);
        print_soln_n = 1'b1;
        wait(i_dut.done_tx);
        @(posedge clock);
        got_msg = "";
        for (int j = 0; j < 32; j++) got_msg = {got_msg, string'(i_dut.inst_solution2char.message_flat[j*8+:8])};
`else
        sw = d[3:0];
        print_soln_n = 1'b0;
        @(posedge clock);
        print_soln_n = 1'b1;

        // Capture the 32-byte message transmitted over UART TX
        recv_message(got_msg);
`endif


        compare_message(d, got_msg, exp_msg);
        $display("day: %0d\n got_msg: \"%s\"\n exp_msg: \"%s\"", d, got_msg, exp_msg);
      end
    end

    end // test_seq

    begin : timeout
      repeat (10_000_000) @(posedge clock);
      $display("");
      $display("============================================");
      $display("\033[0;31m  TIMEOUT: Test did not complete\033[0m");
      $display("============================================");
      $display("  %0d passed, %0d failed so far", pass_count, fail_count);
      $display("============================================");
      $finish;
    end
  join_any
  disable fork;

  repeat (1_000) @(posedge clock);

  // Summary
  if (fail_count == 0)
    $display("\033[0;32m  %0d passed, %0d failed\033[0m", pass_count, fail_count);
  else
    $display("\033[0;31m  %0d passed, %0d failed\033[0m", pass_count, fail_count);
  $display("============================================");
  $display("Simulation finished at time %t", $time);
  $finish;
  end

  for (genvar j = 0; j < 32; j++) begin
    assign got_msg_flat[j*8+:8] = got_msg[31-j];
    assign exp_msg_flat[j*8+:8] = exp_msg[31-j];
  end
endmodule
