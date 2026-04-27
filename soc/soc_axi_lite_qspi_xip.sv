module soc_axi_lite_qspi_xip #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
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
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr_i,
    input  logic [2:0]                s_axi_awprot_i,
    input  logic                      s_axi_awvalid_i,
    output logic                      s_axi_awready_o,
    input  logic [DATA_WIDTH-1:0]     s_axi_wdata_i,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb_i,
    input  logic                      s_axi_wvalid_i,
    output logic                      s_axi_wready_o,
    output logic [1:0]                s_axi_bresp_o,
    output logic                      s_axi_bvalid_o,
    input  logic                      s_axi_bready_i,
    input  logic [ADDR_WIDTH-1:0]     s_axi_araddr_i,
    input  logic [2:0]                s_axi_arprot_i,
    input  logic                      s_axi_arvalid_i,
    output logic                      s_axi_arready_o,
    output logic [DATA_WIDTH-1:0]     s_axi_rdata_o,
    output logic [1:0]                s_axi_rresp_o,
    output logic                      s_axi_rvalid_o,
    input  logic                      s_axi_rready_i,

    input  logic                      cfg_cmd_valid_i,
    input  logic [31:0]               cfg_cmd_data_i,
    output logic                      cfg_cmd_ready_o,
    output logic                      cfg_rsp_valid_o,
    output logic [31:0]               cfg_rsp_data_o,
    output logic                      flash_busy_o,
    output logic                      flash_init_done_o,

    output logic                      qspi_cs_n_o,
    output logic                      qspi_sck_o,
    output logic [1:0]                qspi_mod_o,
    output logic [3:0]                qspi_dat_o,
    input  logic [3:0]                qspi_dat_i
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam logic [31:0] XIP_WINDOW_BYTES = (32'd1 << LGFLASHSZ);
  localparam string SIM_XIP_INIT_FILE_P = SIM_XIP_INIT_FILE;

  typedef enum logic [1:0] {
    RD_IDLE,
    RD_REQ,
    RD_WAIT
  } rd_state_e;

  logic                    aw_seen_q;
  logic                    w_seen_q;
  logic [ADDR_WIDTH-1:0]   aw_addr_q;
  logic [DATA_WIDTH-1:0]   wdata_q;
  logic [STRB_WIDTH-1:0]   wstrb_q;
  logic                    bvalid_q;
  logic [1:0]              bresp_q;
  logic                    rvalid_q;
  logic [DATA_WIDTH-1:0]   rdata_q;
  logic [1:0]              rresp_q;
  logic [ADDR_WIDTH-1:0]   rd_addr_q;
  rd_state_e               rd_state_q;

  logic                    xip_req;
  logic                    xip_gnt;
  logic                    xip_rvalid;
  logic [31:0]             xip_rdata;
  logic                    xip_addr_in_range;

  integer byte_idx;

  assign xip_addr_in_range = (s_axi_araddr_i >= XIP_BASE_ADDR)
                          && ((s_axi_araddr_i - XIP_BASE_ADDR) < XIP_WINDOW_BYTES);

  assign s_axi_awready_o = ~aw_seen_q & ~bvalid_q & (rd_state_q == RD_IDLE) & ~rvalid_q;
  assign s_axi_wready_o  = ~w_seen_q & ~bvalid_q & (rd_state_q == RD_IDLE) & ~rvalid_q;
  assign s_axi_bresp_o   = bresp_q;
  assign s_axi_bvalid_o  = bvalid_q;

  assign s_axi_arready_o = ~bvalid_q & ~rvalid_q & ~aw_seen_q & ~w_seen_q & (rd_state_q == RD_IDLE);
  assign s_axi_rdata_o   = rdata_q;
  assign s_axi_rresp_o   = rresp_q;
  assign s_axi_rvalid_o  = rvalid_q;

  assign xip_req = (rd_state_q == RD_REQ);

  soc_qspi_xip #(
      .XIP_BASE_ADDR (XIP_BASE_ADDR),
      .LGFLASHSZ     (LGFLASHSZ),
      .OPT_PIPE      (OPT_PIPE),
      .OPT_CFG       (OPT_CFG),
      .OPT_STARTUP   (OPT_STARTUP),
      .OPT_CLKDIV    (OPT_CLKDIV),
      .OPT_ENDIANSWAP(OPT_ENDIANSWAP),
      .RDDELAY       (RDDELAY),
      .NDUMMY        (NDUMMY),
      .SIM_XIP_ENABLE(SIM_XIP_ENABLE),
      .SIM_XIP_INIT_FILE(SIM_XIP_INIT_FILE_P),
      .SIM_XIP_DEPTH_WORDS(SIM_XIP_DEPTH_WORDS)
  ) qspi_xip_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .xip_req_i       (xip_req),
      .xip_addr_i      (rd_addr_q),
      .xip_gnt_o       (xip_gnt),
      .xip_rvalid_o    (xip_rvalid),
      .xip_rdata_o     (xip_rdata),
      .cfg_cmd_valid_i (cfg_cmd_valid_i),
      .cfg_cmd_data_i  (cfg_cmd_data_i),
      .cfg_cmd_ready_o (cfg_cmd_ready_o),
      .cfg_rsp_valid_o (cfg_rsp_valid_o),
      .cfg_rsp_data_o  (cfg_rsp_data_o),
      .flash_busy_o    (flash_busy_o),
      .flash_init_done_o(flash_init_done_o),
      .qspi_cs_n_o     (qspi_cs_n_o),
      .qspi_sck_o      (qspi_sck_o),
      .qspi_mod_o      (qspi_mod_o),
      .qspi_dat_o      (qspi_dat_o),
      .qspi_dat_i      (qspi_dat_i)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_seen_q  <= 1'b0;
      w_seen_q   <= 1'b0;
      aw_addr_q  <= '0;
      wdata_q    <= '0;
      wstrb_q    <= '0;
      bvalid_q   <= 1'b0;
      bresp_q    <= 2'b00;
      rvalid_q   <= 1'b0;
      rdata_q    <= '0;
      rresp_q    <= 2'b00;
      rd_addr_q  <= '0;
      rd_state_q <= RD_IDLE;
    end else begin
      logic aw_fire;
      logic w_fire;
      logic ar_fire;
      logic aw_complete;
      logic w_complete;
      logic [ADDR_WIDTH-1:0] write_addr_now;
      logic [DATA_WIDTH-1:0] write_data_now;
      logic [STRB_WIDTH-1:0] write_strb_now;
      logic [DATA_WIDTH-1:0] _unused_write_merge;

      aw_fire = s_axi_awvalid_i && s_axi_awready_o;
      w_fire  = s_axi_wvalid_i && s_axi_wready_o;
      ar_fire = s_axi_arvalid_i && s_axi_arready_o;

      if (aw_fire) begin
        aw_seen_q <= 1'b1;
        aw_addr_q <= s_axi_awaddr_i;
      end

      if (w_fire) begin
        w_seen_q <= 1'b1;
        wdata_q  <= s_axi_wdata_i;
        wstrb_q  <= s_axi_wstrb_i;
      end

      aw_complete    = aw_seen_q | aw_fire;
      w_complete     = w_seen_q | w_fire;
      write_addr_now = aw_seen_q ? aw_addr_q : s_axi_awaddr_i;
      write_data_now = w_seen_q ? wdata_q : s_axi_wdata_i;
      write_strb_now = w_seen_q ? wstrb_q : s_axi_wstrb_i;
      _unused_write_merge = '0;

      if (!bvalid_q && aw_complete && w_complete) begin
        for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
          if (write_strb_now[byte_idx]) begin
            _unused_write_merge[8*byte_idx +: 8] = write_data_now[8*byte_idx +: 8];
          end
        end
        aw_seen_q <= 1'b0;
        w_seen_q  <= 1'b0;
        bvalid_q  <= 1'b1;
        bresp_q   <= 2'b10;
      end

      if (bvalid_q && s_axi_bready_i) begin
        bvalid_q <= 1'b0;
      end

      if (ar_fire) begin
        if (xip_addr_in_range) begin
          rd_addr_q  <= s_axi_araddr_i;
          rd_state_q <= RD_REQ;
        end else begin
          rdata_q  <= 32'h0;
          rresp_q  <= 2'b10;
          rvalid_q <= 1'b1;
        end
      end

      unique case (rd_state_q)
        RD_IDLE: begin
        end

        RD_REQ: begin
          if (xip_gnt) begin
            rd_state_q <= RD_WAIT;
          end
        end

        RD_WAIT: begin
          if (xip_rvalid) begin
            rdata_q    <= xip_rdata;
            rresp_q    <= 2'b00;
            rvalid_q   <= 1'b1;
            rd_state_q <= RD_IDLE;
          end
        end

        default: begin
          rd_state_q <= RD_IDLE;
        end
      endcase

      if (rvalid_q && s_axi_rready_i) begin
        rvalid_q <= 1'b0;
      end
    end
  end

  logic _unused_ok;
  assign _unused_ok = &{1'b0, s_axi_awprot_i, s_axi_arprot_i};

endmodule
