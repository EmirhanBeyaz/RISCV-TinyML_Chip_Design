`timescale 1ns/1ps

module cv32e40p_top #(
    parameter COREV_PULP = 0,
    parameter COREV_CLUSTER = 0,
    parameter FPU = 0,
    parameter FPU_ADDMUL_LAT = 0,
    parameter FPU_OTHERS_LAT = 0,
    parameter ZFINX = 0,
    parameter NUM_MHPMCOUNTERS = 1
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        pulp_clock_en_i,
    input  logic        scan_cg_en_i,
    input  logic [31:0] boot_addr_i,
    input  logic [31:0] mtvec_addr_i,
    input  logic [31:0] dm_halt_addr_i,
    input  logic [31:0] hart_id_i,
    input  logic [31:0] dm_exception_addr_i,
    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    input  logic        instr_rvalid_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,
    output logic        data_req_o,
    input  logic        data_gnt_i,
    input  logic        data_rvalid_i,
    output logic        data_we_o,
    output logic [ 3:0] data_be_o,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,
    input  logic [31:0] irq_i,
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,
    input  logic        debug_req_i,
    output logic        debug_havereset_o,
    output logic        debug_running_o,
    output logic        debug_halted_o,
    input  logic        fetch_enable_i,
    output logic        core_sleep_o
);

  logic [31:0] pc_q;
  logic [ 2:0] fetch_idx_q;
  logic        waiting_q;
  logic        started_q;
  logic [31:0] seen_words_q[0:3];
  integer      seen_idx;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q               <= 32'h0;
      fetch_idx_q        <= 3'd0;
      waiting_q          <= 1'b0;
      started_q          <= 1'b0;
      instr_req_o        <= 1'b0;
      instr_addr_o       <= 32'h0;
      data_req_o         <= 1'b0;
      data_we_o          <= 1'b0;
      data_be_o          <= 4'h0;
      data_addr_o        <= 32'h0;
      data_wdata_o       <= 32'h0;
      irq_ack_o          <= 1'b0;
      irq_id_o           <= 5'h0;
      debug_havereset_o  <= 1'b0;
      debug_running_o    <= 1'b0;
      debug_halted_o     <= 1'b0;
      core_sleep_o       <= 1'b0;

      for (seen_idx = 0; seen_idx < 4; seen_idx = seen_idx + 1) begin
        seen_words_q[seen_idx] <= 32'h0;
      end
    end else begin
      data_req_o        <= 1'b0;
      data_we_o         <= 1'b0;
      data_be_o         <= 4'h0;
      data_addr_o       <= 32'h0;
      data_wdata_o      <= 32'h0;
      irq_ack_o         <= 1'b0;
      irq_id_o          <= 5'h0;
      debug_havereset_o <= 1'b0;
      debug_running_o   <= 1'b1;
      debug_halted_o    <= 1'b0;
      core_sleep_o      <= 1'b0;

      if (!started_q) begin
        pc_q <= boot_addr_i;
        started_q <= 1'b1;
      end

      instr_req_o <= 1'b0;
      if (started_q && fetch_enable_i && (fetch_idx_q < 3'd4) && !waiting_q) begin
        instr_req_o  <= 1'b1;
        instr_addr_o <= pc_q;
        if (instr_gnt_i) begin
          waiting_q <= 1'b1;
        end
      end

      if (instr_rvalid_i && waiting_q) begin
        seen_words_q[fetch_idx_q] <= instr_rdata_i;
        fetch_idx_q               <= fetch_idx_q + 3'd1;
        pc_q                      <= pc_q + 32'd4;
        waiting_q                 <= 1'b0;
      end
    end
  end

endmodule

module tb_cv32e40p_axi_soc_boot_copy;

  import soc_map_pkg::*;

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
  int unsigned ext_instr_req_count;
  int unsigned axi_read_count;
  int unsigned axi_write_count;

  localparam logic [31:0] XIP_WORD0 = 32'h1234_5678;
  localparam logic [31:0] XIP_WORD1 = 32'h89AB_CDEF;
  localparam logic [31:0] XIP_WORD2 = 32'hCAFE_BABE;
  localparam logic [31:0] XIP_WORD3 = 32'hDEAD_BEEF;

  cv32e40p_axi_soc #(
      .BOOT_COPY_XIP_ENABLE(1'b1),
      .BOOT_COPY_WORDS     (4)
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
  ) xip_ram (
      .clk_i          (clk),
      .rst_ni         (rst_n),
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

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ext_instr_req_count <= 0;
      axi_read_count      <= 0;
      axi_write_count     <= 0;
    end else begin
      if (instr_req) begin
        ext_instr_req_count <= ext_instr_req_count + 1;
      end
      if (m_axi_arvalid && m_axi_arready) begin
        axi_read_count <= axi_read_count + 1;
      end
      if (m_axi_awvalid || m_axi_wvalid) begin
        axi_write_count <= axi_write_count + 1;
      end
    end
  end

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    fetch_enable      = 1'b1;
    pulp_clock_en     = 1'b1;
    scan_cg_en        = 1'b0;
    boot_addr         = SOC_IMEM_BASE_ADDR;
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

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    wait (dut.boot_done);
    wait (dut.core_i.fetch_idx_q == 3'd4);
    @(posedge clk);

    if (ext_instr_req_count != 0) begin
      $display("tb_cv32e40p_axi_soc_boot_copy: external instruction port was used");
      $fatal(1);
    end

    if (axi_read_count != 0) begin
      $display("tb_cv32e40p_axi_soc_boot_copy: external AXI should be idle, got %0d reads", axi_read_count);
      $fatal(1);
    end

    if (axi_write_count != 0) begin
      $display("tb_cv32e40p_axi_soc_boot_copy: unexpected external AXI write activity");
      $fatal(1);
    end

    if (dut.imem_i.mem_i.mem[0] !== 32'h0 ||
        dut.imem_i.mem_i.mem[1] !== 32'h0 ||
        dut.imem_i.mem_i.mem[2] !== 32'h0 ||
        dut.imem_i.mem_i.mem[3] !== 32'h0) begin
      $display("tb_cv32e40p_axi_soc_boot_copy: IMEM contents mismatch");
      $fatal(1);
    end

    if (dut.core_i.seen_words_q[0] !== 32'h0 ||
        dut.core_i.seen_words_q[1] !== 32'h0 ||
        dut.core_i.seen_words_q[2] !== 32'h0 ||
        dut.core_i.seen_words_q[3] !== 32'h0) begin
      $display("tb_cv32e40p_axi_soc_boot_copy: fetched words mismatch");
      $fatal(1);
    end

    $display("tb_cv32e40p_axi_soc_boot_copy: PASS");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $display("tb_cv32e40p_axi_soc_boot_copy: TIMEOUT");
    $fatal(1);
  end

endmodule
