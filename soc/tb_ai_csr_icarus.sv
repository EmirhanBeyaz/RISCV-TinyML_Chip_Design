`timescale 1ns/1ps

module tb_ai_csr_icarus;

  reg clk;
  reg rst_ni;

  reg  [31:0] awaddr;
  reg  [2:0]  awprot;
  reg         awvalid;
  wire        awready;

  reg  [31:0] wdata;
  reg  [3:0]  wstrb;
  reg         wvalid;
  wire        wready;

  wire [1:0]  bresp;
  wire        bvalid;
  reg         bready;

  reg  [31:0] araddr;
  reg  [2:0]  arprot;
  reg         arvalid;
  wire        arready;

  wire [31:0] rdata;
  wire [1:0]  rresp;
  wire        rvalid;
  reg         rready;

  wire        accel_start;
  wire        uart_start;
  wire [31:0] input_base;
  wire [31:0] input_len;
  wire [31:0] output_base;
  wire [15:0] uart_baud_div;

  reg         accel_busy;
  reg         accel_done;
  reg  [1:0]  accel_result_class;
  reg  signed [31:0] accel_result0;
  reg  signed [31:0] accel_result1;
  reg  signed [31:0] accel_result2;
  reg  signed [31:0] accel_result3;
  reg  [31:0] accel_cycle_count;

  reg         uart_active;
  reg         uart_done;
  reg         uart_error;
  reg  [31:0] uart_byte_count;

  wire        irq;

  // Okuma sonucu için global register.
  reg [31:0] rd;
  reg accel_start_seen;

  localparam [31:0] REG_ID           = 32'h00;
  localparam [31:0] REG_CTRL         = 32'h04;
  localparam [31:0] REG_STATUS       = 32'h08;
  localparam [31:0] REG_INPUT_BASE   = 32'h0C;
  localparam [31:0] REG_INPUT_LEN    = 32'h10;
  localparam [31:0] REG_OUTPUT_BASE  = 32'h14;
  localparam [31:0] REG_RESULT_CLASS = 32'h18;
  localparam [31:0] REG_CYCLE_COUNT  = 32'h2C;
  localparam [31:0] REG_IRQ_CLEAR    = 32'h30;
  localparam [31:0] REG_UART_BAUD    = 32'h34;

  soc_ai_csr dut (
      .clk_i(clk),
      .rst_ni(rst_ni),

      .s_axi_awaddr_i(awaddr),
      .s_axi_awprot_i(awprot),
      .s_axi_awvalid_i(awvalid),
      .s_axi_awready_o(awready),

      .s_axi_wdata_i(wdata),
      .s_axi_wstrb_i(wstrb),
      .s_axi_wvalid_i(wvalid),
      .s_axi_wready_o(wready),

      .s_axi_bresp_o(bresp),
      .s_axi_bvalid_o(bvalid),
      .s_axi_bready_i(bready),

      .s_axi_araddr_i(araddr),
      .s_axi_arprot_i(arprot),
      .s_axi_arvalid_i(arvalid),
      .s_axi_arready_o(arready),

      .s_axi_rdata_o(rdata),
      .s_axi_rresp_o(rresp),
      .s_axi_rvalid_o(rvalid),
      .s_axi_rready_i(rready),

      .accel_start_o(accel_start),
      .uart_start_o(uart_start),
      .input_base_o(input_base),
      .input_len_o(input_len),
      .output_base_o(output_base),
      .uart_baud_div_o(uart_baud_div),

      .accel_busy_i(accel_busy),
      .accel_done_i(accel_done),
      .accel_result_class_i(accel_result_class),
      .accel_result0_i(accel_result0),
      .accel_result1_i(accel_result1),
      .accel_result2_i(accel_result2),
      .accel_result3_i(accel_result3),
      .accel_cycle_count_i(accel_cycle_count),

      .uart_active_i(uart_active),
      .uart_done_i(uart_done),
      .uart_error_i(uart_error),
      .uart_byte_count_i(uart_byte_count),

      .irq_o(irq)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!rst_ni) begin
      accel_start_seen <= 1'b0;
    end else if (accel_start) begin
      accel_start_seen <= 1'b1;
    end
  end

  task axi_write;
    input [31:0] addr;
    input [31:0] data;
    integer timeout_cnt;
    begin
      @(posedge clk);

      awaddr  = addr;
      wdata   = data;
      wstrb   = 4'hF;
      awvalid = 1'b1;
      wvalid  = 1'b1;
      bready  = 1'b1;

      timeout_cnt = 0;
      while (!(awready && wready)) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] AXI WRITE ready beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      @(posedge clk);
      awvalid = 1'b0;
      wvalid  = 1'b0;

      timeout_cnt = 0;
      while (!bvalid) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] AXI WRITE response beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      if (bresp != 2'b00) begin
        $display("[ERR] AXI WRITE BRESP error addr=%h bresp=%b", addr, bresp);
      end

      @(posedge clk);
      bready = 1'b0;
    end
  endtask

  task axi_read;
    input  [31:0] addr;
    output [31:0] data;
    integer timeout_cnt;
    begin
      @(posedge clk);

      araddr  = addr;
      arvalid = 1'b1;
      rready  = 1'b1;

      timeout_cnt = 0;
      while (!arready) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] AXI READ ready beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      @(posedge clk);
      arvalid = 1'b0;

      timeout_cnt = 0;
      while (!rvalid) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] AXI READ data beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      data = rdata;

      if (rresp != 2'b00) begin
        $display("[ERR] AXI READ RRESP error addr=%h rresp=%b", addr, rresp);
      end

      @(posedge clk);
      rready = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
  end

  initial begin
    $display("[TB] Simulation started");

    $dumpfile("ai_csr.vcd");
    $dumpvars(0, tb_ai_csr_icarus);

    rst_ni = 1'b0;

    awaddr  = 32'h0;
    awprot  = 3'h0;
    awvalid = 1'b0;

    wdata   = 32'h0;
    wstrb   = 4'h0;
    wvalid  = 1'b0;

    bready  = 1'b0;

    araddr  = 32'h0;
    arprot  = 3'h0;
    arvalid = 1'b0;
    rready  = 1'b0;

    accel_busy = 1'b0;
    accel_done = 1'b0;

    accel_result_class = 2'd2;
    accel_result0 = 32'sd100;
    accel_result1 = 32'sd200;
    accel_result2 = 32'sd300;
    accel_result3 = 32'sd400;
    accel_cycle_count = 32'd12345;

    uart_active = 1'b0;
    uart_done = 1'b0;
    uart_error = 1'b0;
    uart_byte_count = 32'd0;

    repeat (5) @(posedge clk);
    rst_ni = 1'b1;
    repeat (5) @(posedge clk);

    $display("---- AI CSR TEST BASLADI ----");

    axi_read(REG_ID, rd);
    $display("AI ID = %h", rd);

    if (rd !== 32'h4149_4331) begin
      $display("[FAIL] AI ID beklenen degil!");
      $finish;
    end

    axi_read(REG_INPUT_BASE, rd);
    $display("Default INPUT_BASE = %h", rd);

    axi_read(REG_INPUT_LEN, rd);
    $display("Default INPUT_LEN = %0d", rd);

    axi_read(REG_OUTPUT_BASE, rd);
    $display("Default OUTPUT_BASE = %h", rd);

    axi_write(REG_INPUT_BASE, 32'h2000_0000);
    axi_write(REG_INPUT_LEN, 32'd1960);
    axi_write(REG_OUTPUT_BASE, 32'h2000_7000);
    axi_write(REG_UART_BAUD, 32'd50);

    axi_read(REG_UART_BAUD, rd);
    $display("UART_BAUD = %0d", rd);

    // CTRL[0] = accel_start
    // CTRL[1] = irq_enable
    accel_start_seen = 1'b0;
    axi_write(REG_CTRL, 32'h0000_0003);

    if (accel_start_seen !== 1'b1) begin
      $display("[FAIL] accel_start pulse yakalanamadi!");
      $finish;
    end else begin
      $display("accel_start pulse yakalandi.");
    end

    // Donanım inference bitti gibi davranıyoruz.
    accel_done = 1'b1;
    @(posedge clk);
    accel_done = 1'b0;
    repeat (3) @(posedge clk);

    axi_read(REG_STATUS, rd);
    $display("STATUS after done = %h", rd);

    if (rd[1] !== 1'b1) begin
      $display("[FAIL] STATUS done biti 1 olmadi!");
      $finish;
    end

    if (rd[2] !== 1'b1) begin
      $display("[FAIL] IRQ biti 1 olmadi!");
      $finish;
    end

    axi_read(REG_RESULT_CLASS, rd);
    $display("RESULT_CLASS = %0d", rd);

    axi_read(REG_CYCLE_COUNT, rd);
    $display("CYCLE_COUNT = %0d", rd);

    axi_write(REG_IRQ_CLEAR, 32'h1);

    axi_read(REG_STATUS, rd);
    $display("STATUS after clear = %h", rd);

    if (rd[1] !== 1'b0 || rd[2] !== 1'b0) begin
      $display("[FAIL] done/irq clear olmadi!");
      $finish;
    end

    $display("---- AI CSR TEST PASS ----");
    $finish;
  end

  initial begin
    #1000000;
    $display("[TIMEOUT] Simulasyon 1 ms icinde bitmedi.");
    $finish;
  end

endmodule