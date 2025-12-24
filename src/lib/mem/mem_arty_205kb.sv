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
 *  mem_arty_205kb.sv
 *  Top module for solving Advent of Code 2025
*/

module mem_arty_205kb #(
  parameter N_ARTY_BRAM = 50,
  parameter WIDTH = 8,
  parameter DEPTH = 4096 * N_ARTY_BRAM
) (
  input clk,
  input wr_en,
  input [WIDTH-1:0] wr_data,
  input [$clog2(DEPTH)-1:0] wr_addr,

  input rd_en,
  input [$clog2(DEPTH)-1:0] rd_addr,
  output [WIDTH-1:0] rd_data
);

  localparam ID_WIDTH   = $clog2(50);
  localparam ADDR_WIDTH = $clog2(4096);

  logic [WIDTH-1:0] mem_rd_data;

  wire [ID_WIDTH-1:0]   block_wr_id   = wr_addr[ID_WIDTH + ADDR_WIDTH - 1:ADDR_WIDTH];
  wire [ADDR_WIDTH-1:0] block_wr_addr = wr_addr[ADDR_WIDTH-1:0];
  wire [ID_WIDTH-1:0]   block_rd_id   = rd_addr[ID_WIDTH + ADDR_WIDTH - 1:ADDR_WIDTH];
  wire [ADDR_WIDTH-1:0] block_rd_addr = rd_addr[ADDR_WIDTH-1:0];

  wire [N_ARTY_BRAM-1:0] block_wr_en, block_rd_en;
  wire [WIDTH-1:0] block_rd_data[N_ARTY_BRAM];
  assign block_wr_en = wr_en << block_wr_id;
  assign block_rd_en = rd_en << block_rd_id;
  generate
    genvar i;
    for (i = 0; i < N_ARTY_BRAM; i++) begin : gen_mem
      mem_arty_4kb_wrapper #(
        .WIDTH(WIDTH),
        .DEPTH(4096)
      ) i_mem (
        .clk(clk),
        .wr_en(block_wr_en[i]),
        .wr_addr(block_wr_addr),
        .wr_data(wr_data),
        .rd_en(block_rd_en[i]),
        .rd_addr(block_rd_addr),
        .rd_data(block_rd_data[i])
      );
    end
  endgenerate

  logic [ID_WIDTH-1:0] block_rd_id_r;
  always_ff @(posedge clk) block_rd_id_r <= block_rd_id;
  assign rd_data = block_rd_data[block_rd_id_r];
endmodule