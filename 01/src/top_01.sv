// top.sv
module top_01 (
  input clk,
  input reset,
  input cs,
  input [7:0] data,
  input data_valid,
  output [7:0] solution,
  output solution_valid
);

  part_a_01 a (
    .clk(clk),
    .reset(reset),
    .data(data),
    .data_valid(data_valid),
    .solution(solution),
    .solution_valid(solution_valid)
  );


endmodule

module part_a_01 (
  input clk,
  input reset,
  input [7:0] data,
  input data_valid,
  output [7:0] solution,
  output solution_valid
);

  localparam MAX_TWIST = 999;
  localparam MAX_TWIST_W = $clog2(MAX_TWIST);
  localparam MAX_DIAL = 99;
  localparam MAX_DIAL_W = $clog2(MAX_DIAL);
  localparam MAX_TWISTED_DIAL = MAX_TWIST + MAX_DIAL;
  localparam MAX_TWISTED_DIAL_W = $clog2(MAX_TWISTED_DIAL) + 1;

  typedef enum {
    IDLE,
    TWIST
  } e_state;


  e_state state_r, state_next;
  logic signed [MAX_TWISTED_DIAL_W-1:0] twist_r, twist_next;
  logic unsigned [MAX_TWISTED_DIAL_W-1:0] dial_r;
  logic signed [MAX_TWISTED_DIAL_W-1:0] dial_next, dial_next_pre_modulus;
  logic cw_r, cw_next;

  always_comb begin
    state_next = state_r;
    twist_next = twist_r;
    dial_next = dial_r;
    dial_next_pre_modulus = dial_r;
    cw_next = cw_r;
    case (state_r)
      IDLE : begin
        if (data_valid) begin
          if (data == 8'h52) begin
            // R
            state_next = TWIST;
            cw_next = 1'b1;
          end
          if (data == 8'h4C) begin
            // L
             state_next = TWIST;
             cw_next = 1'b0;
          end
          twist_next = '0;
          dial_next = 'd50;
        end
      end
      TWIST : begin
        if (8'h30 <= data && data <= 8'h39) begin
          // state stays the same
          twist_next = (twist_r * 10) + data - 8'h30;
        end else begin
          if (data == 8'h0A) begin
            // newline
            dial_next_pre_modulus = cw_r ? ({1'b0, dial_r} + twist_r) : ({1'b0, dial_r} - twist_r);
            dial_next =  (dial_next_pre_modulus % 100 + 100) % 100;
          end else if (data == 8'h52) begin
            cw_next = 1'b1;
            twist_next = '0;
          end else if (data == 8'h4C) begin
            cw_next = 1'b0;
            twist_next = '0;
          end
        end
      end
    endcase
    if (state_r == TWIST && !data_valid) begin
      state_next = IDLE;
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state_r <= IDLE; 
      twist_r <= '0;
      dial_r <= '0;
      cw_r <= 1'b0;
    end
    else begin
      state_r <= state_next;
      twist_r <= twist_next;
      dial_r <= dial_next;
      cw_r <= cw_next;
    end
  end

  //    delayed     first cycle of valid?  first cycle after valid deasserted
  logic data_valid_r, data_valid_assert, data_valid_deassert;
  always_ff @(posedge clk) data_valid_r <= data_valid;
  assign data_valid_assert = data_valid && !data_valid_r;

  logic twist_end = data_valid && (data == 8'h0A);
  logic inc = twist_end && (dial_next == '0);
  logic [15:0] zeros_r, zeros_next;
  assign zeros_next = zeros_r + inc;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) zeros_r <= '0;
    else zeros_r <= zeros_next;
  end


endmodule