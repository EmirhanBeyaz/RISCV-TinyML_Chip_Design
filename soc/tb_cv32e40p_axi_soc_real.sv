`timescale 1ns/1ps

module obi_instr_mem #(
    parameter int DEPTH = 8
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        instr_req_i,
    input  logic [31:0] instr_addr_i,
    output logic        instr_gnt_o,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o
);

  import soc_map_pkg::*;

  localparam int FIFO_PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;
  localparam logic [31:0] TEST_DATA_ADDR = SOC_EXT_TEST_BASE_ADDR;
  localparam logic [31:0] STATUS_ADDR    = SOC_EXT_TEST_STATUS_ADDR;

  logic [31:0] addr_fifo[0:DEPTH-1];
  logic [FIFO_PTR_W-1:0] wr_ptr_q;
  logic [FIFO_PTR_W-1:0] rd_ptr_q;
  logic [FIFO_PTR_W:0]   count_q;

  function automatic [31:0] enc_addi(
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input integer imm
  );
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      enc_addi = {imm12, rs1, 3'b000, rd, 7'b0010011};
    end
  endfunction

  function automatic [31:0] enc_lui(
      input logic [4:0] rd,
      input logic [19:0] imm20
  );
    begin
      enc_lui = {imm20, rd, 7'b0110111};
    end
  endfunction

  function automatic [31:0] enc_sw(
      input logic [4:0] rs2,
      input logic [4:0] rs1,
      input integer imm
  );
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      enc_sw = {imm12[11:5], rs2, rs1, 3'b010, imm12[4:0], 7'b0100011};
    end
  endfunction

  function automatic [31:0] enc_lw(
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input integer imm
  );
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      enc_lw = {imm12, rs1, 3'b010, rd, 7'b0000011};
    end
  endfunction

  function automatic [31:0] enc_bne(
      input logic [4:0] rs1,
      input logic [4:0] rs2,
      input integer imm
  );
    logic [12:0] imm13;
    begin
      imm13 = imm[12:0];
      enc_bne = {
          imm13[12], imm13[10:5], rs2, rs1, 3'b001, imm13[4:1], imm13[11], 7'b1100011
      };
    end
  endfunction

  function automatic [31:0] enc_jal(
      input logic [4:0] rd,
      input integer imm
  );
    logic [20:0] imm21;
    begin
      imm21 = imm[20:0];
      enc_jal = {
          imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, 7'b1101111
      };
    end
  endfunction

  function automatic logic [19:0] enc_addr_hi20(input logic [31:0] value);
    begin
      enc_addr_hi20 = (value + 32'h0000_0800) >> 12;
    end
  endfunction

  function automatic integer enc_addr_lo12(input logic [31:0] value);
    logic [11:0] lo12;
    begin
      lo12 = value[11:0];
      if (lo12[11]) begin
        enc_addr_lo12 = $signed({1'b1, lo12}) - 4096;
      end else begin
        enc_addr_lo12 = lo12;
      end
    end
  endfunction

  function automatic [31:0] rom_word(input logic [31:2] word_addr);
    logic [31:2] local_word_addr;
    begin
      if (word_addr >= SOC_QSPI_XIP_BASE_ADDR[31:2]) begin
        local_word_addr = word_addr - SOC_QSPI_XIP_BASE_ADDR[31:2];
      end else begin
        local_word_addr = word_addr;
      end

      unique case (local_word_addr)
        30'd0: rom_word = enc_lui(5'd1, enc_addr_hi20(TEST_DATA_ADDR));
        30'd1: rom_word = enc_addi(5'd1, 5'd1, enc_addr_lo12(TEST_DATA_ADDR));
        30'd2: rom_word = enc_lui(5'd4, enc_addr_hi20(STATUS_ADDR));
        30'd3: rom_word = enc_addi(5'd4, 5'd4, enc_addr_lo12(STATUS_ADDR));
        30'd4: rom_word = enc_lui(5'd2, 20'h12345);
        30'd5: rom_word = enc_addi(5'd2, 5'd2, 12'h678);
        30'd6: rom_word = enc_sw(5'd2, 5'd1, 0);
        30'd7: rom_word = enc_lw(5'd3, 5'd1, 0);
        30'd8: rom_word = enc_bne(5'd2, 5'd3, 16);
        30'd9: rom_word = enc_addi(5'd5, 5'd0, 1);
        30'd10: rom_word = enc_sw(5'd5, 5'd4, 0);
        30'd11: rom_word = enc_jal(5'd0, 0);
        30'd12: rom_word = enc_addi(5'd5, 5'd0, 2);
        30'd13: rom_word = enc_sw(5'd5, 5'd4, 0);
        30'd14: rom_word = enc_jal(5'd0, 0);
        default: rom_word = 32'h00000013;
      endcase
    end
  endfunction

  assign instr_gnt_o = 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_ptr_q       <= '0;
      rd_ptr_q       <= '0;
      count_q        <= '0;
      instr_rvalid_o <= 1'b0;
      instr_rdata_o  <= 32'h00000013;
    end else begin
      instr_rvalid_o <= 1'b0;

      if (instr_req_i && instr_gnt_o && (count_q < DEPTH)) begin
        addr_fifo[wr_ptr_q] <= instr_addr_i;
        wr_ptr_q            <= wr_ptr_q + 1'b1;
        count_q             <= count_q + 1'b1;
      end

      if (count_q != 0) begin
        instr_rvalid_o <= 1'b1;
        instr_rdata_o  <= rom_word(addr_fifo[rd_ptr_q][31:2]);
        rd_ptr_q       <= rd_ptr_q + 1'b1;
        count_q        <= count_q - 1'b1;
      end
    end
  end

endmodule

module tb_cv32e40p_axi_soc_real;

  import soc_map_pkg::*;

  localparam logic [31:0] STATUS_ADDR = SOC_EXT_TEST_STATUS_ADDR;

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

  cv32e40p_axi_soc dut (
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

  obi_instr_mem instr_mem_i (
      .clk_i         (clk),
      .rst_ni        (rst_n),
      .instr_req_i   (instr_req),
      .instr_addr_i  (instr_addr),
      .instr_gnt_o   (instr_gnt),
      .instr_rvalid_o(instr_rvalid),
      .instr_rdata_o (instr_rdata)
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_seen_q  <= 1'b0;
      status_value_q <= 32'h0;
    end else if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready &&
                 (m_axi_awaddr == STATUS_ADDR)) begin
      status_seen_q  <= 1'b1;
      status_value_q <= m_axi_wdata;
    end
  end

  initial begin
    clk               = 1'b0;
    rst_n             = 1'b0;
    fetch_enable      = 1'b0;
    pulp_clock_en     = 1'b1;
    scan_cg_en        = 1'b0;
    boot_addr         = SOC_QSPI_XIP_BASE_ADDR;
    mtvec_addr        = 32'h0;
    dm_halt_addr      = 32'h0;
    hart_id           = 32'h0;
    dm_exception_addr = 32'h0;
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
    repeat (500) begin
      @(posedge clk);
      if (status_seen_q) begin
        if (status_value_q == 32'h1) begin
          $display("tb_cv32e40p_axi_soc_real: PASS");
          $finish;
        end else begin
          $display("tb_cv32e40p_axi_soc_real: FAIL status=%h", status_value_q);
          $fatal(1);
        end
      end
    end

    $display("tb_cv32e40p_axi_soc_real: TIMEOUT");
    $fatal(1);
  end

endmodule
