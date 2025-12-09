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
  input  wire uart_rxd, // UART Recieve pin.
  output wire uart_txd  // UART transmit pin.
);
  // Clock frequency in hertz.
  parameter CLK_HZ       = 100000000;
  parameter BIT_RATE     = 115200;
  parameter PAYLOAD_BITS = 8;

  wire [PAYLOAD_BITS-1:0] uart_rx_data;
  wire                    uart_rx_valid;
  wire                    uart_rx_break;

  wire                    uart_tx_busy;
  wire [PAYLOAD_BITS-1:0] uart_tx_data;
  wire                    uart_tx_en;

  // UART RX
  uart_rx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ  (CLK_HZ  )
  ) i_uart_rx(
    .clk          (clk          ), // Top level system clock input.
    .resetn       (resetn       ), // Asynchronous active low reset.
    .uart_rxd     (uart_rxd     ), // UART Recieve pin.
    .uart_rx_en   (1'b1         ), // Recieve enable
    .uart_rx_break(uart_rx_break), // Did we get a BREAK message?
    .uart_rx_valid(uart_rx_valid), // Valid data recieved and available.
    .uart_rx_data (uart_rx_data )  // The recieved data.
  );

  top_01 inst_top_01 (
    .clk(clk),
    .reset(reset),
    .cs(cs),
    .data(uart_rx_data),
    .data_valid(uart_rx_valid)
    // .solution(solution),
    // .solution_valid(solution_valid)
  );

  // // UART Transmitter module.
  // uart_tx #(
    // .BIT_RATE(BIT_RATE),
    // .PAYLOAD_BITS(PAYLOAD_BITS),
    // .CLK_HZ  (CLK_HZ  )
  // ) i_uart_tx(
    // .clk          (clk          ),
    // .resetn       (resetn       ),
    // .uart_txd     (uart_txd     ),
    // .uart_tx_en   (uart_tx_en   ),
    // .uart_tx_busy (uart_tx_busy ),
    // .uart_tx_data (uart_tx_data ) 
  // );





endmodule