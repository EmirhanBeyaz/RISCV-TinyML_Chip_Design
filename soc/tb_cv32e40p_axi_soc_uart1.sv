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

  import soc_map_pkg::*;

  localparam logic [31:0] UART_CTRL_ADDR = SOC_UART1_BASE_ADDR + 32'h0;
  localparam logic [31:0] UART_TX_ADDR   = SOC_UART1_BASE_ADDR + 32'hc;
  localparam logic [31:0] STATUS_ADDR    = SOC_EXT_TEST_STATUS_ADDR;
  localparam logic [31:0] UART_CTRL_VAL  = 32'h0000_0003;
  localparam logic [31:0] STATUS_VAL     = 32'h0000_0001;
  localparam logic [7:0]  TEST_TX_BYTE   = 8'ha6;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_CTRL_REQ,
    ST_CTRL_RESP,
    ST_TX_REQ,
    ST_TX_RESP,
    ST_STATUS_REQ,
    ST_STATUS_RESP,
    ST_DONE
  } state_t;

  state_t state_q;

  assign instr_req_o       = 1'b0;
  assign instr_addr_o      = 32'h0;
  assign irq_ack_o         = 1'b0;
  assign irq_id_o          = 5'h0;
  assign debug_havereset_o = 1'b0;
  assign debug_running_o   = 1'b1;
  assign debug_halted_o    = 1'b0;
  assign core_sleep_o      = 1'b0;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= ST_IDLE;
      data_req_o   <= 1'b0;
      data_we_o    <= 1'b0;
      data_be_o    <= 4'h0;
      data_addr_o  <= 32'h0;
      data_wdata_o <= 32'h0;
    end else begin
      unique case (state_q)
        ST_IDLE: begin
          data_req_o   <= 1'b1;
          data_we_o    <= 1'b1;
          data_be_o    <= 4'hf;
          data_addr_o  <= UART_CTRL_ADDR;
          data_wdata_o <= UART_CTRL_VAL;
          state_q      <= ST_CTRL_REQ;
        end

        ST_CTRL_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_CTRL_RESP;
          end
        end

        ST_CTRL_RESP: begin
          if (data_rvalid_i) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hf;
            data_addr_o  <= UART_TX_ADDR;
            data_wdata_o <= {24'h0, TEST_TX_BYTE};
            state_q      <= ST_TX_REQ;
          end
        end

        ST_TX_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_TX_RESP;
          end
        end

        ST_TX_RESP: begin
          if (data_rvalid_i) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hf;
            data_addr_o  <= STATUS_ADDR;
            data_wdata_o <= STATUS_VAL;
            state_q      <= ST_STATUS_REQ;
          end
        end

        ST_STATUS_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_STATUS_RESP;
          end
        end

        ST_STATUS_RESP: begin
          if (data_rvalid_i) begin
            state_q <= ST_DONE;
          end
        end

        ST_DONE: begin
          data_req_o <= 1'b0;
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule

module tb_cv32e40p_axi_soc_uart1;

  import soc_map_pkg::*;

  localparam logic [31:0] STATUS_ADDR  = SOC_EXT_TEST_STATUS_ADDR;
  localparam logic [7:0]  TEST_TX_BYTE = 8'ha6;

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

  integer ext_write_count_q;
  logic   status_seen_q;
  logic   tx_seen_q;

  cv32e40p_axi_soc #(
      .QSPI_INIT_ENABLE(1'b0)
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
      .WORDS(64)
  ) ram_i (
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

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ext_write_count_q <= 0;
      status_seen_q     <= 1'b0;
    end else if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) begin
      ext_write_count_q <= ext_write_count_q + 1;

      if (m_axi_awaddr !== STATUS_ADDR) begin
        $display("tb_cv32e40p_axi_soc_uart1: unexpected external write %h", m_axi_awaddr);
        $fatal(1);
      end

      status_seen_q <= 1'b1;
    end
  end

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    fetch_enable      = 1'b1;
    pulp_clock_en     = 1'b0;
    scan_cg_en        = 1'b0;
    boot_addr         = SOC_QSPI_XIP_BASE_ADDR;
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
    tx_seen_q         = 1'b0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
  end

  initial begin
    wait (rst_n === 1'b1);
    wait (dut.uart1_i.tx_we_q === 1'b1);
    wait_for_tx_byte(TEST_TX_BYTE);
    tx_seen_q = 1'b1;
  end

  initial begin
    repeat (300) begin
      @(posedge clk);
      if (status_seen_q && tx_seen_q) begin
        if (ext_write_count_q !== 1) begin
          $display("tb_cv32e40p_axi_soc_uart1: external write count mismatch %0d", ext_write_count_q);
          $fatal(1);
        end

        $display("tb_cv32e40p_axi_soc_uart1: PASS");
        $finish;
      end
    end

    $display("tb_cv32e40p_axi_soc_uart1: TIMEOUT");
    $fatal(1);
  end

  task automatic wait_for_tx_byte(input logic [7:0] exp_data);
    logic [7:0] seen_data;
    integer bit_idx;
    begin
      seen_data = '0;

      while (uart1_tx !== 1'b0) @(negedge clk);

      for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
        @(negedge clk);
        seen_data[bit_idx] = uart1_tx;
      end

      @(negedge clk);
      if (uart1_tx !== 1'b1) begin
        $display("tb_cv32e40p_axi_soc_uart1: TX stop bit missing");
        $fatal(1);
      end

      if (seen_data !== exp_data) begin
        $display("tb_cv32e40p_axi_soc_uart1: TX byte mismatch %h != %h", seen_data, exp_data);
        $fatal(1);
      end
    end
  endtask

endmodule
