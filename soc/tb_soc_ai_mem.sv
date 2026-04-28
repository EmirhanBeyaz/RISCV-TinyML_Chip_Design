`timescale 1ns/1ps

module tb_soc_ai_mem;

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
  logic        ai_req;
  logic        ai_we;
  logic [ 3:0] ai_be;
  logic [31:0] ai_addr;
  logic [31:0] ai_wdata;
  logic        ai_gnt;
  logic        ai_rvalid;
  logic [31:0] ai_rdata;
  logic [31:0] read_data;

  soc_ai_mem dut (
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
      .ai_req_i       (ai_req),
      .ai_we_i        (ai_we),
      .ai_be_i        (ai_be),
      .ai_addr_i      (ai_addr),
      .ai_wdata_i     (ai_wdata),
      .ai_gnt_o       (ai_gnt),
      .ai_rvalid_o    (ai_rvalid),
      .ai_rdata_o     (ai_rdata)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    s_axi_awaddr = '0;
    s_axi_awprot = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = '0;
    s_axi_wstrb = '0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b0;
    s_axi_araddr = '0;
    s_axi_arprot = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b0;
    ai_req = 1'b0;
    ai_we = 1'b0;
    ai_be = '0;
    ai_addr = '0;
    ai_wdata = '0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    axi_write(SOC_AI_MEM_BASE_ADDR, 32'h1122_3344, 4'hf);
    axi_read(SOC_AI_MEM_BASE_ADDR, read_data);
    check_eq(read_data, 32'h1122_3344, "cpu full write/read");

    ai_write(SOC_AI_MEM_BASE_ADDR + 32'd3, 32'haa00_0000, 4'b1000);
    axi_read(SOC_AI_MEM_BASE_ADDR, read_data);
    check_eq(read_data, 32'haa22_3344, "ai byte write");

    ai_read(SOC_AI_MEM_BASE_ADDR, read_data);
    check_eq(read_data, 32'haa22_3344, "ai readback");

    $display("tb_soc_ai_mem: PASS");
    $finish;
  end

  task automatic check_eq(input logic [31:0] got, input logic [31:0] exp, input string what);
    begin
      if (got !== exp) begin
        $display("tb_soc_ai_mem: %s mismatch got=%h exp=%h", what, got, exp);
        $fatal(1);
      end
    end
  endtask

  task automatic ai_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] be);
    begin
      @(posedge clk);
      ai_addr = addr;
      ai_wdata = data;
      ai_be = be;
      ai_we = 1'b1;
      ai_req = 1'b1;
      while (!ai_gnt) @(posedge clk);
      @(posedge clk);
      ai_req = 1'b0;
      ai_we = 1'b0;
      ai_be = '0;
      ai_wdata = '0;
    end
  endtask

  task automatic ai_read(input logic [31:0] addr, output logic [31:0] data);
    begin
      @(posedge clk);
      ai_addr = addr;
      ai_we = 1'b0;
      ai_req = 1'b1;
      while (!ai_gnt) @(posedge clk);
      @(posedge clk);
      ai_req = 1'b0;
      while (!ai_rvalid) @(posedge clk);
      data = ai_rdata;
    end
  endtask

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
    begin
      @(posedge clk);
      s_axi_awaddr = addr;
      s_axi_awvalid = 1'b1;
      s_axi_wdata = data;
      s_axi_wstrb = strb;
      s_axi_wvalid = 1'b1;
      s_axi_bready = 1'b1;
      while (!(s_axi_awready && s_axi_wready)) @(posedge clk);
      @(posedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      while (!s_axi_bvalid) @(posedge clk);
      if (s_axi_bresp !== 2'b00) $fatal(1, "tb_soc_ai_mem: AXI write error");
      @(posedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
    begin
      @(posedge clk);
      s_axi_araddr = addr;
      s_axi_arvalid = 1'b1;
      s_axi_rready = 1'b1;
      while (!s_axi_arready) @(posedge clk);
      @(posedge clk);
      s_axi_arvalid = 1'b0;
      while (!s_axi_rvalid) @(posedge clk);
      if (s_axi_rresp !== 2'b00) $fatal(1, "tb_soc_ai_mem: AXI read error");
      data = s_axi_rdata;
      @(posedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
