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

module solution2char (
  input            clock,
  input            resetn,
  input [31:0]     solution_a,
  input [31:0]     solution_b,
  input [3:0]      day,
  input            convert,
  input            done_tx,
  output reg [7:0] message [32],
  output reg       done
);

  logic [3:0] bcd_a [10];
  logic [3:0] bcd_b [10];
  bin2bcd bin2bcd_a (
    .clock(clock),
    .resetn(resetn),
    .convert(converting),
    .data(solution_a),
    .bcd(bcd_a),
    .done(done_a)
  );

  bin2bcd bin2bcd_b (
    .clock(clock),
    .resetn(resetn),
    .convert(converting),
    .data(solution_b),
    .bcd(bcd_b),
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
  // "XX: aaaaaaaaaa,bbbbbbbbbb" where XX = day, aaa... = soln a, bbb... = soln b
  assign message[0]  = 8'(day > 9) + 8'd48; // 0 or 1 for first char of the day number
  assign message[1]  = 8'((day > 9) ? day - 10 : day) + 8'd48; // the second char of the day number
  assign message[2]  = 8'h3A; // ":" ascii char
  assign message[3]  = 8'h20; // " " ascii char
  assign message[14] = 8'h2c; // "," ascii char
  always_comb begin
    // Need to flip the ordering for printing in a string, hence 9-i
    for (int i = 0; i < 10; i++) message[i + 04] = bcd_a[9-i] + 8'd48;
    for (int j = 0; j < 10; j++) message[j + 15] = bcd_b[9-j] + 8'd48; // same as above
  end
endmodule