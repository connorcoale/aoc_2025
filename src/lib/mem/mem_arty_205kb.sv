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
  input clock,
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
        .clock(clock),
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
  always_ff @(posedge clock) block_rd_id_r <= block_rd_id;
  assign rd_data = block_rd_data[block_rd_id_r];

  task automatic tb_write(
      input int unsigned global_addr,
      input logic [WIDTH-1:0] data
  );
      int unsigned bram;
      int unsigned local_addr;

      bram  = global_addr >> 12;
      local_addr = global_addr & 12'hFFF;

      // Have to do it this way because of verilator quirks...
      case (bram)
          00: gen_mem[00].i_mem.mem[local_addr] = data;
          01: gen_mem[01].i_mem.mem[local_addr] = data;
          02: gen_mem[02].i_mem.mem[local_addr] = data;
          03: gen_mem[03].i_mem.mem[local_addr] = data;
          04: gen_mem[04].i_mem.mem[local_addr] = data;
          05: gen_mem[05].i_mem.mem[local_addr] = data;
          06: gen_mem[06].i_mem.mem[local_addr] = data;
          07: gen_mem[07].i_mem.mem[local_addr] = data;
          08: gen_mem[08].i_mem.mem[local_addr] = data;
          09: gen_mem[09].i_mem.mem[local_addr] = data;
          10: gen_mem[10].i_mem.mem[local_addr] = data;
          11: gen_mem[11].i_mem.mem[local_addr] = data;
          12: gen_mem[12].i_mem.mem[local_addr] = data;
          13: gen_mem[13].i_mem.mem[local_addr] = data;
          14: gen_mem[14].i_mem.mem[local_addr] = data;
          15: gen_mem[15].i_mem.mem[local_addr] = data;
          16: gen_mem[16].i_mem.mem[local_addr] = data;
          17: gen_mem[17].i_mem.mem[local_addr] = data;
          18: gen_mem[18].i_mem.mem[local_addr] = data;
          19: gen_mem[19].i_mem.mem[local_addr] = data;
          20: gen_mem[20].i_mem.mem[local_addr] = data;
          21: gen_mem[21].i_mem.mem[local_addr] = data;
          22: gen_mem[22].i_mem.mem[local_addr] = data;
          23: gen_mem[23].i_mem.mem[local_addr] = data;
          24: gen_mem[24].i_mem.mem[local_addr] = data;
          25: gen_mem[25].i_mem.mem[local_addr] = data;
          26: gen_mem[26].i_mem.mem[local_addr] = data;
          27: gen_mem[27].i_mem.mem[local_addr] = data;
          28: gen_mem[28].i_mem.mem[local_addr] = data;
          29: gen_mem[29].i_mem.mem[local_addr] = data;
          30: gen_mem[30].i_mem.mem[local_addr] = data;
          31: gen_mem[31].i_mem.mem[local_addr] = data;
          32: gen_mem[32].i_mem.mem[local_addr] = data;
          33: gen_mem[33].i_mem.mem[local_addr] = data;
          34: gen_mem[34].i_mem.mem[local_addr] = data;
          35: gen_mem[35].i_mem.mem[local_addr] = data;
          36: gen_mem[36].i_mem.mem[local_addr] = data;
          37: gen_mem[37].i_mem.mem[local_addr] = data;
          38: gen_mem[38].i_mem.mem[local_addr] = data;
          39: gen_mem[39].i_mem.mem[local_addr] = data;
          40: gen_mem[40].i_mem.mem[local_addr] = data;
          41: gen_mem[41].i_mem.mem[local_addr] = data;
          42: gen_mem[42].i_mem.mem[local_addr] = data;
          43: gen_mem[43].i_mem.mem[local_addr] = data;
          44: gen_mem[44].i_mem.mem[local_addr] = data;
          45: gen_mem[45].i_mem.mem[local_addr] = data;
          46: gen_mem[46].i_mem.mem[local_addr] = data;
          47: gen_mem[47].i_mem.mem[local_addr] = data;
          48: gen_mem[48].i_mem.mem[local_addr] = data;
          49: gen_mem[49].i_mem.mem[local_addr] = data;
          default: ;
      endcase
  endtask
endmodule