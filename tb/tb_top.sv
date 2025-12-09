// Attribution: This IP is licensed freely under the MIT license by Ben Marshall
// Link to source repo: https://github.com/ben-marshall/uart/tree/master

// 
// Module: tb
// 
// Notes:
// - Top level simulation testbench.
// - Modified by Connor Coale

`timescale 1ns/1ns

module tb_top;

    // ---------------------------------------------
    // Clock & UART Inputs
    // ---------------------------------------------
    reg clk;
    reg resetn;
    reg uart_rxd;

    // ---------------------------------------------
    // Clock parameters
    // ---------------------------------------------
    localparam CLK_MHZ  = 100; // arty a7 has 100MHz clock
    // localparam CLK_HZ   = CLK_MHZ * 1_000_000;
    localparam CLK_HZ      = 2_500_000; // let's scale it down 50x to make the sim run faster
    localparam CLK_P    = 1_000_000_000 / CLK_HZ;   // ns per cycle

    // UART bitrate
    localparam BIT_RATE     = 115200;
    localparam CLK_PER_BAUD = CLK_HZ / BIT_RATE;

    // ---------------------------------------------
    // Dumpfile
    // ---------------------------------------------
    initial begin
        $dumpfile("./trace.vcd");
        $dumpvars(1, tb_top);
    end

    // ---------------------------------------------
    // Clock generation
    // ---------------------------------------------
    initial clk = 1'b0;
    always #(CLK_P/2) clk = ~clk;

    // ---------------------------------------------
    // Baud tick generator (1-cycle tick)
    // ---------------------------------------------
    int cnt;
    reg baud;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnt  <= 0;
            baud <= 0;
        end else begin
            if (cnt == (CLK_PER_BAUD - 1)) begin
                cnt  <= 0;
                baud <= 1;
            end else begin
                cnt  <= cnt + 1;
                baud <= 0;
            end
        end
    end

    // ---------------------------------------------
    // UART send-byte task
    // ---------------------------------------------
    task send_byte(input byte b);
        int i;
        begin
            // start bit
            @(posedge baud);
            uart_rxd = 1'b0;

            // 8 data bits
            for (i = 0; i < 8; i++) begin
                @(posedge baud);
                uart_rxd = b[i];
            end

            // stop bit
            @(posedge baud);
            uart_rxd = 1'b1;
        end
    endtask

    // ---------------------------------------------
    // Send input file line-by-line as bytes
    // ---------------------------------------------
    task send_input(input string fname);
        int fd;
        string line;

        fd = $fopen(fname, "r");
        if (fd == 0) begin
            $fatal("Failed to open file: %s", fname);
        end

        while (!$feof(fd)) begin
            void'($fgets(line, fd));
            foreach (line[i]) begin
                send_byte(line[i]);
            end
        end

        // Send EOT (Ctrl-D)
        send_byte(8'h04);

        $fclose(fd);
    endtask

    // ---------------------------------------------
    // Test sequence
    // ---------------------------------------------
    initial begin
        uart_rxd = 1'b1;
        resetn   = 1'b0;

        // Let the clock/baud settle
        repeat (10) @(posedge clk);
        resetn = 1'b1;

        // Wait a little before sending data
        repeat (20) @(posedge clk);

        // send_input("../src/01/input/example_01.txt");
        send_input("../src/01/input/input_01.txt");

        $display("Simulation finished at time %t", $time);
        $finish;
    end

    // ---------------------------------------------
    // DUT
    // ---------------------------------------------
    wire uart_txd;

    top #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ  (CLK_HZ)
    ) i_dut (
        .clk      (clk),
        .resetn   (resetn),
        .uart_rxd (uart_rxd),
        .uart_txd (uart_txd)
    );

endmodule






// `timescale 1ns/1ns

// module tb_top;
// reg  clk        ;   // Top level system clock input.
// reg  resetn     ;
// reg  uart_rxd   ;   // UART Recieve pin.

// // Period and frequency of the system clock.
// localparam CLK_MHZ  = 100;
// localparam CLK_HZ   = CLK_MHZ * 1000000;
// // localparam CLK_HZ   = 921600;
// localparam CLK_P    = 1000000000 / CLK_HZ;

// // Bit rate of the UART line we are testing.
// localparam BIT_RATE = 115200;
// localparam CLK_PER_BAUD = CLK_HZ / BIT_RATE;

// initial begin
  // $dumpfile("./trace.vcd");     
  // $dumpvars(0,tb);
// end

// // Make the clock tick.
// initial clk = 0;
// always #(CLK_P/2) clk = ~clk;

// // Make the baud tick.
// int cnt;
// logic baud;
// always_ff @(posedge clk or negedge resetn) begin
  // if (!resetn) begin
    // cnt <= 0;
    // baud <= 0;
  // end else begin
    // if (cnt == (CLK_PER_BAUD) - 1) begin
      // cnt <= 0;
      // baud <= 1;
    // end else begin
      // cnt <= cnt + 1;
      // baud <= 0;
    // end
  // end
// end

// clocking cb @(posedge clk);
  // output #0 resetn, uart_rxd;
// endclocking

// // clocking cbaud @(posedge baud);
  // // output #0 ;
// // endclocking

// logic [7:0] i_to_send;
// // Sends a single byte down the UART line.
// task send_byte;
  // input [7:0] to_send;
  // integer i;
  // i_to_send = to_send;

  // begin
    // // $display("Sending byte: %d, %b at time %d", to_send,to_send, $time);
    // @baud;  cb.uart_rxd <= 1'b0;
    // for(i=0; i < 8; i = i+1) begin
      // @baud; 
      // cb.uart_rxd <= to_send[i];
    // end
    // @baud;  
    // cb.uart_rxd <= 1'b1;
  // end
// endtask

// task send_input;
  // input string file_name;

  // int fd;
  // string line;

  // fd = $fopen (file_name, "r");
  // while (!$feof(fd)) begin
    // $fgets(line, fd);
    // for (int i = 0; i < line.len(); i ++) begin
      // send_byte(line[i]);
    // end
  // end
  // send_byte(8'h04);
  // $fclose(fd);

// endtask

// initial begin
    // cb.resetn  <= 1'b0;
    // cb.uart_rxd <= 1'b1;
    // @(cb);
    // cb.resetn <= 1'b1;

    // send_input("../src/01/input/example_01.txt");
    // // send_input("../src/01/input/input_01.txt");
    
    
    // // send_byte("R");
    // // send_byte("5");
    // // send_byte("0");
    // // send_byte("\n");
    // // send_byte("R");
    // // send_byte("5");
    // // send_byte("0");
    // // send_byte("\n");
    // // send_byte("R");
    // // send_byte("5");
    // // send_byte("0");
    // // send_byte("\n");
    // // send_byte("R");
    // // send_byte("1");
    // // send_byte("0");
    // // send_byte("\n");
    // // send_byte("L");
    // // send_byte("1");
    // // send_byte("1");
    // // send_byte("0");
    // // send_byte("\n");
    // // send_byte(8'h04);

    // $display("Finish simulation at time %d", $time);
    // $finish();
// end

  // //
  // // Instance the top level implementation module.
  // top #(
    // .BIT_RATE(BIT_RATE),
    // .CLK_HZ  (CLK_HZ  )
  // ) i_dut (
    // .clk      (clk     ),   // Top level system clock input.
    // .resetn   (resetn  ),
    // .uart_rxd (uart_rxd),   // UART Recieve pin.
    // .uart_txd (uart_txd)    // UART Transmit pin.
  // );

// endmodule
