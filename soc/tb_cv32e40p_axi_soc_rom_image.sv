`timescale 1ns/1ps

module tb_cv32e40p_axi_soc_rom_image;

  import soc_map_pkg::*;

  localparam logic [31:0] STATUS_ADDR = SOC_EXT_TEST_STATUS_ADDR;
  localparam int GPIO_PIN = 5;

  logic        clk;
  logic        rst_n;
  logic        fetch_enable;
  logic        pulp_clock_en;
  logic        scan_cg_en;
  logic [31:0] boot_addr;
  logic [31:0] mtvec_addr;
  logic [31:0] dm_halt_addr;
  logic [31:0] hart_id;
  logic [31:0] dm_exception_addr;

  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic [31:0] irq;
  logic        irq_ack;
  logic [ 4:0] irq_id;
  logic        debug_req;
  logic        debug_havereset;
  logic        debug_running;
  logic        debug_halted;
  logic        core_sleep;
  logic        uart0_rx;
  logic        uart0_tx;
  logic        uart1_rx;
  logic        uart1_tx;
  logic [31:0] gpio_in;
  logic [31:0] gpio_out;
  logic [31:0] gpio_dir;
  logic [31:0] gpio_irq;
  logic        timer_ref_clk;
  logic        timer_stoptimer;
  logic        timer_event_lo;
  logic        timer_event_hi;
  logic        timer_irq_lo;
  logic        timer_irq_hi;
  logic        timer_busy;
  logic        i2c_scl_o;
  logic        i2c_scl_oe_o;
  logic        i2c_sda_o;
  logic        i2c_sda_oe_o;
  logic        i2c_sda_i;
  logic        qspi_cs_n;
  logic        qspi_sck;
  logic [ 1:0] qspi_mod;
  logic [ 3:0] qspi_dat_o;
  logic [ 3:0] qspi_dat_i;

  logic [31:0] m_axi_awaddr;
  logic [ 2:0] m_axi_awprot;
  logic        m_axi_awvalid;
  logic        m_axi_awready;
  logic [31:0] m_axi_wdata;
  logic [ 3:0] m_axi_wstrb;
  logic        m_axi_wvalid;
  logic        m_axi_wready;
  logic [ 1:0] m_axi_bresp;
  logic        m_axi_bvalid;
  logic        m_axi_bready;
  logic [31:0] m_axi_araddr;
  logic [ 2:0] m_axi_arprot;
  logic        m_axi_arvalid;
  logic        m_axi_arready;
  logic [31:0] m_axi_rdata;
  logic [ 1:0] m_axi_rresp;
  logic        m_axi_rvalid;
  logic        m_axi_rready;

  logic        status_seen_q;
  logic [31:0] status_value_q;
  int unsigned ext_instr_req_count;
  int unsigned ext_axi_read_count;
  int unsigned ext_axi_write_count;
  int unsigned qspi_local_read_count;
  int unsigned imem_local_write_count;

  cv32e40p_axi_soc #(
      .ROM_INIT_FILE           ("test_rom_image.memh"),
      .IMEM_INIT_FILE          ("test_imem_dirty.memh"),
      .QSPI_SIM_XIP_ENABLE     (1'b1),
      .QSPI_SIM_XIP_INIT_FILE  ("test_flash_header_gpio.memh"),
      .QSPI_SIM_XIP_DEPTH_WORDS(32),
      .BOOT_COPY_XIP_ENABLE    (1'b0),
      .QSPI_INIT_ENABLE        (1'b0)
  ) dut (
      .clk_i               (clk),
      .rst_ni              (rst_n),
      .fetch_enable_i      (fetch_enable),
      .pulp_clock_en_i     (pulp_clock_en),
      .scan_cg_en_i        (scan_cg_en),
      .boot_addr_i         (boot_addr),
      .mtvec_addr_i        (mtvec_addr),
      .dm_halt_addr_i      (dm_halt_addr),
      .hart_id_i           (hart_id),
      .dm_exception_addr_i (dm_exception_addr),
      .instr_req_o         (instr_req),
      .instr_gnt_i         (instr_gnt),
      .instr_rvalid_i      (instr_rvalid),
      .instr_addr_o        (instr_addr),
      .instr_rdata_i       (instr_rdata),
      .irq_i               (irq),
      .irq_ack_o           (irq_ack),
      .irq_id_o            (irq_id),
      .debug_req_i         (debug_req),
      .debug_havereset_o   (debug_havereset),
      .debug_running_o     (debug_running),
      .debug_halted_o      (debug_halted),
      .core_sleep_o        (core_sleep),
      .uart0_rx_i          (uart0_rx),
      .uart0_tx_o          (uart0_tx),
      .uart1_rx_i          (uart1_rx),
      .uart1_tx_o          (uart1_tx),
      .gpio_in_i           (gpio_in),
      .gpio_out_o          (gpio_out),
      .gpio_dir_o          (gpio_dir),
      .gpio_irq_o          (gpio_irq),
      .timer_ref_clk_i     (timer_ref_clk),
      .timer_stoptimer_i   (timer_stoptimer),
      .timer_event_lo_i    (timer_event_lo),
      .timer_event_hi_i    (timer_event_hi),
      .timer_irq_lo_o      (timer_irq_lo),
      .timer_irq_hi_o      (timer_irq_hi),
      .timer_busy_o        (timer_busy),
      .i2c_sda_i           (i2c_sda_i),
      .i2c_scl_o           (i2c_scl_o),
      .i2c_scl_oe_o        (i2c_scl_oe_o),
      .i2c_sda_o           (i2c_sda_o),
      .i2c_sda_oe_o        (i2c_sda_oe_o),
      .qspi_cs_n_o         (qspi_cs_n),
      .qspi_sck_o          (qspi_sck),
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

  axi_lite_ram #(
      .WORDS(16)
  ) ext_ram (
      .clk_i           (clk),
      .rst_ni          (rst_n),
      .s_axi_awaddr_i  (m_axi_awaddr),
      .s_axi_awprot_i  (m_axi_awprot),
      .s_axi_awvalid_i (m_axi_awvalid),
      .s_axi_awready_o (m_axi_awready),
      .s_axi_wdata_i   (m_axi_wdata),
      .s_axi_wstrb_i   (m_axi_wstrb),
      .s_axi_wvalid_i  (m_axi_wvalid),
      .s_axi_wready_o  (m_axi_wready),
      .s_axi_bresp_o   (m_axi_bresp),
      .s_axi_bvalid_o  (m_axi_bvalid),
      .s_axi_bready_i  (m_axi_bready),
      .s_axi_araddr_i  (m_axi_araddr),
      .s_axi_arprot_i  (m_axi_arprot),
      .s_axi_arvalid_i (m_axi_arvalid),
      .s_axi_arready_o (m_axi_arready),
      .s_axi_rdata_o   (m_axi_rdata),
      .s_axi_rresp_o   (m_axi_rresp),
      .s_axi_rvalid_o  (m_axi_rvalid),
      .s_axi_rready_i  (m_axi_rready)
  );

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_seen_q          <= 1'b0;
      status_value_q         <= 32'h0;
      ext_instr_req_count    <= 0;
      ext_axi_read_count     <= 0;
      ext_axi_write_count    <= 0;
      qspi_local_read_count  <= 0;
      imem_local_write_count <= 0;
    end else begin
      if (instr_req) begin
        ext_instr_req_count <= ext_instr_req_count + 1;
      end
      if (m_axi_arvalid && m_axi_arready) begin
        ext_axi_read_count <= ext_axi_read_count + 1;
      end
      if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) begin
        ext_axi_write_count <= ext_axi_write_count + 1;
        if (m_axi_awaddr == STATUS_ADDR) begin
          status_seen_q  <= 1'b1;
          status_value_q <= m_axi_wdata;
        end
      end
      if (dut.qspi_xip_axi_arvalid && dut.qspi_xip_axi_arready) begin
        qspi_local_read_count <= qspi_local_read_count + 1;
      end
      if (dut.imem_data_req && dut.imem_data_gnt && dut.imem_data_we) begin
        imem_local_write_count <= imem_local_write_count + 1;
      end
    end
  end

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    fetch_enable      = 1'b0;
    pulp_clock_en     = 1'b1;
    scan_cg_en        = 1'b0;
    boot_addr         = SOC_ROM_BASE_ADDR;
    mtvec_addr        = 32'h0;
    dm_halt_addr      = 32'h0;
    hart_id           = 32'h0;
    dm_exception_addr = 32'h0;
    instr_gnt         = 1'b0;
    instr_rvalid      = 1'b0;
    instr_rdata       = 32'h0;
    irq               = 32'h0;
    debug_req         = 1'b0;
    uart0_rx          = 1'b1;
    uart1_rx          = 1'b1;
    i2c_sda_i         = 1'b1;
    qspi_dat_i        = 4'h0;
    gpio_in           = 32'h0;
    timer_ref_clk     = 1'b0;
    timer_stoptimer   = 1'b0;
    timer_event_lo    = 1'b0;
    timer_event_hi    = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    fetch_enable = 1'b1;
  end

  initial begin
    repeat (3000) begin
      @(posedge clk);
      if (status_seen_q) begin
        if (status_value_q !== 32'h3) begin
          $display("tb_cv32e40p_axi_soc_rom_image: FAIL status=%h", status_value_q);
          $fatal(1);
        end
        if (ext_instr_req_count != 0) begin
          $display("tb_cv32e40p_axi_soc_rom_image: external instruction fetch should be idle");
          $fatal(1);
        end
        if (ext_axi_read_count != 0) begin
          $display("tb_cv32e40p_axi_soc_rom_image: external AXI reads should be zero, got %0d", ext_axi_read_count);
          $fatal(1);
        end
        if (ext_axi_write_count != 1) begin
          $display("tb_cv32e40p_axi_soc_rom_image: expected single external status write, got %0d", ext_axi_write_count);
          $fatal(1);
        end
        if (qspi_local_read_count != 15) begin
          $display("tb_cv32e40p_axi_soc_rom_image: expected 15 local QSPI reads, got %0d", qspi_local_read_count);
          $fatal(1);
        end
        if (imem_local_write_count != 11) begin
          $display("tb_cv32e40p_axi_soc_rom_image: expected 11 local IMEM writes, got %0d", imem_local_write_count);
          $fatal(1);
        end
        if (gpio_out[GPIO_PIN] !== 1'b1 || gpio_dir[GPIO_PIN] !== 1'b1) begin
          $display("tb_cv32e40p_axi_soc_rom_image: GPIO[%0d] was not driven high", GPIO_PIN);
          $fatal(1);
        end
        if (dut.imem_i.mem_i.mem[0] !== 32'h1000_10b7 ||
            dut.imem_i.mem_i.mem[1] !== 32'h0100_01b7 ||
            dut.imem_i.mem_i.mem[2] !== 32'h0051_8193 ||
            dut.imem_i.mem_i.mem[3] !== 32'h0230_ac23 ||
            dut.imem_i.mem_i.mem[4] !== 32'h0050_0213 ||
            dut.imem_i.mem_i.mem[5] !== 32'h0040_a023 ||
            dut.imem_i.mem_i.mem[6] !== 32'h4000_02b7 ||
            dut.imem_i.mem_i.mem[7] !== 32'h0042_8293 ||
            dut.imem_i.mem_i.mem[8] !== 32'h0030_0313 ||
            dut.imem_i.mem_i.mem[9] !== 32'h0062_a023 ||
            dut.imem_i.mem_i.mem[10] !== 32'h0000_006f) begin
          $display("tb_cv32e40p_axi_soc_rom_image: IMEM image mismatch");
          $fatal(1);
        end
        $display("tb_cv32e40p_axi_soc_rom_image: PASS");
        $finish;
      end
    end

    $display("tb_cv32e40p_axi_soc_rom_image: TIMEOUT");
    $fatal(1);
  end

endmodule
