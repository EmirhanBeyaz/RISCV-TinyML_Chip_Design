`timescale 1ns/1ps

module tb_soc_axi_lite_apb_i2c_master;

  import soc_map_pkg::*;

  localparam logic [11:0] REG_ID       = 12'h000;
  localparam logic [11:0] REG_VERSION  = 12'h004;
  localparam logic [11:0] REG_PRESCALE = 12'h008;
  localparam logic [11:0] REG_CTRL     = 12'h00C;
  localparam logic [11:0] REG_STATUS   = 12'h010;
  localparam logic [11:0] REG_TXRX     = 12'h014;
  localparam logic [11:0] REG_CMD      = 12'h018;

  localparam logic [31:0] CMD_START_WRITE     = 32'h0000_0005;
  localparam logic [31:0] CMD_WRITE_STOP      = 32'h0000_0006;
  localparam logic [31:0] CMD_START_READ_STOP = 32'h0000_001B;

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

  logic [31:0] i2c_prdata;
  logic        i2c_pready;
  logic        i2c_pslverr;
  logic        i2c_scl_o;
  logic        i2c_scl_oe_o;
  logic        i2c_sda_o;
  logic        i2c_sda_oe_o;
  logic        i2c_sda_i;
  logic        slave_sda_drive_low_q;
  logic        slave_done_q;
  logic [7:0]  slave_byte0_q;
  logic [7:0]  slave_byte1_q;

  wire i2c_scl_line = i2c_scl_oe_o ? 1'b0 : 1'b1;
  wire i2c_sda_line = (i2c_sda_oe_o ? 1'b0 : 1'b1) &
                      (slave_sda_drive_low_q ? 1'b0 : 1'b1);

  assign i2c_sda_i = i2c_sda_line;

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

  soc_apb_i2c_master i2c_i (
      .clk_i        (clk),
      .rst_ni       (rst_n),
      .paddr_i      (apb_paddr[11:0]),
      .pwdata_i     (apb_pwdata),
      .pwrite_i     (apb_pwrite),
      .psel_i       (apb_psel[SOC_MMIO_I2C]),
      .penable_i    (apb_penable),
      .prdata_o     (i2c_prdata),
      .pready_o     (i2c_pready),
      .pslverr_o    (i2c_pslverr),
      .i2c_sda_i    (i2c_sda_i),
      .i2c_scl_o    (i2c_scl_o),
      .i2c_scl_oe_o (i2c_scl_oe_o),
      .i2c_sda_o    (i2c_sda_o),
      .i2c_sda_oe_o (i2c_sda_oe_o)
  );

  integer idx;

  always_comb begin
    for (idx = 0; idx < SOC_MMIO_SLOT_COUNT; idx = idx + 1) begin
      apb_prdata[idx]  = '0;
      apb_pready[idx]  = 1'b1;
      apb_pslverr[idx] = 1'b1;
    end

    apb_prdata[SOC_MMIO_I2C]  = i2c_prdata;
    apb_pready[SOC_MMIO_I2C]  = i2c_pready;
    apb_pslverr[SOC_MMIO_I2C] = i2c_pslverr;
  end

  always #5 clk = ~clk;

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
    slave_sda_drive_low_q = 1'b0;
    slave_done_q = 1'b0;
    slave_byte0_q = 8'h00;
    slave_byte1_q = 8'h00;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    axi_check_read(SOC_I2C_BASE_ADDR + REG_ID, 32'h4932_434D);
    axi_check_read(SOC_I2C_BASE_ADDR + REG_VERSION, 32'h0001_0000);

    axi_write(SOC_I2C_BASE_ADDR + REG_PRESCALE, 32'd2);
    axi_write(SOC_I2C_BASE_ADDR + REG_CTRL, 32'h1);

    axi_write(SOC_I2C_BASE_ADDR + REG_TXRX, 32'h0000_00A0);
    axi_write(SOC_I2C_BASE_ADDR + REG_CMD, CMD_START_WRITE);
    axi_wait_done();
    axi_expect_status_bits(32'h0000_0004, 32'h0);

    axi_write(SOC_I2C_BASE_ADDR + REG_TXRX, 32'h0000_003C);
    axi_write(SOC_I2C_BASE_ADDR + REG_CMD, CMD_WRITE_STOP);
    axi_wait_done();
    axi_expect_status_bits(32'h0000_0004, 32'h0);

    axi_write(SOC_I2C_BASE_ADDR + REG_CMD, CMD_START_READ_STOP);
    axi_wait_done();
    axi_expect_status_bits(32'h0000_000C, 32'h0000_0008);
    axi_check_read(SOC_I2C_BASE_ADDR + REG_TXRX, 32'h0000_005A);

    if (!slave_done_q) begin
      $display("tb_soc_axi_lite_apb_i2c_master: slave sequence did not complete");
      $fatal(1);
    end
    if (slave_byte0_q !== 8'hA0 || slave_byte1_q !== 8'h3C) begin
      $display("tb_soc_axi_lite_apb_i2c_master: captured bytes mismatch %02x %02x",
               slave_byte0_q, slave_byte1_q);
      $fatal(1);
    end

    $display("tb_soc_axi_lite_apb_i2c_master: PASS");
    $finish;
  end

  initial begin
    @(posedge rst_n);
    slave_sequence();
  end

  task automatic slave_wait_start;
    bit start_seen;
    begin
      start_seen = 1'b0;
      while (!start_seen) begin
        @(negedge i2c_sda_line);
        if (i2c_scl_line === 1'b1) begin
          start_seen = 1'b1;
        end
      end
    end
  endtask

  task automatic slave_wait_stop;
    bit stop_seen;
    begin
      stop_seen = 1'b0;
      while (!stop_seen) begin
        @(posedge i2c_sda_line);
        if (i2c_scl_line === 1'b1) begin
          stop_seen = 1'b1;
        end
      end
    end
  endtask

  task automatic slave_recv_byte(output logic [7:0] value);
    integer bit_idx;
    begin
      value = 8'h00;
      for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
        @(posedge i2c_scl_line);
        value[bit_idx] = i2c_sda_line;
        @(negedge i2c_scl_line);
      end
    end
  endtask

  task automatic slave_send_ack;
    begin
      slave_sda_drive_low_q = 1'b1;
      @(posedge i2c_scl_line);
      @(negedge i2c_scl_line);
      slave_sda_drive_low_q = 1'b0;
    end
  endtask

  task automatic slave_send_byte(input logic [7:0] value);
    integer bit_idx;
    begin
      @(negedge i2c_scl_line);
      slave_sda_drive_low_q = ~value[7];
      for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
        @(posedge i2c_scl_line);
        @(negedge i2c_scl_line);
        if (bit_idx > 0) begin
          slave_sda_drive_low_q = ~value[bit_idx-1];
        end
      end
      slave_sda_drive_low_q = 1'b0;
    end
  endtask

  task automatic slave_expect_master_nack;
    begin
      @(posedge i2c_scl_line);
      if (i2c_sda_line !== 1'b1) begin
        $display("tb_soc_axi_lite_apb_i2c_master: expected master NACK, saw %b", i2c_sda_line);
        $fatal(1);
      end
      @(negedge i2c_scl_line);
    end
  endtask

  task automatic slave_sequence;
    logic [7:0] value;
    begin
      slave_wait_start();
      slave_recv_byte(value);
      slave_byte0_q = value;
      slave_send_ack();
      slave_recv_byte(value);
      slave_byte1_q = value;
      slave_send_ack();
      slave_wait_stop();

      slave_wait_start();
      slave_send_byte(8'h5A);
      slave_expect_master_nack();
      slave_wait_stop();
      slave_done_q = 1'b1;
    end
  endtask

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
        $display("tb_soc_axi_lite_apb_i2c_master: write response error %b at %h", s_axi_bresp, addr);
        $fatal(1);
      end
      while (s_axi_bvalid) @(posedge clk);
      @(negedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
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
        $display("tb_soc_axi_lite_apb_i2c_master: read response error %b at %h", s_axi_rresp, addr);
        $fatal(1);
      end
      data = s_axi_rdata;
      while (s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

  task automatic axi_check_read(input logic [31:0] addr, input logic [31:0] exp_data);
    logic [31:0] rd_data;
    begin
      axi_read(addr, rd_data);
      if (rd_data !== exp_data) begin
        $display("tb_soc_axi_lite_apb_i2c_master: read mismatch addr=%h exp=%h got=%h",
                 addr, exp_data, rd_data);
        $fatal(1);
      end
    end
  endtask

  task automatic axi_wait_done;
    logic [31:0] rd_data;
    integer poll_idx;
    bit done_seen;
    begin
      done_seen = 1'b0;
      for (poll_idx = 0; poll_idx < 200; poll_idx = poll_idx + 1) begin
        axi_read(SOC_I2C_BASE_ADDR + REG_STATUS, rd_data);
        if (rd_data[1]) begin
          done_seen = 1'b1;
          poll_idx = 200;
        end
      end
      if (!done_seen) begin
        $display("tb_soc_axi_lite_apb_i2c_master: command done timeout");
        $fatal(1);
      end
    end
  endtask

  task automatic axi_expect_status_bits(
      input logic [31:0] mask,
      input logic [31:0] exp_value
  );
    logic [31:0] rd_data;
    begin
      axi_read(SOC_I2C_BASE_ADDR + REG_STATUS, rd_data);
      if ((rd_data & mask) !== exp_value) begin
        $display("tb_soc_axi_lite_apb_i2c_master: status mismatch mask=%h exp=%h got=%h",
                 mask, exp_value, rd_data);
        $fatal(1);
      end
    end
  endtask

endmodule
