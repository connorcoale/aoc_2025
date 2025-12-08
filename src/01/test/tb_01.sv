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

module tb_01 ();
  logic clk;
  logic reset;
  logic [7:0] data;
  logic data_valid;
  logic [7:0] solution;
  logic solution_valid;

  initial begin
    $dumpfile("trace.vcd");
    $dumpvars();
  end

  top_01 dut (
    .clk(clk),
    .reset(reset),
    .data(data),
    .data_valid(data_valid),
    .solution(solution),
    .solution_valid(solution_valid)
  );
  initial begin
    clk = 1'b0;
    forever begin
      #1 clk = !clk;
    end
  end

  clocking cb @(posedge clk);
      output #0 reset, data_valid, data;
  endclocking

  task reset_dut;
    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
  endtask

  task send_twists;
    input string file_name;

    int fd;
    string line;

    fd = $fopen (file_name, "r");
    while (!$feof(fd)) begin
      $fgets(line, fd);
      for (int i = 0; i < line.len(); i ++) begin
        @(cb);
        cb.data_valid <= '1;
        cb.data <= line.getc(i);
      end
    end
    @(cb);
    cb.data_valid <= '0;

    $fclose(fd);
  endtask

  initial begin
    cb.reset <= 1'b0;
    cb.data <= '0;
    cb.data_valid <= 1'b0;

    // reset_dut();
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_01.txt");
    // reset_dut();
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_02.txt");
    // reset_dut();
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_03.txt");
    // reset_dut();
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_04.txt");
    reset_dut();
    send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/input_01.txt");
    @(cb);
    $finish;
  end
endmodule