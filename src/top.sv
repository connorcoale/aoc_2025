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
 *  top.sv
 *  Top module for solving Advent of Code 2025
*/

module top (
  input        clock,
  input        resetn,
  input        print_input_n, // Simulation input to read all the memories
  input        solve_day_n,   // Button to press to solve the puzzle indicated by switches
  input        print_soln_n,
  input [3:0]  sw,            // Switches to select puzzle
  input  wire  uart_rxd,      // UART Recieve pin.
  output wire  uart_txd       // UART transmit pin.
);
  // Clock frequency in hertz.
  parameter CLK_HZ        = 100000000;
  parameter BIT_RATE      = 115200;
  parameter PAYLOAD_BITS  = 8;
  parameter BRAM_TOT_SIZE = 204_800; // bytes
  parameter BRAM_ADDR_W   = $clog2(BRAM_TOT_SIZE);
  parameter ADVENT_N      = 12;

  // UART signals
  wire [PAYLOAD_BITS-1:0] uart_rx_data;
  wire                    uart_rx_valid;
  wire                    uart_rx_break;
  wire                    uart_rx_en;

  assign uart_rx_en = 1'b1;

  wire                     uart_tx_busy;
  logic [PAYLOAD_BITS-1:0] uart_tx_data;
  logic                    uart_tx_en;

  // Input signals
  wire print_input = !print_input_n;
  wire solve_day   = !solve_day_n   &&  4'd1 <= sw && sw <= ADVENT_N;
  wire print_soln  = !print_soln_n  &&  4'd1 <= sw && sw <= ADVENT_N;

  // UART Receiver module
  uart_rx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ  (CLK_HZ  )
  ) i_uart_rx(
    .clock          (clock          ), // Top level system clock input.
    .resetn       (resetn       ), // Asynchronous active low reset.
    .uart_rxd     (uart_rxd     ), // UART Recieve pin.
    .uart_rx_en   (uart_rx_en   ), // Recieve enable
    .uart_rx_break(uart_rx_break), // Did we get a BREAK message?
    .uart_rx_valid(uart_rx_valid), // Valid data recieved and available.
    .uart_rx_data (uart_rx_data )  // The recieved data.
  );

  // UART Transmitter module
  uart_tx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ  (CLK_HZ  )
  ) i_uart_tx(
    .clock        (clock        ),
    .resetn       (resetn       ),
    .uart_txd     (uart_txd     ),
    .uart_tx_en   (uart_tx_en   ),
    .uart_tx_busy (uart_tx_busy ),
    .uart_tx_data (uart_tx_data ) 
  );

  logic wr_en, rd_en;
  logic [7:0] wr_data, rd_data;
  logic [BRAM_ADDR_W-1:0] wr_addr, wr_addr_next, rd_addr, rd_addr_next;
  mem_arty_full mem (
    .clock(clock),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .wr_addr(wr_addr),
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
  );
  
  logic [ADVENT_N-1:0] cs, solution_valid;
  wire [7:0] data = rd_data;
  logic data_valid;

  wire [48-1:0] solutions[12][2];
  part_01 inst_part_01 (
    .clock(clock),
    .reset(reset),
    .cs(cs[1-1]),
    .data(data),
    .data_valid(data_valid),
    .solution_a(solutions[0][0]),
    .solution_b(solutions[0][1]),
    .solution_valid(solution_valid[1-1])
  );

  part_02 inst_part_02 (
    .clock(clock),
    .reset(reset),
    .cs(cs[2-1]),
    .data(data),
    .data_valid(data_valid),
    .solution_a(solutions[1][0]),
    .solution_b(solutions[1][1]),
    .solution_valid(solution_valid[2-1])
  );


  wire [48-1:0] solution_a = solutions[sw - 1][0];
  wire [48-1:0] solution_b = solutions[sw - 1][1];
  logic convert;
  logic done_tx;
  logic [8*32-1:0] message_flat;
  logic [7:0] message [32];
  always_comb begin
    for (int i = 0; i < 32; i++) message[i] = message_flat[(i+1)*8-1-:8];
  end
  logic done_converting;
  solution2char inst_solution2char (
    .clock(clock),
    .resetn(resetn),
    .solution_a(solution_a),
    .solution_b(solution_b),
    .day(sw),
    .convert(convert),
    .done_tx(done_tx),
    .message_flat(message_flat),
    .done(done_converting)
  );


  // Set up a small reg file pointing to the day mem base addresses
  logic [BRAM_ADDR_W-1:0]      day_mem_addr[ADVENT_N];
  logic [BRAM_ADDR_W-1:0]      day_mem_addr_next[ADVENT_N];
  logic [$clog2(ADVENT_N)-1:0] day_mem_ptr, day_mem_ptr_next;
  genvar i;
  for (i = 1; i < ADVENT_N; i++) begin
    always_ff @(posedge clock or negedge resetn) begin
      if (!resetn) day_mem_addr[i] <= '0;
      else day_mem_addr[i] <= day_mem_addr_next[i];
    end
  end
  assign day_mem_addr[0] = '0;

  task automatic set_default_day_mem();
    for (int i = 0; i <= ADVENT_N; i++) begin
      day_mem_addr_next[i] = day_mem_addr[i];
    end
  endtask

  always_ff @(posedge clock or negedge resetn) begin
    if (!resetn) day_mem_ptr <= '1;
    else         day_mem_ptr <= day_mem_ptr_next;
  end

  typedef enum {
    IDLE,
    LOAD,
    READ_MEM,
    SOLVE,
    CONVERT_SOLN,
    TX_CHAR,
    WAIT_TX
    // SOLVE,
    // OUTPUT_DATA,
    // WAIT_SEND_CHAR,
    // OUTPUT_SOL
  } e_state;
  e_state state_r, state_next;

  logic [4:0] msg_char, msg_char_next;
  always_ff @(posedge clock) wr_addr    <= wr_addr_next;
  always_ff @(posedge clock) rd_addr    <= rd_addr_next;
  always_ff @(posedge clock) state_r    <= state_next;
  always_ff @(posedge clock) msg_char   <= msg_char_next;
  always_ff @(posedge clock) data_valid <= rd_en;

  wire start_transmission_rx = uart_rx_valid && uart_rx_data == 8'h02; // STX ascii character
  always_comb begin
    state_next       = state_r;
    wr_en            = uart_rx_valid && !start_transmission_rx; // don't save the STX char
    wr_addr_next     = wr_addr;
    wr_data          = uart_rx_data;
    rd_en            = 1'b0;
    rd_addr_next     = rd_addr;
    day_mem_ptr_next = day_mem_ptr;
    set_default_day_mem();
    convert          = 1'b0;
    msg_char_next    = '0;
    uart_tx_data     = '0;
    uart_tx_en       = 1'b0;
    cs               = '0;
    done_tx          = 1'b0;
    case (state_r) 
      IDLE: begin
        wr_addr_next = '0;
        if (start_transmission_rx) begin
          day_mem_ptr_next = 'd1; 
          state_next = LOAD;
        end
        else if (print_input) begin
          rd_addr_next = '0;
          state_next   = READ_MEM;
        end
        else if (solve_day) begin
          rd_addr_next = day_mem_addr[sw - 1];
          cs[sw-1]     = 1'b1;
          state_next   = SOLVE;
        end
        else if (print_soln) begin
          if (1 <= sw && sw <= 12) begin
            state_next = CONVERT_SOLN;
          end
        end
      end
      LOAD: begin
        if (wr_en) begin
          wr_addr_next = wr_addr + wr_en;
          if (wr_data == 8'h03) begin
            day_mem_ptr_next = day_mem_ptr + 1;
            day_mem_addr_next[day_mem_ptr] = wr_addr + 1;
          end
          else if (wr_data == 8'h04) state_next = IDLE;
        end
      end
      READ_MEM: begin
        rd_en        = 1'b1;
        rd_addr_next = rd_addr + 1'b1;
        state_next   = (rd_data == 8'h04) ? IDLE : READ_MEM;
      end
      SOLVE: begin
        rd_en        = rd_addr == day_mem_addr[sw-1] || rd_data != 8'h03;
        rd_addr_next = rd_addr + rd_en;
        cs[sw-1]     = 1'b1;
        state_next   = solution_valid[sw-1] ? IDLE : SOLVE;
      end
      CONVERT_SOLN: begin
        convert = 1'b1;
        if (done_converting) state_next = TX_CHAR;
      end
      TX_CHAR: begin
        uart_tx_data = message[msg_char];
        uart_tx_en = 1'b1;
        msg_char_next = msg_char + 1;
        state_next = WAIT_TX;
      end
      WAIT_TX: begin
        // convert = 1'b1;
        uart_tx_data = message[msg_char];
        uart_tx_en = 1'b1;
        msg_char_next = msg_char;
        if (!uart_tx_busy) begin
          if (msg_char < 'd31) state_next = TX_CHAR;
          else begin
            state_next = IDLE;
            done_tx = 1'b1;
          end
        end else state_next = WAIT_TX;
      end
    endcase
  end
endmodule