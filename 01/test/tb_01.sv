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

    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_01.txt");
    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
    send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/input_01.txt");
    //send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_02.txt");
    @(cb);
    cb.reset <= '1;
    @(cb);
    cb.reset <= '0;
    // send_twists("/Users/connorcoale/Documents/projects/aoc_2025/01/input/example_03.txt");
    @(cb);
    $finish;
  end
endmodule