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

`ifndef PART_NUM
  `error "PART_NUM not defined. Use -DPART_NUM=XX"
`endif
`define STR1(x) `"x`"
`define STR(x) `STR1(x)

module tb_n ();
  logic clock;
  logic reset;
  logic cs;
  logic [7:0] data;
  logic data_valid;
  logic [47:0] solution_a, solution_b;
  logic solution_valid;

  initial begin
    $dumpfile($sformatf("sim/trace/trace_part_%s.vcd", `STR(`PART_NUM)));
    $dumpvars();
  end

  part_`PART_NUM dut (
    .clock         (clock),
    .reset         (reset),
    .cs            (cs),
    .data          (data),
    .data_valid    (data_valid),
    .solution_a    (solution_a),
    .solution_b    (solution_b),
    .solution_valid(solution_valid)
  );

  initial begin
    clock = 1'b0;
    forever begin
      #1 clock = !clock;
    end
  end

  clocking cb @(posedge clock);
      output #0 reset, cs, data, data_valid;
  endclocking

  task reset_dut;
    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
  endtask

  task present_data;
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
    cb.cs <= 1'b1;
    cb.data_valid <= '1;
    cb.data <= 'h03;
    @(cb);
    cb.data_valid <= '0;
    cb.cs <= 1'b0;
    $fclose(fd);
  endtask

  initial begin
    reset_dut();
    fork
      begin : stimulus
        present_data($sformatf("sim/stimulus/%s/input_%s.txt", `STR(`PART_NUM), `STR(`PART_NUM)));
        forever @(cb);
      end
      begin : wait_end
        @(solution_valid);
        repeat(10) @(cb);
      end
      begin : timeout
        #100ms;
      end
    join_any
    $finish;
  end
endmodule