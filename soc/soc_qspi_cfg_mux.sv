module soc_qspi_cfg_mux (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        init_cmd_valid_i,
    input  logic [31:0] init_cmd_data_i,
    output logic        init_cmd_ready_o,
    output logic        init_rsp_valid_o,
    output logic [31:0] init_rsp_data_o,

    input  logic        sw_cmd_valid_i,
    input  logic [31:0] sw_cmd_data_i,
    output logic        sw_cmd_ready_o,
    output logic        sw_rsp_valid_o,
    output logic [31:0] sw_rsp_data_o,

    output logic        cfg_cmd_valid_o,
    output logic [31:0] cfg_cmd_data_o,
    input  logic        cfg_cmd_ready_i,
    input  logic        cfg_rsp_valid_i,
    input  logic [31:0] cfg_rsp_data_i
);

  localparam logic OWNER_INIT = 1'b0;
  localparam logic OWNER_SW   = 1'b1;

  logic rsp_pending_q;
  logic rsp_owner_q;
  logic cmd_owner;

  assign cmd_owner       = init_cmd_valid_i ? OWNER_INIT : OWNER_SW;
  assign cfg_cmd_valid_o = !rsp_pending_q && (init_cmd_valid_i || sw_cmd_valid_i);
  assign cfg_cmd_data_o  = init_cmd_valid_i ? init_cmd_data_i : sw_cmd_data_i;

  assign init_cmd_ready_o = !rsp_pending_q && cfg_cmd_ready_i;
  assign sw_cmd_ready_o   = !rsp_pending_q && !init_cmd_valid_i && cfg_cmd_ready_i;

  assign init_rsp_valid_o = cfg_rsp_valid_i && rsp_pending_q && (rsp_owner_q == OWNER_INIT);
  assign init_rsp_data_o  = cfg_rsp_data_i;
  assign sw_rsp_valid_o   = cfg_rsp_valid_i && rsp_pending_q && (rsp_owner_q == OWNER_SW);
  assign sw_rsp_data_o    = cfg_rsp_data_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rsp_pending_q <= 1'b0;
      rsp_owner_q   <= OWNER_INIT;
    end else begin
      if (!rsp_pending_q && cfg_cmd_valid_o && cfg_cmd_ready_i) begin
        rsp_pending_q <= 1'b1;
        rsp_owner_q   <= cmd_owner;
      end

      if (cfg_rsp_valid_i) begin
        rsp_pending_q <= 1'b0;
      end
    end
  end

endmodule
