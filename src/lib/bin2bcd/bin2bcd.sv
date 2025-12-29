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
 *  Convert the given 32 binary to bcd
*/

module bin2bcd (
  input clock,
  input resetn,
  input convert,
  input [31:0] data,
  output reg [3:0] bcd [10], // 10 digits max in 32 bit integer
  output reg done
); 

  logic [5:0] cnt, cnt_next;
  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) cnt <= '0;
    else         cnt <= cnt_next;
  end

  logic [31:0] data_r, data_next;
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
        if (cnt == 31) state_next = DONE;
      end
      DONE: begin
        if (!convert) state_next = IDLE;
        done = 1'b1;
      end
    endcase
  end

  logic [3:0] nibbles [10];
  logic [3:0] nibbles_shifted [10];
  logic [3:0] nibbles_add3 [10];
  logic [3:0] nibbles_next [10];
  task automatic set_nibbles_next_0;
    for (int i = 0; i < 10; i++) begin
      nibbles_next[i] = '0;
    end
  endtask

  always_comb begin
    set_nibbles_next_0();
    if (state_r == BUSY) begin
      for (int i = 0; i < 10; i++) begin
        // Make shifted version of all nibbles
        if (i == 0) begin
          nibbles_shifted[i] = {nibbles[i][2:0], data_r[31]};
        end
        else begin
          nibbles_shifted[i] = {nibbles[i][2:0], nibbles[i-1][3]};
        end
      end
      for (int j = 0; j < 10; j++) begin
        // Add 3 to any nibble which is over 4
        nibbles_add3[j] = (nibbles_shifted[j] > 'd4 && cnt != 'd31) ? nibbles_shifted[j] + 'd3 : nibbles_shifted[j];
      end
      nibbles_next = nibbles_add3;
    end else if (state_r == DONE) begin
      nibbles_next = nibbles;
    end
  end
  always_ff @(posedge clock) begin
    nibbles <= nibbles_next;
  end

  genvar i;
  for (i = 0; i < 10; i++) assign bcd[i] = nibbles[i];

endmodule