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
 *  bin2bcd.sv
 *  Convert the given binary to bcd
*/

module bin2bcd #(
  parameter longint unsigned MAX_INT = 64'd999_999_999_999,
  localparam int unsigned BITS_W     = $clog2(MAX_INT + 1),
  localparam int unsigned DIG_W      = $rtoi($log10(MAX_INT)) + 1
) (
  input                clock,
  input                resetn,
  input                convert,
  input                hold,
  input [BITS_W-1:0]   data,
  output [4*DIG_W-1:0] bcd_flat,
  output reg done
); 

  logic [$clog2(BITS_W)-1:0] cnt, cnt_next;
  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) cnt <= '0;
    else         cnt <= cnt_next;
  end

  logic [BITS_W-1:0] data_r, data_next;
  always_ff @(posedge clock) data_r <= data_next;
  
  typedef enum {
    IDLE,
    BUSY,
    DONE
  } e_state;
  e_state state_r, state_next;

  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) state_r <= IDLE;
    else         state_r <= state_next;
  end
  always_comb begin
    state_next = state_r;
    cnt_next   = '0;
    data_next  = data_r;
    done       = 1'b0;
    case (state_r)
      IDLE: begin
        if (convert) begin
          state_next = BUSY; 
          data_next = data;
        end
      end
      BUSY: begin
        cnt_next = cnt + 1'b1;
        data_next = data_r << 1;
        if (cnt == BITS_W - 1) state_next = DONE;
      end
      DONE: begin
        if (!(convert || hold)) state_next = IDLE;
        done = 1'b1;
      end
    endcase
  end


  logic [4*DIG_W-1:0] nibbles_flat;
  logic [4*DIG_W-1:0] nibbles_shifted_flat;
  logic [4*DIG_W-1:0] nibbles_add3_flat;
  logic [4*DIG_W-1:0] nibbles_next_flat;

  always_comb begin
    // set_nibbles_next_0();
    nibbles_next_flat = '0;
    nibbles_shifted_flat = '0;
    nibbles_add3_flat = '0;
    if (state_r == BUSY) begin
      nibbles_shifted_flat = {nibbles_flat[4*DIG_W-2:0], data_r[BITS_W-1]};
      for (int j = 0; j < 4*DIG_W; j = j + 4) begin
        // Add 3 to any nibble which is over 4
        nibbles_add3_flat[j+3-:4] = (nibbles_shifted_flat[j+3-:4] > 'd4 && cnt != BITS_W-1) ? nibbles_shifted_flat[j+3-:4] + 'd3 : nibbles_shifted_flat[j+3-:4];
      end
      nibbles_next_flat = nibbles_add3_flat;
    end else if (state_r == DONE) begin
      nibbles_next_flat = nibbles_flat;
    end
  end
  always_ff @(posedge clock) begin
    nibbles_flat <= nibbles_next_flat;
  end
  assign bcd_flat = nibbles_flat;
endmodule