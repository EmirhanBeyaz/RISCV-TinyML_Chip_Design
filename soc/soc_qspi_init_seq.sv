module soc_qspi_init_seq #(
    parameter bit ENABLE = 1'b1,
    parameter int TIMEOUT_CYCLES = 1024
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic        cfg_cmd_valid_o,
    output logic [31:0] cfg_cmd_data_o,
    input  logic        cfg_cmd_ready_i,
    input  logic        cfg_rsp_valid_i,
    input  logic [31:0] cfg_rsp_data_i,
    output logic        init_active_o,
    output logic        init_done_o,
    output logic        init_error_o,
    output logic [31:0] last_rsp_data_o,
    output logic [31:0] last_cmd_data_o,
    output logic [31:0] step_index_o,
    output logic [31:0] error_code_o
);

  localparam logic [31:0] CFG_USERMODE  = 32'h0000_1000;
  localparam logic [31:0] CFG_QSPEED    = 32'h0000_0800;
  localparam logic [31:0] CFG_WEDIR     = 32'h0000_0200;
  localparam logic [31:0] CFG_USER_CS_N = 32'h0000_0100;

  localparam logic [31:0] F_RESET       = CFG_USERMODE | 32'h0000_00ff;
  localparam logic [31:0] F_END         = CFG_USERMODE | CFG_USER_CS_N;
  localparam logic [31:0] QUAD_IO_READ  = CFG_USERMODE | 32'h0000_00eb;
  localparam logic [31:0] QUAD_ADDR     = CFG_USERMODE | CFG_QSPEED | CFG_WEDIR;
  localparam logic [31:0] QUAD_MODE     = CFG_USERMODE | CFG_QSPEED | CFG_WEDIR | 32'h0000_00a0;
  localparam logic [31:0] QUAD_DUMMY    = CFG_USERMODE | CFG_QSPEED;
  localparam int unsigned SEQ_LEN       = 16;
  localparam int unsigned IDX_W         = (SEQ_LEN > 1) ? $clog2(SEQ_LEN) : 1;
  localparam int unsigned TIMEOUT_W     = (TIMEOUT_CYCLES > 1) ? $clog2(TIMEOUT_CYCLES + 1) : 1;

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_SEND,
    ST_WAIT_RSP,
    ST_DONE
  } state_e;

  state_e               state_q;
  logic [IDX_W-1:0]     seq_idx_q;
  logic [TIMEOUT_W-1:0] timeout_q;

  function automatic logic [31:0] seq_cmd(input logic [IDX_W-1:0] idx);
    begin
      unique case (idx)
        0: seq_cmd = F_END;
        1: seq_cmd = F_RESET;
        2: seq_cmd = F_RESET;
        3: seq_cmd = F_RESET;
        4: seq_cmd = F_RESET;
        5: seq_cmd = F_RESET;
        6: seq_cmd = F_RESET;
        7: seq_cmd = F_END;
        8: seq_cmd = QUAD_IO_READ;
        9: seq_cmd = QUAD_ADDR;
        10: seq_cmd = QUAD_ADDR;
        11: seq_cmd = QUAD_ADDR;
        12: seq_cmd = QUAD_MODE;
        13: seq_cmd = QUAD_DUMMY;
        14: seq_cmd = CFG_USERMODE;
        15: seq_cmd = CFG_USER_CS_N;
        default: seq_cmd = F_END;
      endcase
    end
  endfunction

  assign cfg_cmd_valid_o = ENABLE && (state_q == ST_SEND) && !init_error_o;
  assign cfg_cmd_data_o  = seq_cmd(seq_idx_q);
  assign init_active_o   = ENABLE && (state_q != ST_DONE) && !init_error_o;
  assign step_index_o    = 32'(seq_idx_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q         <= ENABLE ? ST_SEND : ST_DONE;
      seq_idx_q       <= '0;
      timeout_q       <= '0;
      init_done_o     <= !ENABLE;
      init_error_o    <= 1'b0;
      last_rsp_data_o <= 32'h0;
      last_cmd_data_o <= 32'h0;
      error_code_o    <= 32'h0;
    end else if (!ENABLE) begin
      state_q         <= ST_DONE;
      seq_idx_q       <= '0;
      timeout_q       <= '0;
      init_done_o     <= 1'b1;
      init_error_o    <= 1'b0;
      last_rsp_data_o <= 32'h0;
      last_cmd_data_o <= 32'h0;
      error_code_o    <= 32'h0;
    end else begin
      unique case (state_q)
        ST_IDLE: begin
          state_q <= ST_SEND;
        end

        ST_SEND: begin
          if (cfg_cmd_ready_i) begin
            last_cmd_data_o <= seq_cmd(seq_idx_q);
            state_q   <= ST_WAIT_RSP;
            timeout_q <= '0;
          end else if (timeout_q == TIMEOUT_CYCLES[TIMEOUT_W-1:0]) begin
            init_error_o <= 1'b1;
            error_code_o <= 32'd1;
            state_q      <= ST_DONE;
          end else begin
            timeout_q <= timeout_q + 1'b1;
          end
        end

        ST_WAIT_RSP: begin
          if (cfg_rsp_valid_i) begin
            last_rsp_data_o <= cfg_rsp_data_i;
            timeout_q       <= '0;
            if (seq_idx_q == (SEQ_LEN - 1)) begin
              init_done_o <= 1'b1;
              state_q     <= ST_DONE;
            end else begin
              seq_idx_q <= seq_idx_q + 1'b1;
              state_q   <= ST_SEND;
            end
          end else if (timeout_q == TIMEOUT_CYCLES[TIMEOUT_W-1:0]) begin
            init_error_o <= 1'b1;
            error_code_o <= 32'd2;
            state_q      <= ST_DONE;
          end else begin
            timeout_q <= timeout_q + 1'b1;
          end
        end

        ST_DONE: begin
        end

        default: begin
          state_q <= ST_DONE;
        end
      endcase
    end
  end

endmodule
