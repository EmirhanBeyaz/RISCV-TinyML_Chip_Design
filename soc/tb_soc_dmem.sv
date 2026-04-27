`timescale 1ns/1ps

module tb_soc_dmem;

  import soc_map_pkg::*;

  logic        clk;
  logic        rst_n;
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
  logic [31:0] read_data;

  soc_dmem dut (
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
      .s_axi_rready_i (s_axi_rready)
  );

  always #5 clk = ~clk;

  initial begin
    clk          = 1'b0;
    rst_n        = 1'b0;
    s_axi_awaddr = '0;
    s_axi_awprot = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata  = '0;
    s_axi_wstrb  = '0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b0;
    s_axi_araddr = '0;
    s_axi_arprot = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    axi_write(SOC_DMEM_BASE_ADDR, 32'hDEAD_BEEF, 4'hf);
    axi_read(SOC_DMEM_BASE_ADDR, read_data);
    if (read_data !== 32'hDEAD_BEEF) begin
      $display("tb_soc_dmem: full write/read mismatch %h", read_data);
      $fatal(1);
    end

    axi_write(SOC_DMEM_BASE_ADDR, 32'h00AA_0000, 4'b0100);
    axi_read(SOC_DMEM_BASE_ADDR, read_data);
    if (read_data !== 32'hDEAA_BEEF) begin
      $display("tb_soc_dmem: byte write mismatch %h", read_data);
      $fatal(1);
    end

    $display("tb_soc_dmem: PASS");
    $finish;
  end

  task automatic axi_write(
      input logic [31:0] addr,
      input logic [31:0] data,
      input logic [ 3:0] strb
  );
    begin
      @(posedge clk);
      s_axi_awaddr  = addr;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = strb;
      s_axi_wvalid  = 1'b1;
      s_axi_bready  = 1'b1;

      while (!(s_axi_awready && s_axi_wready)) begin
        @(posedge clk);
      end

      @(posedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      while (!s_axi_bvalid) begin
        @(posedge clk);
      end

      if (s_axi_bresp !== 2'b00) begin
        $display("tb_soc_dmem: write response error %b", s_axi_bresp);
        $fatal(1);
      end

      @(posedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_read(
      input logic [31:0] addr,
      output logic [31:0] data
  );
    begin
      @(posedge clk);
      s_axi_araddr  = addr;
      s_axi_arvalid = 1'b1;
      s_axi_rready  = 1'b1;

      while (!s_axi_arready) begin
        @(posedge clk);
      end

      @(posedge clk);
      s_axi_arvalid = 1'b0;

      while (!s_axi_rvalid) begin
        @(posedge clk);
      end

      if (s_axi_rresp !== 2'b00) begin
        $display("tb_soc_dmem: read response error %b", s_axi_rresp);
        $fatal(1);
      end

      data = s_axi_rdata;
      @(posedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
