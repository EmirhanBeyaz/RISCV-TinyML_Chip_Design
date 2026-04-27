`timescale 1ns/1ps

module tb_soc_axi_lite_apb_qspi_cfg;

  import soc_map_pkg::*;

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
  localparam logic [31:0] STATUS_IDLE    = 32'h0000_0136;
  localparam logic [31:0] STATUS_RSP     = 32'h0000_0176;
  localparam logic [31:0] FLASH_STAT_IDLE = 32'h0000_0006;
  localparam logic [31:0] FLASH_STAT_RSP  = 32'h0000_000E;
  localparam logic [31:0] INIT_STAT       = 32'h0012_0002;
  localparam logic [31:0] INIT_LAST_RSP   = 32'h55AA_00CC;

  logic clk;
  logic rst_n;

  logic [31:0] s_axi_awaddr;
  logic [ 2:0] s_axi_awprot;
  logic        s_axi_awvalid;
  logic        s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [ 3:0] s_axi_wstrb;
  logic        s_axi_wvalid;
  logic        s_axi_wready;
  logic [ 1:0] s_axi_bresp;
  logic        s_axi_bvalid;
  logic        s_axi_bready;
  logic [31:0] s_axi_araddr;
  logic [ 2:0] s_axi_arprot;
  logic        s_axi_arvalid;
  logic        s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [ 1:0] s_axi_rresp;
  logic        s_axi_rvalid;
  logic        s_axi_rready;

  logic [31:0] apb_paddr;
  logic [ 2:0] apb_pprot;
  logic        apb_penable;
  logic        apb_pwrite;
  logic [31:0] apb_pwdata;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_psel;
  logic [SOC_MMIO_SLOT_COUNT-1:0][31:0] apb_prdata;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_pready;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_pslverr;

  logic [31:0] qspi_prdata;
  logic        qspi_pready;
  logic        qspi_pslverr;
  logic        cfg_cmd_valid;
  logic [31:0] cfg_cmd_data;
  logic        cfg_cmd_ready;
  logic        cfg_rsp_valid;
  logic [31:0] cfg_rsp_data;
  logic [31:0] cfg_cmd_seen_q;
  logic [31:0] cfg_rsp_next_q;
  logic        cfg_rsp_pending_q;
  integer      idx;

  soc_axi_lite_apb_island #(
      .NO_APB_SLOTS(SOC_MMIO_SLOT_COUNT)
  ) dut (
      .clk_i          (clk),
      .rst_ni         (rst_n),
      .s_axi_awaddr_i (s_axi_awaddr),
      .s_axi_awprot_i (s_axi_awprot),
      .s_axi_awvalid_i(s_axi_awvalid),
      .s_axi_awready_o(s_axi_awready),
      .s_axi_wdata_i  (s_axi_wdata),
      .s_axi_wstrb_i  (s_axi_wstrb),
      .s_axi_wvalid_i (s_axi_wvalid),
      .s_axi_wready_o (s_axi_wready),
      .s_axi_bresp_o  (s_axi_bresp),
      .s_axi_bvalid_o (s_axi_bvalid),
      .s_axi_bready_i (s_axi_bready),
      .s_axi_araddr_i (s_axi_araddr),
      .s_axi_arprot_i (s_axi_arprot),
      .s_axi_arvalid_i(s_axi_arvalid),
      .s_axi_arready_o(s_axi_arready),
      .s_axi_rdata_o  (s_axi_rdata),
      .s_axi_rresp_o  (s_axi_rresp),
      .s_axi_rvalid_o (s_axi_rvalid),
      .s_axi_rready_i (s_axi_rready),
      .paddr_o        (apb_paddr),
      .pprot_o        (apb_pprot),
      .penable_o      (apb_penable),
      .pwrite_o       (apb_pwrite),
      .pwdata_o       (apb_pwdata),
      .psel_o         (apb_psel),
      .prdata_i       (apb_prdata),
      .pready_i       (apb_pready),
      .pslverr_i      (apb_pslverr)
  );

  soc_apb_qspi_cfg qspi_cfg_i (
      .clk_i            (clk),
      .rst_ni           (rst_n),
      .paddr_i          (apb_paddr[11:0]),
      .pwdata_i         (apb_pwdata),
      .pwrite_i         (apb_pwrite),
      .psel_i           (apb_psel[SOC_MMIO_QSPI_CFG]),
      .penable_i        (apb_penable),
      .prdata_o         (qspi_prdata),
      .pready_o         (qspi_pready),
      .pslverr_o        (qspi_pslverr),
      .boot_active_i    (1'b0),
      .boot_done_i      (1'b1),
      .boot_enable_i    (1'b1),
      .boot_copy_words_i(32'd16),
      .xip_base_addr_i  (soc_map_pkg::SOC_QSPI_XIP_BASE_ADDR),
      .imem_base_addr_i (soc_map_pkg::SOC_IMEM_BASE_ADDR),
      .flash_busy_i     (1'b0),
      .flash_init_done_i(1'b1),
      .init_active_i    (1'b0),
      .init_done_i      (1'b1),
      .init_error_i     (1'b0),
      .init_step_i      (32'd18),
      .init_error_code_i(32'd0),
      .init_last_rsp_i  (INIT_LAST_RSP),
      .cfg_cmd_valid_o  (cfg_cmd_valid),
      .cfg_cmd_data_o   (cfg_cmd_data),
      .cfg_cmd_ready_i  (cfg_cmd_ready),
      .cfg_rsp_valid_i  (cfg_rsp_valid),
      .cfg_rsp_data_i   (cfg_rsp_data)
  );

  always_comb begin
    for (idx = 0; idx < SOC_MMIO_SLOT_COUNT; idx = idx + 1) begin
      apb_prdata[idx]  = '0;
      apb_pready[idx]  = 1'b1;
      apb_pslverr[idx] = 1'b1;
    end

    apb_prdata[SOC_MMIO_QSPI_CFG]  = qspi_prdata;
    apb_pready[SOC_MMIO_QSPI_CFG]  = qspi_pready;
    apb_pslverr[SOC_MMIO_QSPI_CFG] = qspi_pslverr;
  end

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cfg_cmd_ready    <= 1'b1;
      cfg_rsp_valid    <= 1'b0;
      cfg_rsp_data     <= 32'h0;
      cfg_cmd_seen_q   <= 32'h0;
      cfg_rsp_next_q   <= 32'h0;
      cfg_rsp_pending_q <= 1'b0;
    end else begin
      cfg_rsp_valid <= 1'b0;

      if (cfg_cmd_valid && cfg_cmd_ready) begin
        cfg_cmd_seen_q    <= cfg_cmd_data;
        cfg_rsp_next_q    <= 32'hA5A5_0000 | cfg_cmd_data[15:0];
        cfg_rsp_pending_q <= 1'b1;
        cfg_cmd_ready     <= 1'b0;
      end else if (cfg_rsp_pending_q) begin
        cfg_rsp_valid     <= 1'b1;
        cfg_rsp_data      <= cfg_rsp_next_q;
        cfg_rsp_pending_q <= 1'b0;
        cfg_cmd_ready     <= 1'b1;
      end
    end
  end

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    s_axi_awaddr  = '0;
    s_axi_awprot  = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = '0;
    s_axi_wstrb   = '0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = '0;
    s_axi_arprot  = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_ID, 32'h5153_5049);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_VERSION, 32'h0001_0000);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_STATUS, STATUS_IDLE);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_COPY_WORDS, 32'd16);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_XIP_BASE, SOC_QSPI_XIP_BASE_ADDR);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_IMEM_BASE, SOC_IMEM_BASE_ADDR);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_FLASH_STAT, FLASH_STAT_IDLE);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_INIT_STAT, INIT_STAT);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_INIT_RSP, INIT_LAST_RSP);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_LAST_CMD, 32'h0);

    axi_write(SOC_QSPI_CFG_BASE_ADDR + REG_SCRATCH0, 32'h55AA_33CC);
    axi_write(SOC_QSPI_CFG_BASE_ADDR + REG_SCRATCH1, 32'hC001_CAFE);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_SCRATCH0, 32'h55AA_33CC);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_SCRATCH1, 32'hC001_CAFE);

    axi_write(SOC_QSPI_CFG_BASE_ADDR + REG_CFG_CMD, 32'h0000_00AB);
    if (cfg_cmd_seen_q !== 32'h0000_00AB) begin
      $display("tb_soc_axi_lite_apb_qspi_cfg: cfg cmd mismatch %h", cfg_cmd_seen_q);
      $fatal(1);
    end
    repeat (2) @(posedge clk);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_STATUS, STATUS_RSP);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_FLASH_STAT, FLASH_STAT_RSP);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_LAST_CMD, 32'h0000_00AB);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_CFG_RSP, 32'hA5A5_00AB);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_STATUS, STATUS_IDLE);
    axi_check_read(SOC_QSPI_CFG_BASE_ADDR + REG_FLASH_STAT, FLASH_STAT_IDLE);

    $display("tb_soc_axi_lite_apb_qspi_cfg: PASS");
    $finish;
  end

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    begin
      s_axi_awaddr  = addr;
      s_axi_awprot  = 3'b000;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = 4'hF;
      s_axi_wvalid  = 1'b1;

      wait (s_axi_awready && s_axi_wready);
      @(posedge clk);
      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      s_axi_bready = 1'b1;
      while (!s_axi_bvalid) @(posedge clk);
      if (s_axi_bresp !== 2'b00) begin
        $display("tb_soc_axi_lite_apb_qspi_cfg: write response error %b at %h", s_axi_bresp, addr);
        $fatal(1);
      end
      while (s_axi_bvalid) @(posedge clk);
      @(negedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_check_read(input logic [31:0] addr, input logic [31:0] exp_data);
    begin
      s_axi_araddr  = addr;
      s_axi_arprot  = 3'b000;
      s_axi_arvalid = 1'b1;

      wait (s_axi_arready);
      @(posedge clk);
      @(negedge clk);
      s_axi_arvalid = 1'b0;

      s_axi_rready = 1'b1;
      while (!s_axi_rvalid) @(posedge clk);
      if (s_axi_rresp !== 2'b00) begin
        $display("tb_soc_axi_lite_apb_qspi_cfg: read response error %b at %h", s_axi_rresp, addr);
        $fatal(1);
      end
      if (s_axi_rdata !== exp_data) begin
        $display("tb_soc_axi_lite_apb_qspi_cfg: read mismatch %h != %h at %h",
                 s_axi_rdata, exp_data, addr);
        $fatal(1);
      end
      while (s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
