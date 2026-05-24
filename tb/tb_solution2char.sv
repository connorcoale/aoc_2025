/*
 *  Copyright (C) 2025  Connor Coale
 *
 *  This file is part of aoc_2025.
 *
 *  aoc_2025 is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  aoc_2025 is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with aoc_2025.  If not, see <https://www.gnu.org/licenses/>.
 */
`timescale 1ns/1ns

module tb_solution2char;
  logic clock;
  logic resetn;
  logic [48-1:0] solution_a, solution_b;
  logic [3:0] day;
  logic convert;
  logic done_tx;
  logic [8*32-1:0] message_flat;
  logic done;

  int pass_count;
  int fail_count;

  // ------------------------------------------------------------
  // Clock
  // ------------------------------------------------------------
  initial begin
    clock = 1'b0;
    forever #1 clock = ~clock;
  end

  // ------------------------------------------------------------
  // Clocking block
  // ------------------------------------------------------------
  clocking cb @(posedge clock);
    default output #0;
    output resetn;
    output solution_a;
    output solution_b;
    output day;
    output convert;
    output done_tx;
    input  done;
  endclocking

  // ------------------------------------------------------------
  // DUT
  // ------------------------------------------------------------
  solution2char solution2char (
    .clock(clock),
    .resetn(resetn),
    .solution_a(solution_a),
    .solution_b(solution_b),
    .day(day),
    .convert(convert),
    .done_tx(done_tx),
    .message_flat(message_flat),
    .done(done)
  );

  // ------------------------------------------------------------
  // Wave dump
  // ------------------------------------------------------------
  initial begin
    $dumpfile("sim/trace/trace_solution2char.vcd");
    $dumpvars(0, tb_solution2char);
  end

  // ------------------------------------------------------------
  // Run one test case
  // ------------------------------------------------------------
  task run_test(input [47:0] a, input [47:0] b, input [3:0] d,
                input string desc, input [7:0] exp[0:31]);
    int mismatch;
    logic [7:0] got;

    // Drive inputs
    @(cb);
    cb.solution_a <= a;
    cb.solution_b <= b;
    cb.day        <= d;
    cb.convert    <= 1'b1;
    @(cb);
    cb.convert <= 1'b0;

    // Wait for done (level-sensitive, avoids race with 0->1 edge)
    wait(done);
    @(cb);

    // Compare byte-by-byte
    mismatch = -1;
    for (int i = 0; i < 32; i++) begin
      got = message_flat[i*8 +: 8];
      if (got != exp[i]) begin
        mismatch = i;
        break;
      end
    end

    // Display result
    if (mismatch == -1) begin
      $display("\033[0;32mPASS:\033[0m day=%0d %s", d, desc);
      pass_count++;
    end else begin
      $display("\033[0;31mFAIL:\033[0m day=%0d %s byte %0d: got 0x%0h, exp 0x%0h",
               d, desc, mismatch, got, exp[mismatch]);
      fail_count++;
    end

    // Clear done for next test
    cb.done_tx <= 1'b1;
    @(cb);
    cb.done_tx <= 1'b0;
    @(cb);
  endtask

  // ------------------------------------------------------------
  // Build expected byte array helper
  // ------------------------------------------------------------
  function automatic void build_exp(input [3:0] d, input logic [7:0] sa[12],
                                    input logic [7:0] sb[12],
                                    output logic [7:0] exp[0:31]);
    // Format: "DD: SSSSSSSSSSSS,TTTTTTTTTTTT\0\0\0"
    exp[0] = 8'((d > 9) ? 1 : 0) + 8'd48;
    exp[1] = 8'((d > 9) ? d - 10 : d) + 8'd48;
    exp[2] = 8'h3A; // ':'
    exp[3] = 8'h20; // ' '
    for (int i = 0; i < 12; i++) exp[4  + i] = sa[i];
    exp[16] = 8'h2C; // ','
    for (int i = 0; i < 12; i++) exp[17 + i] = sb[i];
    exp[29] = 8'h00;
    exp[30] = 8'h00;
    exp[31] = 8'h00;
  endfunction

  // ------------------------------------------------------------
  // Helper to convert a 48-bit BCD value to 12 ASCII digit bytes
  // (MSD-first: nibble 11 at byte 0, nibble 0 at byte 11)
  // ------------------------------------------------------------
  function automatic void bcd_to_digits(input [47:0] val, output logic [7:0] digits[12]);
    for (int i = 0; i < 12; i++)
      digits[i] = val[44 - i*4 +: 4] + 8'd48;
  endfunction

  // ------------------------------------------------------------
  // Stimulus
  // ------------------------------------------------------------
  initial begin
    logic [7:0] exp[0:31];
    logic [7:0] dig_a[12];
    logic [7:0] dig_b[12];

    pass_count = 0;
    fail_count = 0;

    // Reset
    cb.resetn     <= 1'b0;
    cb.solution_a <= '0;
    cb.solution_b <= '0;
    cb.day        <= '0;
    cb.convert    <= 1'b0;
    cb.done_tx    <= 1'b0;
    @(cb);
    cb.resetn <= 1'b1;
    @(cb);

    // ======== Test 1: BCD, both fill all 12 digits ========
    // A=0x123456789012, B=0x987654321098
    // Expected: "02: 123456789012,987654321098\0\0\0"
    bcd_to_digits(48'h123456789012, dig_a);
    bcd_to_digits(48'h987654321098, dig_b);
    build_exp(4'd2, dig_a, dig_b, exp);
    run_test(48'h123456789012, 48'h987654321098, 4'd2, "BCD both full", exp);

    // ======== Test 2: BCD, both with leading zeros ========
    // A=0x000000001234, B=0x000000005678
    // Expected: "02: 000000001234,000000005678\0\0\0"
    bcd_to_digits(48'h000000001234, dig_a);
    bcd_to_digits(48'h000000005678, dig_b);
    build_exp(4'd2, dig_a, dig_b, exp);
    run_test(48'h000000001234, 48'h000000005678, 4'd2, "BCD both leading-zero", exp);

    // ======== Test 3: BCD, only one fills all 12 ========
    // A=0x123456789012, B=0x000000003456
    // Expected: "02: 123456789012,000000003456\0\0\0"
    bcd_to_digits(48'h123456789012, dig_a);
    bcd_to_digits(48'h000000003456, dig_b);
    build_exp(4'd2, dig_a, dig_b, exp);
    run_test(48'h123456789012, 48'h000000003456, 4'd2, "BCD one voll one leading-zero", exp);

    // ======== Test 4: BCD, all zeros ========
    bcd_to_digits(48'h000000000000, dig_a);
    bcd_to_digits(48'h000000000000, dig_b);
    build_exp(4'd2, dig_a, dig_b, exp);
    run_test(48'h000000000000, 48'h000000000000, 4'd2, "BCD all zero", exp);

    // ======== Test 5: BCD, all 9s ========
    bcd_to_digits(48'h999999999999, dig_a);
    bcd_to_digits(48'h999999999999, dig_b);
    build_exp(4'd2, dig_a, dig_b, exp);
    run_test(48'h999999999999, 48'h999999999999, 4'd2, "BCD all 9s", exp);

    // ======== Test 6: Normal (bin2bcd), max value 999_999_999_999 ========
    // bin2bcd converts binary 999_999_999_999 to BCD 0x999999999999
    // Expected: "00: 999999999999,000000000000\0\0\0"
    bcd_to_digits(48'h999999999999, dig_a);
    bcd_to_digits(48'h000000000000, dig_b);
    build_exp(4'd0, dig_a, dig_b, exp);
    run_test(48'd999999999999, 48'd0, 4'd0, "BIN max", exp);

    // ======== Test 7: Normal, zero and one (bin2bcd edge cases) ========
    // bin2bcd converts 0 to BCD 0x000000000000, 1 to BCD 0x000000000001
    // Expected: "00: 000000000000,000000000001\0\0\0"
    bcd_to_digits(48'h000000000000, dig_a);
    bcd_to_digits(48'h000000000001, dig_b);
    build_exp(4'd0, dig_a, dig_b, exp);
    run_test(48'd0, 48'd1, 4'd0, "BIN zero and one", exp);

    // ======== Test 8: Normal, typical values through bin2bcd ========
    // 123456789 -> BCD 0x000123456789, 987654321 -> BCD 0x000987654321
    // Expected: "00: 000123456789,000987654321\0\0\0"
    bcd_to_digits(48'h000123456789, dig_a);
    bcd_to_digits(48'h000987654321, dig_b);
    build_exp(4'd0, dig_a, dig_b, exp);
    run_test(48'd123456789, 48'd987654321, 4'd0, "BIN typical", exp);

    // ======== Test 9: Day > 9 (tens-digit formatting) through bin2bcd ========
    // Day 10 is not day 2, so takes the bin2bcd path
    // Expected: "10: 000000000000,000000000000\0\0\0"
    bcd_to_digits(48'h000000000000, dig_a);
    bcd_to_digits(48'h000000000000, dig_b);
    build_exp(4'd10, dig_a, dig_b, exp);
    run_test(48'd0, 48'd0, 4'd10, "BIN day 10 tens-digit", exp);

    $finish;
  end
endmodule
