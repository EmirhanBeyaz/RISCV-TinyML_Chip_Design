module fpga_top #(
    parameter logic [31:0] BOOT_ADDR             = 32'h0000_0000,
    parameter logic [31:0] MTVEC_ADDR            = 32'h0000_0000,
    parameter logic [31:0] DM_HALT_ADDR          = 32'h0000_0000,
    parameter logic [31:0] DM_EXCEPTION_ADDR     = 32'h0000_0000,
    parameter logic [31:0] HART_ID               = 32'h0000_0000,
    parameter              ROM_INIT_FILE         = "",
    parameter              IMEM_INIT_FILE        = "",
    parameter bit          BOOT_COPY_XIP_ENABLE  = 1'b0,
    parameter bit          QSPI_INIT_ENABLE      = 1'b1,
    parameter int unsigned EXT_AXI_RAM_WORDS     = 1024
) (
    input  wire        clk_i,
    input  wire        rst_ni,

    input  wire        uart0_rx_i,
    output wire        uart0_tx_o,
    input  wire        uart1_rx_i,
    output wire        uart1_tx_o,

    input  wire [7:0]  sw_i,
    output wire [7:0]  led_o,

    inout  wire        i2c_scl_io,
    inout  wire        i2c_sda_io,

    output wire        qspi_cs_n_o,
    output wire        qspi_sck_o,
    inout  wire [3:0]  qspi_dq_io
);

  localparam logic [31:0] ZERO_IRQ = 32'h0000_0000;

  logic        soc_instr_req;
  logic [31:0] soc_instr_addr;

  logic [31:0] gpio_in;
  logic [31:0] gpio_out;
  logic [31:0] gpio_dir;
  logic [31:0] gpio_irq;

  logic        timer_irq_lo;
  logic        timer_irq_hi;
  logic        timer_busy;

  logic        i2c_scl_i;
  logic        i2c_scl_o;
  logic        i2c_scl_oe;
  logic        i2c_sda_i;
  logic        i2c_sda_o;
  logic        i2c_sda_oe;

  logic [1:0]  qspi_mod;
  logic [3:0]  qspi_dat_o;
  logic [3:0]  qspi_dat_i;

  logic [31:0] m_axi_awaddr;
  logic [2:0]  m_axi_awprot;
  logic        m_axi_awvalid;
  logic        m_axi_awready;
  logic [31:0] m_axi_wdata;
  logic [3:0]  m_axi_wstrb;
  logic        m_axi_wvalid;
  logic        m_axi_wready;
  logic [1:0]  m_axi_bresp;
  logic        m_axi_bvalid;
  logic        m_axi_bready;
  logic [31:0] m_axi_araddr;
  logic [2:0]  m_axi_arprot;
  logic        m_axi_arvalid;
  logic        m_axi_arready;
  logic [31:0] m_axi_rdata;
  logic [1:0]  m_axi_rresp;
  logic        m_axi_rvalid;
  logic        m_axi_rready;

  assign gpio_in = {24'h0, sw_i};
  assign led_o   = gpio_out[7:0] & gpio_dir[7:0];

  assign i2c_scl_io = i2c_scl_oe ? 1'b0 : 1'bz;
  assign i2c_sda_io = i2c_sda_oe ? 1'b0 : 1'bz;
  assign i2c_scl_i  = i2c_scl_io;
  assign i2c_sda_i  = i2c_sda_io;

  assign qspi_dat_i = qspi_dq_io;
  assign qspi_dq_io[0] = ((qspi_mod == 2'b10) || (qspi_mod == 2'b00)) ? qspi_dat_o[0] : 1'bz;
  assign qspi_dq_io[1] =  (qspi_mod == 2'b10)                          ? qspi_dat_o[1] : 1'bz;
  assign qspi_dq_io[2] =  (qspi_mod == 2'b10)                          ? qspi_dat_o[2] : 1'bz;
  assign qspi_dq_io[3] =  (qspi_mod == 2'b10)                          ? qspi_dat_o[3] : 1'bz;

  cv32e40p_axi_soc #(
      .ROM_INIT_FILE       (ROM_INIT_FILE),
      .IMEM_INIT_FILE      (IMEM_INIT_FILE),
      .BOOT_COPY_XIP_ENABLE(BOOT_COPY_XIP_ENABLE),
      .QSPI_INIT_ENABLE    (QSPI_INIT_ENABLE)
  ) soc_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .fetch_enable_i      (1'b1),
      .pulp_clock_en_i     (1'b1),
      .scan_cg_en_i        (1'b0),
      .boot_addr_i         (BOOT_ADDR),
      .mtvec_addr_i        (MTVEC_ADDR),
      .dm_halt_addr_i      (DM_HALT_ADDR),
      .hart_id_i           (HART_ID),
      .dm_exception_addr_i (DM_EXCEPTION_ADDR),
      .instr_req_o         (soc_instr_req),
      .instr_gnt_i         (1'b0),
      .instr_rvalid_i      (1'b0),
      .instr_addr_o        (soc_instr_addr),
      .instr_rdata_i       (32'h0000_0000),
      .irq_i               (ZERO_IRQ),
      .irq_ack_o           (),
      .irq_id_o            (),
      .debug_req_i         (1'b0),
      .debug_havereset_o   (),
      .debug_running_o     (),
      .debug_halted_o      (),
      .core_sleep_o        (),
      .uart0_rx_i          (uart0_rx_i),
      .uart0_tx_o          (uart0_tx_o),
      .uart1_rx_i          (uart1_rx_i),
      .uart1_tx_o          (uart1_tx_o),
      .gpio_in_i           (gpio_in),
      .gpio_out_o          (gpio_out),
      .gpio_dir_o          (gpio_dir),
      .gpio_irq_o          (gpio_irq),
      .timer_ref_clk_i     (1'b0),
      .timer_stoptimer_i   (1'b0),
      .timer_event_lo_i    (1'b0),
      .timer_event_hi_i    (1'b0),
      .timer_irq_lo_o      (timer_irq_lo),
      .timer_irq_hi_o      (timer_irq_hi),
      .timer_busy_o        (timer_busy),
      .i2c_sda_i           (i2c_sda_i),
      .i2c_scl_o           (i2c_scl_o),
      .i2c_scl_oe_o        (i2c_scl_oe),
      .i2c_sda_o           (i2c_sda_o),
      .i2c_sda_oe_o        (i2c_sda_oe),
      .qspi_cs_n_o         (qspi_cs_n_o),
      .qspi_sck_o          (qspi_sck_o),
      .qspi_mod_o          (qspi_mod),
      .qspi_dat_o          (qspi_dat_o),
      .qspi_dat_i          (qspi_dat_i),
      .m_axi_awaddr_o      (m_axi_awaddr),
      .m_axi_awprot_o      (m_axi_awprot),
      .m_axi_awvalid_o     (m_axi_awvalid),
      .m_axi_awready_i     (m_axi_awready),
      .m_axi_wdata_o       (m_axi_wdata),
      .m_axi_wstrb_o       (m_axi_wstrb),
      .m_axi_wvalid_o      (m_axi_wvalid),
      .m_axi_wready_i      (m_axi_wready),
      .m_axi_bresp_i       (m_axi_bresp),
      .m_axi_bvalid_i      (m_axi_bvalid),
      .m_axi_bready_o      (m_axi_bready),
      .m_axi_araddr_o      (m_axi_araddr),
      .m_axi_arprot_o      (m_axi_arprot),
      .m_axi_arvalid_o     (m_axi_arvalid),
      .m_axi_arready_i     (m_axi_arready),
      .m_axi_rdata_i       (m_axi_rdata),
      .m_axi_rresp_i       (m_axi_rresp),
      .m_axi_rvalid_i      (m_axi_rvalid),
      .m_axi_rready_o      (m_axi_rready)
  );

  // Keep the external AXI-Lite fabric local in the FPGA wrapper so stray
  // accesses do not become top-level IOs.
  axi_lite_ram #(
      .WORDS(EXT_AXI_RAM_WORDS)
  ) ext_axi_ram_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (m_axi_awaddr),
      .s_axi_awprot_i (m_axi_awprot),
      .s_axi_awvalid_i(m_axi_awvalid),
      .s_axi_awready_o(m_axi_awready),
      .s_axi_wdata_i  (m_axi_wdata),
      .s_axi_wstrb_i  (m_axi_wstrb),
      .s_axi_wvalid_i (m_axi_wvalid),
      .s_axi_wready_o (m_axi_wready),
      .s_axi_bresp_o  (m_axi_bresp),
      .s_axi_bvalid_o (m_axi_bvalid),
      .s_axi_bready_i (m_axi_bready),
      .s_axi_araddr_i (m_axi_araddr),
      .s_axi_arprot_i (m_axi_arprot),
      .s_axi_arvalid_i(m_axi_arvalid),
      .s_axi_arready_o(m_axi_arready),
      .s_axi_rdata_o  (m_axi_rdata),
      .s_axi_rresp_o  (m_axi_rresp),
      .s_axi_rvalid_o (m_axi_rvalid),
      .s_axi_rready_i (m_axi_rready)
  );

endmodule
