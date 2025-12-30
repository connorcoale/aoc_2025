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
  logic [31:0] solution_a, solution_b;
  logic [3:0] day;
  logic convert;
  logic done_tx;
  logic [8*32-1:0] message_flat;
  logic done;

  // ------------------------------------------------------------
  // Clock generation
  // ------------------------------------------------------------
  initial begin
    clock = 1'b0;
    forever #1 clock = ~clock;
  end

  // ------------------------------------------------------------
  // Clocking block
  //   - Drives inputs AFTER posedge
  //   - Samples outputs AFTER posedge
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
    input  message_flat;
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
  // Stimulus
  // ------------------------------------------------------------
  initial begin
    // Default values
    cb.resetn     <= 1'b0;
    cb.solution_a <= 32'd123456789;
    cb.solution_b <= 32'd987654321;
    cb.day        <= 4'd7;
    cb.convert    <= 1'b0;

    // Hold reset for 1 cycle
    @(cb);
    cb.resetn <= 1'b1;

    // Pulse convert for 1 clean cycle
    @(cb);
    cb.convert <= 1'b1;

    @(cb);
    cb.convert <= 1'b0;

    // Wait for completion
    repeat (500) @(cb);
    cb.done_tx <= 1'b1;
    @(cb);
    cb.done_tx <= 1'b0;
    repeat (10) @(cb);
    $finish;
  end

endmodule