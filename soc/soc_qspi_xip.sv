module soc_qspi_xip #(
    parameter logic [31:0] XIP_BASE_ADDR = 32'h3000_0000,
    parameter int unsigned LGFLASHSZ = 24,
    parameter bit          OPT_PIPE = 1'b1,
    parameter bit          OPT_CFG = 1'b1,
    parameter bit          OPT_STARTUP = 1'b1,
    parameter int unsigned OPT_CLKDIV = 1,
    parameter bit          OPT_ENDIANSWAP = 1'b0,
    parameter int unsigned RDDELAY = 1,
    parameter int unsigned NDUMMY = 6,
    parameter bit          SIM_XIP_ENABLE = 1'b0,
    parameter string       SIM_XIP_INIT_FILE = "",
    parameter int unsigned SIM_XIP_DEPTH_WORDS = 256
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        xip_req_i,
    input  logic [31:0] xip_addr_i,
    output logic        xip_gnt_o,
    output logic        xip_rvalid_o,
    output logic [31:0] xip_rdata_o,

    input  logic        cfg_cmd_valid_i,
    input  logic [31:0] cfg_cmd_data_i,
    output logic        cfg_cmd_ready_o,
    output logic        cfg_rsp_valid_o,
    output logic [31:0] cfg_rsp_data_o,

    output logic        flash_busy_o,
    output logic        flash_init_done_o,

    output logic        qspi_cs_n_o,
    output logic        qspi_sck_o,
    output logic [1:0]  qspi_mod_o,
    output logic [3:0]  qspi_dat_o,
    input  logic [3:0]  qspi_dat_i
);

  localparam int WB_ADDR_WIDTH = (LGFLASHSZ > 2) ? (LGFLASHSZ - 2) : 1;

  typedef enum logic [0:0] {
    OP_XIP = 1'b0,
    OP_CFG = 1'b1
  } op_kind_e;

  logic                   rst_i;
  logic                   wb_cyc_q;
  logic                   wb_stb_q;
  op_kind_e               op_kind_q;
  logic [WB_ADDR_WIDTH-1:0] wb_addr_q;
  logic [31:0]            cfg_cmd_q;
  logic                   init_done_q;

  logic                   core_wb_stall;
  logic                   core_wb_ack;
  logic [31:0]            core_wb_data;
  logic                   core_qspi_cs_n;
  logic                   core_qspi_sck;
  logic [1:0]             core_qspi_mod;
  logic [3:0]             core_qspi_dat;

  logic                   xip_in_range;
  logic [31:0]            xip_offset;
  logic [WB_ADDR_WIDTH-1:0] xip_word_addr;
  logic                   issue_xip;
  logic                   issue_cfg;
  logic                   accept_now;
  logic                   sim_issue_xip;
  logic                   sim_issue_cfg;
  logic                   sim_pending_q;
  logic                   sim_is_cfg_q;
  logic [WB_ADDR_WIDTH-1:0] sim_word_addr_q;
  logic [31:0]            sim_cfg_cmd_q;
  logic                   sim_xip_rvalid_q;
  logic [31:0]            sim_xip_rdata_q;
  logic                   sim_cfg_rsp_valid_q;
  logic [31:0]            sim_cfg_rsp_data_q;
  logic [31:0]            sim_flash_mem [0:SIM_XIP_DEPTH_WORDS-1];

  assign rst_i = ~rst_ni;

  assign xip_in_range = (xip_addr_i >= XIP_BASE_ADDR)
                      && ((xip_addr_i - XIP_BASE_ADDR) < (32'd1 << LGFLASHSZ));
  assign xip_offset   = xip_addr_i - XIP_BASE_ADDR;
  assign xip_word_addr = xip_offset[WB_ADDR_WIDTH+1:2];

  assign issue_cfg = (!wb_cyc_q) && cfg_cmd_valid_i;
  assign issue_xip = (!wb_cyc_q) && (!cfg_cmd_valid_i) && xip_req_i && xip_in_range;
  assign accept_now = wb_cyc_q && wb_stb_q && !core_wb_stall;

  assign sim_issue_cfg = SIM_XIP_ENABLE && !sim_pending_q && cfg_cmd_valid_i;
  assign sim_issue_xip = SIM_XIP_ENABLE && !sim_pending_q && !cfg_cmd_valid_i
                      && xip_req_i && xip_in_range;

  assign xip_gnt_o = SIM_XIP_ENABLE ? sim_issue_xip
                                     : (accept_now && (op_kind_q == OP_XIP));
  assign xip_rvalid_o = SIM_XIP_ENABLE ? sim_xip_rvalid_q
                                        : (core_wb_ack && (op_kind_q == OP_XIP));
  assign xip_rdata_o = SIM_XIP_ENABLE ? sim_xip_rdata_q : core_wb_data;
  assign cfg_cmd_ready_o = SIM_XIP_ENABLE ? !sim_pending_q : !wb_cyc_q;
  assign cfg_rsp_valid_o = SIM_XIP_ENABLE ? sim_cfg_rsp_valid_q
                                          : (core_wb_ack && (op_kind_q == OP_CFG));
  assign cfg_rsp_data_o = SIM_XIP_ENABLE ? sim_cfg_rsp_data_q : core_wb_data;
  assign flash_busy_o = SIM_XIP_ENABLE ? sim_pending_q : wb_cyc_q;
  assign flash_init_done_o = SIM_XIP_ENABLE ? 1'b1 : init_done_q;

`ifndef SYNTHESIS
  initial begin : init_sim_xip_mem
    integer idx;
    for (idx = 0; idx < SIM_XIP_DEPTH_WORDS; idx = idx + 1) begin
      sim_flash_mem[idx] = 32'h0;
    end
    if (SIM_XIP_ENABLE && (SIM_XIP_INIT_FILE != "")) begin
      $readmemh(SIM_XIP_INIT_FILE, sim_flash_mem);
    end
  end
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wb_cyc_q    <= 1'b0;
      wb_stb_q    <= 1'b0;
      op_kind_q   <= OP_XIP;
      wb_addr_q   <= '0;
      cfg_cmd_q   <= '0;
      init_done_q <= 1'b0;
      sim_pending_q       <= 1'b0;
      sim_is_cfg_q        <= 1'b0;
      sim_word_addr_q     <= '0;
      sim_cfg_cmd_q       <= 32'h0;
      sim_xip_rvalid_q    <= 1'b0;
      sim_xip_rdata_q     <= 32'h0;
      sim_cfg_rsp_valid_q <= 1'b0;
      sim_cfg_rsp_data_q  <= 32'h0;
    end else begin
      sim_xip_rvalid_q    <= 1'b0;
      sim_cfg_rsp_valid_q <= 1'b0;

      if (SIM_XIP_ENABLE) begin
        if (sim_issue_cfg) begin
          sim_pending_q   <= 1'b1;
          sim_is_cfg_q    <= 1'b1;
          sim_cfg_cmd_q   <= cfg_cmd_data_i;
        end else if (sim_issue_xip) begin
          sim_pending_q   <= 1'b1;
          sim_is_cfg_q    <= 1'b0;
          sim_word_addr_q <= xip_word_addr;
        end else if (sim_pending_q) begin
          sim_pending_q <= 1'b0;
          if (sim_is_cfg_q) begin
            sim_cfg_rsp_valid_q <= 1'b1;
            sim_cfg_rsp_data_q  <= sim_cfg_cmd_q;
          end else begin
            sim_xip_rvalid_q <= 1'b1;
            if (sim_word_addr_q < SIM_XIP_DEPTH_WORDS) begin
              sim_xip_rdata_q <= sim_flash_mem[sim_word_addr_q];
            end else begin
              sim_xip_rdata_q <= 32'h0;
            end
          end
        end
      end

      if (issue_cfg) begin
        wb_cyc_q  <= 1'b1;
        wb_stb_q  <= 1'b1;
        op_kind_q <= OP_CFG;
        wb_addr_q <= '0;
        cfg_cmd_q <= cfg_cmd_data_i;
      end else if (issue_xip) begin
        wb_cyc_q  <= 1'b1;
        wb_stb_q  <= 1'b1;
        op_kind_q <= OP_XIP;
        wb_addr_q <= xip_word_addr;
        cfg_cmd_q <= 32'h0;
      end

      if (accept_now) begin
        wb_stb_q <= 1'b0;
      end

      if (core_wb_ack) begin
        wb_cyc_q    <= 1'b0;
        wb_stb_q    <= 1'b0;
        init_done_q <= 1'b1;
      end
    end
  end

  qflexpress #(
      .LGFLASHSZ    (LGFLASHSZ),
      .OPT_PIPE     (OPT_PIPE),
      .OPT_CFG      (OPT_CFG),
      .OPT_STARTUP  (OPT_STARTUP),
      .OPT_CLKDIV   (OPT_CLKDIV),
      .OPT_ENDIANSWAP(OPT_ENDIANSWAP),
      .RDDELAY      (RDDELAY),
      .NDUMMY       (NDUMMY)
  ) qflexpress_i (
      .i_clk      (clk_i),
      .i_reset    (rst_i),
      .i_wb_cyc   (wb_cyc_q),
      .i_wb_stb   (wb_stb_q && (op_kind_q == OP_XIP)),
      .i_cfg_stb  (wb_stb_q && (op_kind_q == OP_CFG)),
      .i_wb_we    (op_kind_q == OP_CFG),
      .i_wb_addr  (wb_addr_q),
      .i_wb_data  (cfg_cmd_q),
      .o_wb_stall (core_wb_stall),
      .o_wb_ack   (core_wb_ack),
      .o_wb_data  (core_wb_data),
      .o_qspi_sck (core_qspi_sck),
      .o_qspi_cs_n(core_qspi_cs_n),
      .o_qspi_mod (core_qspi_mod),
      .o_qspi_dat (core_qspi_dat),
      .i_qspi_dat (qspi_dat_i)
  );

  assign qspi_cs_n_o = SIM_XIP_ENABLE ? 1'b1 : core_qspi_cs_n;
  assign qspi_sck_o  = SIM_XIP_ENABLE ? 1'b0 : core_qspi_sck;
  assign qspi_mod_o  = SIM_XIP_ENABLE ? 2'b00 : core_qspi_mod;
  assign qspi_dat_o  = SIM_XIP_ENABLE ? 4'h0 : core_qspi_dat;

endmodule
