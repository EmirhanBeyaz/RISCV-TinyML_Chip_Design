module soc_apb_qspi_cfg #(
    parameter int APB_ADDR_WIDTH = 12
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0]               pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [31:0]               prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,
    input  logic                      boot_active_i,
    input  logic                      boot_done_i,
    input  logic                      boot_enable_i,
    input  logic [31:0]               boot_copy_words_i,
    input  logic [31:0]               xip_base_addr_i,
    input  logic [31:0]               imem_base_addr_i,
    input  logic                      flash_busy_i,
    input  logic                      flash_init_done_i,
    input  logic                      init_active_i,
    input  logic                      init_done_i,
    input  logic                      init_error_i,
    input  logic [31:0]               init_step_i,
    input  logic [31:0]               init_error_code_i,
    input  logic [31:0]               init_last_rsp_i,
    output logic                      cfg_cmd_valid_o,
    output logic [31:0]               cfg_cmd_data_o,
    input  logic                      cfg_cmd_ready_i,
    input  logic                      cfg_rsp_valid_i,
    input  logic [31:0]               cfg_rsp_data_i
);

  localparam logic [11:0] REG_ID         = 12'h000;
  localparam logic [11:0] REG_VERSION    = 12'h004;
  localparam logic [11:0] REG_STATUS     = 12'h008;
  localparam logic [11:0] REG_COPY_WORDS = 12'h00C;
  localparam logic [11:0] REG_XIP_BASE   = 12'h010;
  localparam logic [11:0] REG_IMEM_BASE  = 12'h014;
  localparam logic [11:0] REG_SCRATCH0   = 12'h018;
  localparam logic [11:0] REG_SCRATCH1   = 12'h01C;
  localparam logic [11:0] REG_CFG_CMD    = 12'h020;
  localparam logic [11:0] REG_CFG_RSP    = 12'h024;
  localparam logic [11:0] REG_FLASH_STAT = 12'h028;
  localparam logic [11:0] REG_INIT_STAT  = 12'h02C;
  localparam logic [11:0] REG_INIT_RSP   = 12'h030;
  localparam logic [11:0] REG_LAST_CMD   = 12'h034;

  localparam logic [31:0] QSPI_CFG_ID      = 32'h5153_5049;  // "QSPI"
  localparam logic [31:0] QSPI_CFG_VERSION = 32'h0001_0000;

  logic [31:0] scratch0_q;
  logic [31:0] scratch1_q;
  logic [31:0] cfg_rsp_data_q;
  logic [31:0] cfg_last_cmd_q;
  logic        cfg_rsp_pending_q;
  logic        reg_access;
  logic [11:0] reg_addr;
  logic        cfg_cmd_access;

  assign reg_access = psel_i && penable_i;
  assign reg_addr   = {paddr_i[APB_ADDR_WIDTH-1:2], 2'b00};
  assign cfg_cmd_access = reg_access && pwrite_i && (reg_addr == REG_CFG_CMD);
  assign cfg_cmd_valid_o = cfg_cmd_access;
  assign cfg_cmd_data_o  = pwdata_i;
  assign pready_o        = cfg_cmd_access ? cfg_cmd_ready_i : 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      scratch0_q        <= 32'h0;
      scratch1_q        <= 32'h0;
      cfg_rsp_data_q    <= 32'h0;
      cfg_last_cmd_q    <= 32'h0;
      cfg_rsp_pending_q <= 1'b0;
    end else begin
      if (reg_access && pwrite_i) begin
        unique case (reg_addr)
          REG_SCRATCH0: scratch0_q <= pwdata_i;
          REG_SCRATCH1: scratch1_q <= pwdata_i;
          default: begin
          end
        endcase
      end
      if (cfg_cmd_valid_o && cfg_cmd_ready_i) begin
        cfg_last_cmd_q <= cfg_cmd_data_o;
      end
      if (cfg_rsp_valid_i) begin
        cfg_rsp_data_q    <= cfg_rsp_data_i;
        cfg_rsp_pending_q <= 1'b1;
      end
      if (reg_access && !pwrite_i && (reg_addr == REG_CFG_RSP) && !cfg_rsp_valid_i) begin
        cfg_rsp_pending_q <= 1'b0;
      end
    end
  end

  always_comb begin
    prdata_o  = 32'h0;
    pslverr_o = 1'b0;

    unique case (reg_addr)
      REG_ID:         prdata_o = QSPI_CFG_ID;
      REG_VERSION:    prdata_o = QSPI_CFG_VERSION;
      REG_STATUS:     prdata_o = {
                                 22'h0,
                                 init_error_i,
                                 init_done_i,
                                 init_active_i,
                                 cfg_rsp_pending_q,
                                 cfg_cmd_ready_i,
                                 flash_init_done_i,
                                 flash_busy_i,
                                 boot_enable_i,
                                 boot_done_i,
                                 boot_active_i
                               };
      REG_COPY_WORDS: prdata_o = boot_copy_words_i;
      REG_XIP_BASE:   prdata_o = xip_base_addr_i;
      REG_IMEM_BASE:  prdata_o = imem_base_addr_i;
      REG_SCRATCH0:   prdata_o = scratch0_q;
      REG_SCRATCH1:   prdata_o = scratch1_q;
      REG_CFG_CMD:    prdata_o = 32'h0;
      REG_CFG_RSP:    prdata_o = cfg_rsp_data_q;
      REG_FLASH_STAT: prdata_o = {
                                 28'h0,
                                 cfg_rsp_pending_q,
                                 cfg_cmd_ready_i,
                                 flash_init_done_i,
                                 flash_busy_i
                               };
      REG_INIT_STAT:  prdata_o = {
                                 8'h0,
                                 init_step_i[7:0],
                                 init_error_code_i[7:0],
                                 5'h0,
                                 init_error_i,
                                 init_done_i,
                                 init_active_i
                               };
      REG_INIT_RSP:   prdata_o = init_last_rsp_i;
      REG_LAST_CMD:   prdata_o = cfg_last_cmd_q;
      default: begin
        prdata_o  = 32'h0;
        pslverr_o = psel_i;
      end
    endcase
  end

endmodule
