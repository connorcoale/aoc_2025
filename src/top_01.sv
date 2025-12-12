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
 *  top_01.sv
 *  Top module for solving Advent of Code 2025, problem 01.
*/
module top_01 #(
  parameter MAX_DIAL           = 99,
  parameter MAX_TWIST          = 999
) (
  input clk,
  input reset,
  input cs,
  input [7:0] data,
  input data_valid,
  output [7:0] solution,
  output solution_valid
);

  solve_01 #(
    .MAX_DIAL(MAX_DIAL),
    .MAX_TWIST(MAX_TWIST)
  ) inst_solve_01 (
    .clk(clk),
    .reset(reset),
    .data(data),
    .data_valid(data_valid),
    .solution(solution),
    .solution_valid(solution_valid)
  );


endmodule

module solve_01 #(
  parameter MAX_DIAL,
  parameter MAX_TWIST,
  parameter MAX_DIAL_W         = $clog2(MAX_DIAL),
  parameter MAX_TWIST_W        = $clog2(MAX_TWIST),
  parameter MAX_TWISTED_DIAL   = MAX_TWIST + MAX_DIAL,
  parameter MAX_TWISTED_DIAL_W = $clog2(MAX_TWISTED_DIAL) + 1
) (
  input        clk,
  input        reset,
  input [7:0]  data,
  input        data_valid,
  output [7:0] solution,
  output       solution_valid
);

  typedef enum {
    IDLE,
    TWIST
  } e_state;

  e_state state_r, state_next;
  logic signed   [MAX_TWIST_W-1:0]        twist_r, twist_next;
  logic unsigned [MAX_DIAL_W-1:0]         dial_r, dial_out, dial_next;
  logic                                   cw_r, cw_next;

  logic ends_at_zero;
  logic [$clog2(10)-1:0] zero_passes;
  safe_twister #(
    .MAX_DIAL_W(MAX_DIAL_W),
    .MAX_TWIST_W(MAX_TWIST_W),
    .MAX_TWISTED_DIAL_W(MAX_TWISTED_DIAL_W)
  ) inst_safe_twister (
    .dial_in(dial_r),
    .twist(twist_r),
    .cw(cw_r),
    .dial_out(dial_out),
    .zero(ends_at_zero),
    .zero_passes(zero_passes)
  );

  always_comb begin
    state_next = state_r;
    twist_next = twist_r;
    dial_next  = dial_r;
    cw_next    = cw_r;
    case (state_r)
      IDLE : begin
        if (data_valid) begin
          if (data == 8'h52) begin
            // R
            state_next = TWIST;
            cw_next = 1'b1;
          end
          if (data == 8'h4C) begin
            // L
             state_next = TWIST;
             cw_next = 1'b0;
          end
          twist_next = '0;
          dial_next = 'd50;
        end
      end
      TWIST : begin
        if (!data_valid) state_next = TWIST; // do nothing
        else if (8'h30 <= data && data <= 8'h39) begin
          // state stays the same
          twist_next = (twist_r * 10) + data - 8'h30;
        end else begin
          if (data == 8'h0A) begin
            // newline
            dial_next = dial_out;
          end else if (data == 8'h52) begin
            cw_next = 1'b1;
            twist_next = '0;
          end else if (data == 8'h4C) begin
            cw_next = 1'b0;
            twist_next = '0;
          end
        end
      end
    endcase
    if (state_r == TWIST && data_valid && data == 8'h04) begin
      state_next = IDLE;
    end
  end

  // Flopping of state signals
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state_r <= IDLE; 
      twist_r <= '0;
      dial_r <= '0;
      cw_r <= 1'b0;
    end
    else begin
      state_r <= state_next;
      twist_r <= twist_next;
      dial_r <= dial_next;
      cw_r <= cw_next;
    end
  end

  // Count how many times it ends at zero
  logic [15:0] ends_at_zero_r, ends_at_zero_next;
  logic twist_end;
  logic inc_zero;
  assign twist_end = data_valid && (data == 8'h0A);
  assign inc_zero = twist_end && ends_at_zero;
  assign ends_at_zero_next = ends_at_zero_r + inc_zero;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) ends_at_zero_r <= '0;
    else ends_at_zero_r <= ends_at_zero_next;
  end

  // Count how many times it passes and ends at zero
  logic [31:0] times_pointing_at_zero_r, times_pointing_at_zero_next;
  logic [$clog2(11)-1:0] inc_pointing;
  assign inc_pointing = twist_end ? ends_at_zero + zero_passes : '0;
  assign times_pointing_at_zero_next = times_pointing_at_zero_r + inc_pointing;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) times_pointing_at_zero_r <= '0;
    else times_pointing_at_zero_r <= times_pointing_at_zero_next;
  end
endmodule

module safe_twister #(
  parameter MAX_DIAL_W,
  parameter MAX_TWIST_W,
  parameter MAX_TWISTED_DIAL_W
) (
  input [MAX_DIAL_W-1:0]        dial_in,
  input [MAX_TWIST_W-1:0]       twist,
  input                         cw,
  output logic [MAX_DIAL_W-1:0] dial_out,
  output logic                  zero,
  output logic [$clog2(10)-1:0] zero_passes
);
  logic signed [MAX_TWISTED_DIAL_W-1:0] twisted_dial_total;
  assign twisted_dial_total = cw ? dial_in + twist : dial_in - twist;

  // determine how many twists were needed to get to this point
  logic [$clog2(10)-1:0] twist_modulo;
  always_comb begin
    case (twisted_dial_total) inside
      [-999: -901] : twist_modulo = 'd10;
      [-900: -801] : twist_modulo = 'd9;
      [-800: -701] : twist_modulo = 'd8;
      [-700: -601] : twist_modulo = 'd7;
      [-600: -501] : twist_modulo = 'd6;
      [-500: -401] : twist_modulo = 'd5;
      [-400: -301] : twist_modulo = 'd4;
      [-300: -201] : twist_modulo = 'd3;
      [-200: -101] : twist_modulo = 'd2;
      [-100:   -1] : twist_modulo = 'd1;
      [   0:  100] : twist_modulo = 'd0;
      [ 101:  200] : twist_modulo = 'd1;
      [ 201:  300] : twist_modulo = 'd2;
      [ 301:  400] : twist_modulo = 'd3;
      [ 401:  500] : twist_modulo = 'd4;
      [ 501:  600] : twist_modulo = 'd5;
      [ 601:  700] : twist_modulo = 'd6;
      [ 701:  800] : twist_modulo = 'd7;
      [ 801:  900] : twist_modulo = 'd8;
      [ 901: 1000] : twist_modulo = 'd9;
      [1001: 1098] : twist_modulo = 'd10;
      default      : twist_modulo = 'd0;
    endcase
  end

  // Determine what the new dial number is without using
  // modulo operator
  logic neg, mult_of_100;
  logic signed [MAX_TWISTED_DIAL_W-1:0] modulo_adjustment;
  logic [MAX_DIAL_W:0] dial_neg, dial_pos;
  assign neg = twisted_dial_total < 0;
  assign mult_of_100 = twisted_dial_total == 'd100  ||
                 twisted_dial_total == 'd200  || 
                 twisted_dial_total == 'd300  || 
                 twisted_dial_total == 'd400  || 
                 twisted_dial_total == 'd500  || 
                 twisted_dial_total == 'd600  || 
                 twisted_dial_total == 'd700  || 
                 twisted_dial_total == 'd800  || 
                 twisted_dial_total == 'd900  || 
                 twisted_dial_total == 'd1000;
  // Value to add or subtract to get back in the range [0, 100]
  // Need to account for special case when the twisted_dial_total
  // was a positive multiple of 100
  assign modulo_adjustment = (twist_modulo + mult_of_100) * 100;

  assign dial_neg = twisted_dial_total + modulo_adjustment;
  assign dial_pos = twisted_dial_total - modulo_adjustment;
  always_comb begin
    // if (mult_of_100)    dial_out = '0;
    if (neg) dial_out = dial_neg;
    else     dial_out = dial_pos;
  end

  // Assign outputs
  assign zero = dial_out == '0;
  assign zero_passes = twist_modulo - (neg && (dial_in == '0));
endmodule