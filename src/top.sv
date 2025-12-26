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
  input        clk,
  input        resetn,
  input        print_input_n, // Simulation input to read all the memories
  input        solve_day_n,   // Button to press to solve the puzzle indicated by switches
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

  wire                    uart_tx_busy;
  wire [PAYLOAD_BITS-1:0] uart_tx_data;
  wire                    uart_tx_en;

  // Input signals
  wire print_input = !print_input_n;
  wire solve_day   = !solve_day_n;

  // UART Receiver module
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

  // UART Transmitter module
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
  mem_arty_205kb mem (
    .clk(clk),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .wr_addr(wr_addr),
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
  );
  
  logic cs01, cs02, cs03, cs04, cs05, cs06, cs07, cs08, cs09, cs10, cs11, cs12;
  wire [7:0] data = rd_data;
  logic data_valid;

  part_01 inst_part_01 (
    .clk(clk),
    .reset(reset),
    .cs(cs01),
    .data(data),
    .data_valid(data_valid),
    .solution_a(solution_a),
    .solution_b(solution_b),
    .solution_valid(solution_valid)
  );

  // Set up a small reg file pointing to the day mem base addresses
  logic [BRAM_ADDR_W-1:0]      day_mem_addr[ADVENT_N];
  logic [BRAM_ADDR_W-1:0]      day_mem_addr_next[ADVENT_N];
  logic [$clog2(ADVENT_N)-1:0] day_mem_ptr, day_mem_ptr_next;
  genvar i;
  for (i = 1; i < ADVENT_N; i++) begin
    always_ff @(posedge clk or negedge resetn) begin
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

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) day_mem_ptr <= '1;
    else         day_mem_ptr <= day_mem_ptr_next;
  end

  typedef enum {
    IDLE,
    LOAD,
    READ_MEM,
    SOLVE_01,
    TX
    // SOLVE,
    // OUTPUT_DATA,
    // WAIT_SEND_CHAR,
    // OUTPUT_SOL
  } e_state;
  e_state state_r, state_next;

  always_ff @(posedge clk) wr_addr <= wr_addr_next;
  always_ff @(posedge clk) rd_addr <= rd_addr_next;
  always_ff @(posedge clk) state_r <= state_next;



  wire start_transmission_rx = uart_rx_valid && uart_rx_data == 8'h02; // STX ascii character
  always_comb begin
    state_next       = state_r;
    wr_en            = uart_rx_valid && !start_transmission_rx; // don't save the STX char
    wr_addr_next     = wr_addr;
    wr_data          = uart_rx_data;
    rd_en            = 1'b0;
    day_mem_ptr_next = day_mem_ptr;
    cs01             = 1'b0;
    data_valid       = 1'b0;
    set_default_day_mem();
    case (state_r) 
      IDLE: begin
        wr_addr_next = '0;
        if (start_transmission_rx) state_next = LOAD;
        else if (print_input) begin
          rd_addr_next = '0;
          state_next   = READ_MEM;
        end
        else if (sw == 4'd1 && solve_day) begin
          rd_addr_next = day_mem_addr[0];
          state_next   = SOLVE_01;
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
        rd_en        = 1'b1;
        rd_addr_next = rd_addr + 1'b1;

        state_next   = (rd_data == 8'h04) ? IDLE : READ_MEM;
      end
      SOLVE_01: begin
        rd_en        = (rd_data != 8'h03);
        rd_addr_next = rd_addr + 1'b1;

        data_valid   = 1'b1;
        cs01         = 1'b1;

        state_next   = (rd_data != 8'h03) ? SOLVE_01 : IDLE;        
      end
      TX: begin

      end
    endcase
  end
endmodule