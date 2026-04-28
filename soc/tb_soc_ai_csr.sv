`timescale 1ns/1ps

module tb_soc_ai_csr;

  import soc_map_pkg::*;

  localparam logic [31:0] REG_ID           = 32'h00;
  localparam logic [31:0] REG_CTRL         = 32'h04;
  localparam logic [31:0] REG_STATUS       = 32'h08;
  localparam logic [31:0] REG_INPUT_LEN    = 32'h10;
  localparam logic [31:0] REG_RESULT_CLASS = 32'h18;
  localparam logic [31:0] REG_RESULT0      = 32'h1c;
  localparam logic [31:0] REG_CYCLE_COUNT  = 32'h2c;
  localparam logic [31:0] REG_IRQ_CLEAR    = 32'h30;
  localparam logic [31:0] REG_UART_COUNT   = 32'h38;

  logic clk;
  logic rst_n;
  logic [31:0] awaddr;
  logic [2:0]  awprot;
  logic        awvalid;
  logic        awready;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;
  logic [31:0] araddr;
  logic [2:0]  arprot;
  logic        arvalid;
  logic        arready;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;
  logic        accel_start;
  logic        uart_start;
  logic [31:0] input_base;
  logic [31:0] input_len;
  logic [31:0] output_base;
  logic [15:0] uart_baud_div;
  logic        accel_busy;
  logic        accel_done;
  logic [1:0]  accel_result_class;
  logic signed [31:0] accel_result0;
  logic signed [31:0] accel_result1;
  logic signed [31:0] accel_result2;
  logic signed [31:0] accel_result3;
  logic [31:0] accel_cycle_count;
  logic        uart_active;
  logic        uart_done;
  logic        uart_error;
  logic [31:0] uart_byte_count;
  logic        irq;
  logic        start_seen;
  logic        uart_start_seen;
  logic [31:0] read_data;

  soc_ai_csr dut (
      .clk_i                (clk),
      .rst_ni               (rst_n),
      .s_axi_awaddr_i       (awaddr),
      .s_axi_awprot_i       (awprot),
      .s_axi_awvalid_i      (awvalid),
      .s_axi_awready_o      (awready),
      .s_axi_wdata_i        (wdata),
      .s_axi_wstrb_i        (wstrb),
      .s_axi_wvalid_i       (wvalid),
      .s_axi_wready_o       (wready),
      .s_axi_bresp_o        (bresp),
      .s_axi_bvalid_o       (bvalid),
      .s_axi_bready_i       (bready),
      .s_axi_araddr_i       (araddr),
      .s_axi_arprot_i       (arprot),
      .s_axi_arvalid_i      (arvalid),
      .s_axi_arready_o      (arready),
      .s_axi_rdata_o        (rdata),
      .s_axi_rresp_o        (rresp),
      .s_axi_rvalid_o       (rvalid),
      .s_axi_rready_i       (rready),
      .accel_start_o        (accel_start),
      .uart_start_o         (uart_start),
      .input_base_o         (input_base),
      .input_len_o          (input_len),
      .output_base_o        (output_base),
      .uart_baud_div_o      (uart_baud_div),
      .accel_busy_i         (accel_busy),
      .accel_done_i         (accel_done),
      .accel_result_class_i (accel_result_class),
      .accel_result0_i      (accel_result0),
      .accel_result1_i      (accel_result1),
      .accel_result2_i      (accel_result2),
      .accel_result3_i      (accel_result3),
      .accel_cycle_count_i  (accel_cycle_count),
      .uart_active_i        (uart_active),
      .uart_done_i          (uart_done),
      .uart_error_i         (uart_error),
      .uart_byte_count_i    (uart_byte_count),
      .irq_o                (irq)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (accel_start) start_seen <= 1'b1;
    if (uart_start) uart_start_seen <= 1'b1;
  end

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    awaddr = '0;
    awprot = '0;
    awvalid = 1'b0;
    wdata = '0;
    wstrb = '0;
    wvalid = 1'b0;
    bready = 1'b0;
    araddr = '0;
    arprot = '0;
    arvalid = 1'b0;
    rready = 1'b0;
    accel_busy = 1'b0;
    accel_done = 1'b0;
    accel_result_class = 2'd2;
    accel_result0 = 32'sd11;
    accel_result1 = -32'sd5;
    accel_result2 = 32'sd99;
    accel_result3 = 32'sd3;
    accel_cycle_count = 32'd1234;
    uart_active = 1'b0;
    uart_done = 1'b0;
    uart_error = 1'b0;
    uart_byte_count = 32'd1960;
    start_seen = 1'b0;
    uart_start_seen = 1'b0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    axi_read(SOC_AI_CSR_BASE_ADDR + REG_ID, read_data);
    check_eq(read_data, 32'h4149_4331, "ID");

    axi_write(SOC_AI_CSR_BASE_ADDR + REG_INPUT_LEN, 32'd4);
    check_eq(input_len, 32'd4, "input_len output");

    axi_write(SOC_AI_CSR_BASE_ADDR + REG_CTRL, 32'h0000_0007);
    repeat (2) @(posedge clk);
    if (!start_seen || !uart_start_seen) begin
      $display("tb_soc_ai_csr: start pulses missing");
      $fatal(1);
    end

    accel_done = 1'b1;
    @(posedge clk);
    accel_done = 1'b0;
    @(posedge clk);

    axi_read(SOC_AI_CSR_BASE_ADDR + REG_STATUS, read_data);
    if (read_data[2:1] !== 2'b11 || !irq) begin
      $display("tb_soc_ai_csr: done/irq status bad status=%h irq=%b", read_data, irq);
      $fatal(1);
    end

    axi_read(SOC_AI_CSR_BASE_ADDR + REG_RESULT_CLASS, read_data);
    check_eq(read_data, 32'd2, "result class");
    axi_read(SOC_AI_CSR_BASE_ADDR + REG_RESULT0, read_data);
    check_eq(read_data, 32'd11, "result0");
    axi_read(SOC_AI_CSR_BASE_ADDR + REG_CYCLE_COUNT, read_data);
    check_eq(read_data, 32'd1234, "cycle count");
    axi_read(SOC_AI_CSR_BASE_ADDR + REG_UART_COUNT, read_data);
    check_eq(read_data, 32'd1960, "uart count");

    axi_write(SOC_AI_CSR_BASE_ADDR + REG_IRQ_CLEAR, 32'h1);
    @(posedge clk);
    if (irq) begin
      $display("tb_soc_ai_csr: irq did not clear");
      $fatal(1);
    end

    $display("tb_soc_ai_csr: PASS");
    $finish;
  end

  task automatic check_eq(input logic [31:0] got, input logic [31:0] exp, input string what);
    begin
      if (got !== exp) begin
        $display("tb_soc_ai_csr: %s mismatch got=%h exp=%h", what, got, exp);
        $fatal(1);
      end
    end
  endtask

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    begin
      @(posedge clk);
      awaddr = addr;
      awvalid = 1'b1;
      wdata = data;
      wstrb = 4'hf;
      wvalid = 1'b1;
      bready = 1'b1;
      while (!(awready && wready)) @(posedge clk);
      @(posedge clk);
      awvalid = 1'b0;
      wvalid = 1'b0;
      while (!bvalid) @(posedge clk);
      if (bresp !== 2'b00) $fatal(1, "tb_soc_ai_csr: AXI write error at %h", addr);
      @(posedge clk);
      bready = 1'b0;
    end
  endtask

  task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
    begin
      @(posedge clk);
      araddr = addr;
      arvalid = 1'b1;
      rready = 1'b1;
      while (!arready) @(posedge clk);
      @(posedge clk);
      arvalid = 1'b0;
      while (!rvalid) @(posedge clk);
      if (rresp !== 2'b00) $fatal(1, "tb_soc_ai_csr: AXI read error at %h", addr);
      data = rdata;
      @(posedge clk);
      rready = 1'b0;
    end
  endtask

endmodule
