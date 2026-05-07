`timescale 1ns/1ps

module tb_uart_icarus;

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

  reg         uart_rx;
  wire        uart_tx;

  reg [31:0] rd;

  localparam [31:0] REG_CTRL   = 32'h00;
  localparam [31:0] REG_STATUS = 32'h04;
  localparam [31:0] REG_RXDATA = 32'h08;
  localparam [31:0] REG_TXDATA = 32'h0C;

  localparam [15:0] BAUD_DIV_SIM = 16'd8;

  soc_axi_lite_uart dut (
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

      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx)
  );

  always #5 clk = ~clk;

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
        $display("[ERR] AXI WRITE BRESP error addr=%h data=%h bresp=%b", addr, data, bresp);
        $finish;
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
        $finish;
      end

      @(posedge clk);
      rready = 1'b0;
    end
  endtask

  task wait_uart_start_bit;
    integer timeout_cnt;
    begin
      timeout_cnt = 0;

      while (uart_tx !== 1'b0) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;

        if (timeout_cnt > 1000) begin
          $display("[FAIL] UART TX start bit gorulmedi.");
          $finish;
        end
      end

      $display("UART TX start bit goruldu.");
    end
  endtask

  task wait_uart_idle;
    integer i;
    begin
      for (i = 0; i < (BAUD_DIV_SIM * 20); i = i + 1) begin
        @(posedge clk);
      end

      if (uart_tx !== 1'b1) begin
        $display("[FAIL] UART TX frame sonunda idle 1 olmadi. uart_tx=%b", uart_tx);
        $finish;
      end

      $display("UART TX frame tamamlandi ve idle'a dondu.");
    end
  endtask

  initial begin
    clk = 1'b0;
  end

  initial begin
    $display("[TB] UART simulation started");

    $dumpfile("uart.vcd");
    $dumpvars(0, tb_uart_icarus);

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

    uart_rx = 1'b1;

    repeat (5) @(posedge clk);
    rst_ni = 1'b1;
    repeat (5) @(posedge clk);

    $display("---- UART TEST BASLADI ----");

    axi_read(REG_STATUS, rd);
    $display("Initial STATUS = %h", rd);

    axi_write(REG_CTRL, {BAUD_DIV_SIM, 14'b0, 1'b1, 1'b1});

    axi_read(REG_CTRL, rd);
    $display("CTRL after init = %h", rd);

    if (rd[0] !== 1'b1 || rd[1] !== 1'b1 || rd[31:16] !== BAUD_DIV_SIM) begin
      $display("[FAIL] UART CTRL beklenen degerde degil.");
      $finish;
    end

    $display("TXDATA'ya 0x55 yaziliyor...");
    axi_write(REG_TXDATA, 32'h0000_0055);

    wait_uart_start_bit();
    wait_uart_idle();

    axi_read(REG_STATUS, rd);
    $display("Final STATUS = %h", rd);

    $display("---- UART TEST PASS ----");
    $finish;
  end

  initial begin
    #2000000;
    $display("[TIMEOUT] UART simulasyonu 2 ms icinde bitmedi.");
    $finish;
  end

endmodule
