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

module tb_02 ();
  logic clk;
  logic reset;
  logic cs;
  logic [7:0] data;
  logic data_valid;
  logic [31:0] solution_a, solution_b;
  logic solution_valid;

  initial begin
    $dumpfile("sim/trace/trace_part_02.vcd");
    $dumpvars();
  end

  part_02 dut (
    .clock(clk),
    .reset(reset),
    .cs(cs),
    .data(data),
    .data_valid(data_valid),
    .solution_a(solution_a),
    .solution_b(solution_b),
    .solution_valid(solution_valid)
  );
  initial begin
    clk = 1'b0;
    forever begin
      #1 clk = !clk;
    end
  end

  clocking cb @(posedge clk);
      output #0 reset, data_valid, data, cs;
  endclocking

  task reset_dut;
    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
  endtask

  task send_file;
    input string file_name;

    int fd;
    string line;

    fd = $fopen (file_name, "r");
    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      foreach (line[i]) begin
        @(cb);
        cb.cs <= 1'b1;
        cb.data_valid <= '1;
        cb.data <= line[i];
      end
    end
    @(cb);
    cb.data_valid <= '0;
    cb.cs <= 1'b0;
    $fclose(fd);
  endtask

  initial begin
    cb.reset <= 1'b0;
    cb.data <= '0;
    cb.data_valid <= 1'b0;
    cb.cs <= 1'b0;
    reset_dut();
    // send_file("sim/stimulus/02/example_01.txt");
    // repeat (5000) @(cb);
    // send_file("sim/stimulus/02/example_02.txt");
    // repeat (10000) @(cb);
    // send_file("sim/stimulus/02/example_03.txt");
    // repeat (10000) @(cb);
    send_file("sim/stimulus/02/input_02.txt");
    repeat (2500000) @(cb);
    $finish;
  end
endmodule