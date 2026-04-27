`timescale 1ns/1ps

module tb_soc_axi_lite_uart;

  import soc_map_pkg::*;

  localparam logic [31:0] REG_CTRL   = 32'h000;
  localparam logic [31:0] REG_STATUS = 32'h004;
  localparam logic [31:0] REG_RXDATA = 32'h008;
  localparam logic [31:0] REG_TXDATA = 32'h00c;

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

  logic uart_rx;
  logic uart_tx;

  soc_axi_lite_uart dut (
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
      .uart_rx_i      (uart_rx),
      .uart_tx_o      (uart_tx)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    uart_rx = 1'b1;

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

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    axi_check_read(SOC_UART0_BASE_ADDR + REG_STATUS, 32'h0000_000a);

    axi_write(SOC_UART0_BASE_ADDR + REG_CTRL, 32'h0000_0003);
    axi_check_read(SOC_UART0_BASE_ADDR + REG_CTRL, 32'h0000_0003);

    axi_write(SOC_UART0_BASE_ADDR + REG_TXDATA, 32'h0000_0055);
    wait_for_tx_byte(8'h55);

    inject_rx_byte(8'ha6);
    axi_check_read(SOC_UART0_BASE_ADDR + REG_STATUS, 32'h0000_0002);
    axi_check_read(SOC_UART0_BASE_ADDR + REG_RXDATA, 32'h0000_00a6);
    axi_check_read(SOC_UART0_BASE_ADDR + REG_STATUS, 32'h0000_000a);

    $display("tb_soc_axi_lite_uart: PASS");
    $finish;
  end

  initial begin
    #10000;
    $display("tb_soc_axi_lite_uart: TIMEOUT");
    $fatal(1);
  end

  task automatic wait_for_tx_byte(input logic [7:0] exp_data);
    logic [7:0] seen_data;
    integer bit_idx;
    begin
      seen_data = '0;

      while (uart_tx !== 1'b0) @(negedge clk);

      for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
        @(negedge clk);
        seen_data[bit_idx] = uart_tx;
      end

      @(negedge clk);
      if (uart_tx !== 1'b1) begin
        $display("tb_soc_axi_lite_uart: TX stop bit missing");
        $fatal(1);
      end

      if (seen_data !== exp_data) begin
        $display("tb_soc_axi_lite_uart: TX byte mismatch %h != %h", seen_data, exp_data);
        $fatal(1);
      end
    end
  endtask

  task automatic inject_rx_byte(input logic [7:0] data);
    begin
      @(negedge clk);
      dut.uart_rx_i_dut.queue[0] = data;
      dut.uart_rx_i_dut.write_ptr = 5'd1;
      dut.uart_rx_i_dut.read_ptr = 5'd0;
    end
  endtask

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    begin
      s_axi_awaddr  = addr;
      s_axi_awprot  = 3'b000;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = 4'hf;
      s_axi_wvalid  = 1'b1;

      wait (s_axi_awready && s_axi_wready);
      @(posedge clk);
      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      s_axi_bready = 1'b1;
      while (!s_axi_bvalid) @(posedge clk);
      if (s_axi_bresp !== 2'b00) begin
        $display("tb_soc_axi_lite_uart: write response error %b at %h", s_axi_bresp, addr);
        $fatal(1);
      end
      while (s_axi_bvalid) @(posedge clk);
      @(negedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_check_read(input logic [31:0] addr, input logic [31:0] exp_data);
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
        $display("tb_soc_axi_lite_uart: read response error %b at %h", s_axi_rresp, addr);
        $fatal(1);
      end

      if (s_axi_rdata !== exp_data) begin
        $display("tb_soc_axi_lite_uart: readback mismatch %h != %h at %h",
                 s_axi_rdata, exp_data, addr);
        $fatal(1);
      end

      while (s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
