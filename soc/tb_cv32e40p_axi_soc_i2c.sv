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

  localparam logic [31:0] I2C_PRESCALE_ADDR = SOC_I2C_BASE_ADDR + 32'h008;
  localparam logic [31:0] I2C_CTRL_ADDR     = SOC_I2C_BASE_ADDR + 32'h00C;
  localparam logic [31:0] I2C_STATUS_ADDR   = SOC_I2C_BASE_ADDR + 32'h010;
  localparam logic [31:0] I2C_TXRX_ADDR     = SOC_I2C_BASE_ADDR + 32'h014;
  localparam logic [31:0] I2C_CMD_ADDR      = SOC_I2C_BASE_ADDR + 32'h018;
  localparam logic [31:0] STATUS_ADDR       = SOC_EXT_TEST_STATUS_ADDR;
  localparam logic [31:0] STATUS_PASS       = 32'h0000_0001;
  localparam logic [31:0] STATUS_FAIL       = 32'h0000_0002;
  localparam logic [31:0] CMD_START_WRITE   = 32'h0000_0005;
  localparam logic [31:0] CMD_WRITE_STOP    = 32'h0000_0006;

  typedef enum logic [4:0] {
    ST_IDLE,
    ST_PRESCALE_REQ,
    ST_PRESCALE_RESP,
    ST_CTRL_REQ,
    ST_CTRL_RESP,
    ST_ADDR_REQ,
    ST_ADDR_RESP,
    ST_CMD0_REQ,
    ST_CMD0_RESP,
    ST_WAIT0,
    ST_STAT0_REQ,
    ST_STAT0_RESP,
    ST_DATA_REQ,
    ST_DATA_RESP,
    ST_CMD1_REQ,
    ST_CMD1_RESP,
    ST_WAIT1,
    ST_STAT1_REQ,
    ST_STAT1_RESP,
    ST_STATUS_REQ,
    ST_STATUS_RESP,
    ST_DONE
  } state_t;

  state_t      state_q;
  logic [7:0]  wait_count_q;
  logic [31:0] status_word_q;

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
      state_q       <= ST_IDLE;
      wait_count_q  <= 8'h0;
      status_word_q <= STATUS_FAIL;
      data_req_o    <= 1'b0;
      data_we_o     <= 1'b0;
      data_be_o     <= 4'h0;
      data_addr_o   <= 32'h0;
      data_wdata_o  <= 32'h0;
    end else begin
      unique case (state_q)
        ST_IDLE: begin
          data_req_o   <= 1'b1;
          data_we_o    <= 1'b1;
          data_be_o    <= 4'hF;
          data_addr_o  <= I2C_PRESCALE_ADDR;
          data_wdata_o <= 32'd2;
          state_q      <= ST_PRESCALE_REQ;
        end

        ST_PRESCALE_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_PRESCALE_RESP;
          end
        end

        ST_PRESCALE_RESP: begin
          if (data_rvalid_i) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hF;
            data_addr_o  <= I2C_CTRL_ADDR;
            data_wdata_o <= 32'h1;
            state_q      <= ST_CTRL_REQ;
          end
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
            data_be_o    <= 4'hF;
            data_addr_o  <= I2C_TXRX_ADDR;
            data_wdata_o <= 32'h0000_00A0;
            state_q      <= ST_ADDR_REQ;
          end
        end

        ST_ADDR_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_ADDR_RESP;
          end
        end

        ST_ADDR_RESP: begin
          if (data_rvalid_i) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hF;
            data_addr_o  <= I2C_CMD_ADDR;
            data_wdata_o <= CMD_START_WRITE;
            state_q      <= ST_CMD0_REQ;
          end
        end

        ST_CMD0_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_CMD0_RESP;
          end
        end

        ST_CMD0_RESP: begin
          if (data_rvalid_i) begin
            wait_count_q <= 8'h0;
            state_q      <= ST_WAIT0;
          end
        end

        ST_WAIT0: begin
          wait_count_q <= wait_count_q + 8'd1;
          if (wait_count_q == 8'd100) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hF;
            data_addr_o  <= I2C_TXRX_ADDR;
            data_wdata_o <= 32'h0000_003C;
            state_q      <= ST_DATA_REQ;
          end
        end

        ST_DATA_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_DATA_RESP;
          end
        end

        ST_DATA_RESP: begin
          if (data_rvalid_i) begin
            data_req_o   <= 1'b1;
            data_we_o    <= 1'b1;
            data_be_o    <= 4'hF;
            data_addr_o  <= I2C_CMD_ADDR;
            data_wdata_o <= CMD_WRITE_STOP;
            state_q      <= ST_CMD1_REQ;
          end
        end

        ST_CMD1_REQ: begin
          if (data_gnt_i) begin
            data_req_o <= 1'b0;
            state_q    <= ST_CMD1_RESP;
          end
        end

        ST_CMD1_RESP: begin
          if (data_rvalid_i) begin
            wait_count_q <= 8'h0;
            state_q      <= ST_WAIT1;
          end
        end

        ST_WAIT1: begin
          wait_count_q <= wait_count_q + 8'd1;
          if (wait_count_q == 8'd100) begin
            status_word_q <= STATUS_PASS;
            state_q       <= ST_DONE;
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

module tb_cv32e40p_axi_soc_i2c;

  import soc_map_pkg::*;

  localparam logic [31:0] STATUS_ADDR = SOC_EXT_TEST_STATUS_ADDR;
  localparam logic [4:0]  CORE_ST_DONE = 5'd21;

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

  logic        slave_sda_drive_low_q;
  integer      scl_toggle_count_q;
  integer      sda_drive_count_q;
  logic        prev_scl_oe_q;
  logic        prev_sda_oe_q;
  integer      ext_write_count_q;
  logic        status_seen_q;
  logic [31:0] status_value_q;
  logic        aw_seen_q;
  logic        w_seen_q;
  logic [31:0] awaddr_q;
  logic [31:0] wdata_q;

  wire i2c_scl_line = i2c_scl_oe_o ? 1'b0 : 1'b1;
  wire i2c_sda_line = (i2c_sda_oe_o ? 1'b0 : 1'b1) &
                      (slave_sda_drive_low_q ? 1'b0 : 1'b1);

  assign i2c_sda_i = i2c_sda_line;

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

  always #5 clk = ~clk;
  always #7 timer_ref_clk = ~timer_ref_clk;

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    fetch_enable      = 1'b1;
    pulp_clock_en     = 1'b1;
    scan_cg_en        = 1'b0;
    boot_addr         = 32'h0;
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
    gpio_in           = 32'h0;
    timer_ref_clk     = 1'b0;
    timer_stoptimer   = 1'b0;
    timer_event_lo    = 1'b0;
    timer_event_hi    = 1'b0;
    qspi_dat_i        = 4'hF;
    slave_sda_drive_low_q = 1'b0;
    scl_toggle_count_q = 0;
    sda_drive_count_q  = 0;
    prev_scl_oe_q      = 1'b0;
    prev_sda_oe_q      = 1'b0;
    ext_write_count_q = 0;
    status_seen_q     = 1'b0;
    status_value_q    = 32'h0;
    aw_seen_q         = 1'b0;
    w_seen_q          = 1'b0;
    awaddr_q          = 32'h0;
    wdata_q           = 32'h0;
    m_axi_awready     = 1'b0;
    m_axi_wready      = 1'b0;
    m_axi_bresp       = 2'b00;
    m_axi_bvalid      = 1'b0;
    m_axi_arready     = 1'b0;
    m_axi_rdata       = 32'h0;
    m_axi_rresp       = 2'b00;
    m_axi_rvalid      = 1'b0;

    repeat (8) @(posedge clk);
    rst_n = 1'b1;

    repeat (500) @(posedge clk);

    if (dut.core_i.state_q !== CORE_ST_DONE) begin
      $display("tb_cv32e40p_axi_soc_i2c: core did not reach done state=%0d i2c_status=%h",
               dut.core_i.state_q, dut.i2c_i.status_word);
      $fatal(1);
    end
    if (dut.core_i.status_word_q !== 32'h1) begin
      $display("tb_cv32e40p_axi_soc_i2c: core reported fail status %h", dut.core_i.status_word_q);
      $fatal(1);
    end
    if (scl_toggle_count_q < 8 || sda_drive_count_q < 2) begin
      $display("tb_cv32e40p_axi_soc_i2c: insufficient i2c line activity scl_toggles=%0d sda_drives=%0d",
               scl_toggle_count_q, sda_drive_count_q);
      $fatal(1);
    end
    $display("tb_cv32e40p_axi_soc_i2c: PASS");
    $finish;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m_axi_awready <= 1'b0;
      m_axi_wready  <= 1'b0;
      m_axi_bvalid  <= 1'b0;
      m_axi_arready <= 1'b0;
      m_axi_rvalid  <= 1'b0;
      m_axi_rdata   <= 32'h0;
      aw_seen_q     <= 1'b0;
      w_seen_q      <= 1'b0;
      awaddr_q      <= 32'h0;
      wdata_q       <= 32'h0;
      prev_scl_oe_q <= 1'b0;
      prev_sda_oe_q <= 1'b0;
      scl_toggle_count_q <= 0;
      sda_drive_count_q  <= 0;
    end else begin
      m_axi_awready <= 1'b0;
      m_axi_wready  <= 1'b0;
      m_axi_arready <= 1'b0;

      if (i2c_scl_oe_o != prev_scl_oe_q) begin
        scl_toggle_count_q <= scl_toggle_count_q + 1;
      end
      if (i2c_sda_oe_o && !prev_sda_oe_q) begin
        sda_drive_count_q <= sda_drive_count_q + 1;
      end
      prev_scl_oe_q <= i2c_scl_oe_o;
      prev_sda_oe_q <= i2c_sda_oe_o;

      if (!aw_seen_q && m_axi_awvalid) begin
        m_axi_awready <= 1'b1;
        aw_seen_q     <= 1'b1;
        awaddr_q      <= m_axi_awaddr;
      end

      if (!w_seen_q && m_axi_wvalid) begin
        m_axi_wready <= 1'b1;
        w_seen_q     <= 1'b1;
        wdata_q      <= m_axi_wdata;
      end

      if (!m_axi_bvalid && aw_seen_q && w_seen_q) begin
        m_axi_bvalid <= 1'b1;
        if (awaddr_q == STATUS_ADDR) begin
          ext_write_count_q <= ext_write_count_q + 1;
          status_seen_q     <= 1'b1;
          status_value_q    <= wdata_q;
        end else begin
          $display("tb_cv32e40p_axi_soc_i2c: unexpected external write %h", awaddr_q);
          $fatal(1);
        end
      end else if (m_axi_bvalid && m_axi_bready) begin
        m_axi_bvalid <= 1'b0;
        aw_seen_q    <= 1'b0;
        w_seen_q     <= 1'b0;
      end

      if (!m_axi_rvalid && m_axi_arvalid) begin
        m_axi_arready <= 1'b1;
        m_axi_rvalid  <= 1'b1;
        m_axi_rdata   <= 32'h0;
      end else if (m_axi_rvalid && m_axi_rready) begin
        m_axi_rvalid <= 1'b0;
      end
    end
  end

endmodule
