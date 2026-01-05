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

/*
 *  mem_arty_full.sv
 *  Top module for solving Advent of Code 2025
*/


module mem_arty_full #(
  parameter N_ARTY_BRAM = 50,
  parameter WIDTH = 8,
  parameter DEPTH = 4096 * N_ARTY_BRAM
) (
  input clock,
  input wr_en,
  input [WIDTH-1:0] wr_data,
  input [$clog2(DEPTH)-1:0] wr_addr,

  input rd_en,
  input [$clog2(DEPTH)-1:0] rd_addr,
  output [WIDTH-1:0] rd_data
);
  logic [WIDTH-1:0] mem [DEPTH];
  logic [WIDTH-1:0] mem_rd_data;
  always_ff @(posedge clock) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end else if (rd_en) begin
      mem_rd_data <= mem[rd_addr];
    end
  end
  assign rd_data = mem_rd_data;
endmodule