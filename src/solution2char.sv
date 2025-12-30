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
 *  solution2char.sv
 *  Convert the given solution to a nicely formatted char string.
*/

module solution2char #(
  parameter longint unsigned MAX_INT = 64'd999_999_999_999,
  localparam int unsigned SOL_BIT_W  = $clog2(MAX_INT + 1),
  localparam int unsigned SOL_DIG_W  = $rtoi($log10(MAX_INT)) + 1,
  localparam int unsigned ASCII_W    = 8,
  localparam int unsigned MSG_CHR_W  = 32,
  localparam int unsigned MSG_BIT_W  = MSG_CHR_W * ASCII_W
  ) (
  input                      clock,
  input                      resetn,
  input [SOL_BIT_W-1:0]      solution_a,
  input [SOL_BIT_W-1:0]      solution_b,
  input [3:0]                day,
  input                      convert,
  input                      done_tx,
  output reg [MSG_BIT_W-1:0] message_flat,
  output reg                 done
);

  logic [ASCII_W-1:0]     message [MSG_CHR_W];
  logic [3:0]             bcd_a [SOL_DIG_W];
  logic [4*SOL_DIG_W-1:0] bcd_a_flat;
  logic [3:0]             bcd_b [SOL_DIG_W];
  logic [4*SOL_DIG_W-1:0] bcd_b_flat;
  always_comb begin
    for (int i = 0; i < SOL_DIG_W; i++) bcd_a[i] = bcd_a_flat[(i+1)*4-1-:4];
    for (int i = 0; i < SOL_DIG_W; i++) bcd_b[i] = bcd_b_flat[(i+1)*4-1-:4];
  end
  bin2bcd #(.MAX_INT(MAX_INT)) bin2bcd_a (
    .clock(clock),
    .resetn(resetn),
    .convert(converting),
    .data(solution_a),
    .bcd_flat(bcd_a_flat),
    .done(done_a)
  );

  bin2bcd #(.MAX_INT(MAX_INT)) bin2bcd_b (
    .clock(clock),
    .resetn(resetn),
    .convert(converting),
    .data(solution_b),
    .bcd_flat(bcd_b_flat),
    .done(done_b)
  );

  wire both_done = done_a && done_b;
  logic converting, converting_next;
  typedef enum {
    IDLE,
    BUSY,
    DONE
  } e_state;
  e_state state_r, state_next;

  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      state_r    <= IDLE;
      converting <= 1'b0;
    end else begin
      state_r    <= state_next;
      converting <= converting_next;
    end
  end
  always_comb begin
    done = 1'b0;
    converting_next = converting;
    state_next = state_r;
    case (state_r)
      IDLE: begin
        if (convert) begin
          converting_next = 1'b1;
          state_next = BUSY;
        end
      end
      BUSY: begin
        if (both_done) begin
          state_next = DONE;
        end
      end
      DONE: begin
        converting_next = !done_tx;
        done = 1'b1;
        state_next = done_tx ? IDLE : state_r;
      end
    endcase
  end


  // Create the string in form:
  // "XX: aaaaaaaaaaaa,bbbbbbbbbbbb" where XX = day, aaa... = soln a, bbb... = soln b
  localparam SOL_A_IDX = 4;
  localparam COMMA_IDX = SOL_A_IDX + SOL_DIG_W;
  localparam SOL_B_IDX = COMMA_IDX + 1;
  localparam MSG_END   = SOL_B_IDX + SOL_DIG_W;
  assign message[0]         = 8'(day > 9) + 8'd48; // 0 or 1 for first char of the day number
  assign message[1]         = 8'((day > 9) ? day - 10 : day) + 8'd48; // the second char of the day number
  assign message[2]         = 8'h3A; // ":" ascii char
  assign message[3]         = 8'h20; // " " ascii char
  assign message[COMMA_IDX] = 8'h2c; // "," ascii char
  always_comb begin
    // Need to flip the ordering for printing in a string, hence 9-i
    for (int i = SOL_A_IDX; i < COMMA_IDX; i++)   message[i] = bcd_a[(SOL_DIG_W - 1) - (i - SOL_A_IDX)] + 8'd48;
    for (int j = SOL_B_IDX; j < MSG_END;   j++)   message[j] = bcd_b[(SOL_DIG_W - 1) - (j - SOL_B_IDX)] + 8'd48; // same as above
    for (int k = MSG_END;   k < MSG_CHR_W; k++ )  message[k] = 8'd0;
  end
  always_comb for (int i = 0; i < MSG_CHR_W; i++) message_flat[(i+1)*8-1-:8] = message[i];
endmodule