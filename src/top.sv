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
  input        clk,     // Top level system clock input.
  input        resetn,
  input        print_input_n,
  input [3:0]  sw, // sw[0] = load data
  input  wire uart_rxd, // UART Recieve pin.
  output wire uart_txd  // UART transmit pin.
);
  // Clock frequency in hertz.
  parameter CLK_HZ        = 100000000;
  parameter BIT_RATE      = 115200;
  parameter PAYLOAD_BITS  = 8;
  parameter BRAM_TOT_SIZE = 204_800; // bytes
  parameter BRAM_ADDR_W   = $clog2(BRAM_TOT_SIZE);
  parameter ADVENT_N      = 12;

  wire [PAYLOAD_BITS-1:0] uart_rx_data;
  wire                    uart_rx_valid;
  wire                    uart_rx_break;
  wire                    uart_rx_en;

  assign uart_rx_en = 1'b1;

  wire                    uart_tx_busy;
  wire [PAYLOAD_BITS-1:0] uart_tx_data;
  wire                    uart_tx_en;

  wire print_input;
  assign print_input = !print_input_n;

  // Set up a small reg file pointing to the day mem base addresses
  logic [BRAM_ADDR_W-1:0]      day_mem_addr[ADVENT_N];
  logic [BRAM_ADDR_W-1:0]      day_mem_addr_next[ADVENT_N];
  logic [$clog2(ADVENT_N)-1:0] day_mem_ptr, day_mem_ptr_next;
  genvar i;
  for (i = 0; i < ADVENT_N; i++) begin
    always_ff @(posedge clk or negedge resetn) begin
      if (!resetn) day_mem_addr[i] <= '0;
      else day_mem_addr[i] <= day_mem_addr_next[i];
    end
  end

  task automatic set_default_day_mem();
    for (int i = 0; i <= ADVENT_N; i++) begin
      day_mem_addr_next[i] = day_mem_addr[i];
    end
  endtask

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) day_mem_ptr <= '0;
    else         day_mem_ptr <= day_mem_ptr_next;
  end

  // UART RX
  uart_rx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ  (CLK_HZ  )
  ) i_uart_rx(
    .clk          (clk          ), // Top level system clock input.
    .resetn       (resetn       ), // Asynchronous active low reset.
    .uart_rxd     (uart_rxd     ), // UART Recieve pin.
    .uart_rx_en   (uart_rx_en   ), // Recieve enable
    .uart_rx_break(uart_rx_break), // Did we get a BREAK message?
    .uart_rx_valid(uart_rx_valid), // Valid data recieved and available.
    .uart_rx_data (uart_rx_data )  // The recieved data.
  );

  part_01 inst_part_01 (
    .clk(clk),
    .reset(reset),
    .cs(cs),
    .data(uart_rx_data),
    .data_valid(uart_rx_valid)
    // .solution(solution),
    // .solution_valid(solution_valid)
  );

  // UART Transmitter module.
  uart_tx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ  (CLK_HZ  )
  ) i_uart_tx(
    .clk          (clk          ),
    .resetn       (resetn       ),
    .uart_txd     (uart_txd     ),
    .uart_tx_en   (uart_tx_en   ),
    .uart_tx_busy (uart_tx_busy ),
    .uart_tx_data (uart_tx_data ) 
  );

  logic wr_en, rd_en;
  logic [7:0] wr_data, rd_data;
  logic [BRAM_ADDR_W-1:0] wr_addr, wr_addr_next, rd_addr, rd_addr_next;
  mem_wrapper mem (
    .clk(clk),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .wr_addr(wr_addr),
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
  );

  typedef enum {
    IDLE,
    LOAD,
    READ_MEM
    // SOLVE,
    // OUTPUT_DATA,
    // WAIT_SEND_CHAR,
    // OUTPUT_SOL
  } e_state;
  e_state state_r, state_next;

  always_ff @(posedge clk) wr_addr     <= wr_addr_next;
  always_ff @(posedge clk) rd_addr     <= rd_addr_next;
  always_ff @(posedge clk) state_r     <= state_next;



  always_comb begin
    state_next       = state_r;
    wr_en            = uart_rx_valid && sw[0];
    wr_addr_next     = wr_addr;
    wr_data          = uart_rx_data;
    rd_en            = 1'b0;
    day_mem_ptr_next = day_mem_ptr;
    set_default_day_mem();
    case (state_r) 
      IDLE: begin
        wr_addr_next = '0;
        if (wr_en) begin 
          state_next = LOAD;
          wr_addr_next = wr_addr + wr_en;
        end
        else if (print_input) begin
          state_next = READ_MEM;
          rd_addr_next = rd_addr + 1'b1;
          rd_en = 1'b1;
        end
      end
      LOAD: begin
        if (wr_en) begin
          wr_addr_next = wr_addr + wr_en;
          if (wr_data == 8'h03) begin
            day_mem_addr_next[day_mem_ptr] = wr_addr;
            day_mem_ptr_next = day_mem_ptr + 1;
          end
          else if (wr_data == 8'h04) state_next = IDLE;
        end
      end
      READ_MEM: begin
        rd_en = 1'b1;
        state_next = (rd_data == 8'h04) ? IDLE : READ_MEM;
        rd_addr_next = rd_addr + 1'b1;
      end

    endcase
  end

  // logic [$clog2(128)-1:0] char_cnt_r, char_cnt_next;
  // logic [7:0] char_r, char_next;
  // logic load_char;

  // always_comb begin
    // state_next = state_r;
    // char_next  = char_r;
    // char_cnt_nxt = char_cnt_r;
    // load_char = 0;
    // send_char = 0;

    // case (state_r) 
    // IDLE: begin
      // if (uart_rx_valid) begin
        // char_cnt_nxt = '0;
        // char_next = uart_rx_data;
        // state_next = LOAD;
      // end
      // else if (print_input) begin
        // char_cnt_nxt = '0;
        // state_next = OUTPUT_DATA;
      // end
    // end
    // LOAD: begin
      // char_cnt_nxt = char_cnt_nxt + 1;
      // char_nxt = uart_rx_data;
      // load_char = 1;
      // state_next = WAIT_RCV_CHAR;
    // end
    // WAIT_RCV_CHAR: begin
      // if (uart_rx_valid) begin
        // char_next = uart_rx_data;
        // state_next = (uart_rx_data == 'h04) ? IDLE : LOAD;
      // end
    // end
    // SOLVE: begin
      
    // end
    // OUTPUT_DATA: begin
      // char_cnt_nxt = '0;
      // send_char = 1;
    // end
    // WAIT_SEND_CHAR: begin

    // end
    // OUTPUT_SOL: begin

    // end
    // default: begin

    // end
    // endcase
  // end
endmodule