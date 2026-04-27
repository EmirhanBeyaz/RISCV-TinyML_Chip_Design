`timescale 1ns/1ps

module tb_soc_axi_lite_imem;

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

  logic        imem_req;
  logic        imem_we;
  logic [ 3:0] imem_be;
  logic [31:0] imem_addr;
  logic [31:0] imem_wdata;
  logic        imem_gnt;
  logic        imem_rvalid;
  logic [31:0] imem_rdata;

  soc_axi_lite_imem dut (
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
      .imem_req_o     (imem_req),
      .imem_we_o      (imem_we),
      .imem_be_o      (imem_be),
      .imem_addr_o    (imem_addr),
      .imem_wdata_o   (imem_wdata),
      .imem_gnt_i     (imem_gnt),
      .imem_rvalid_i  (imem_rvalid),
      .imem_rdata_i   (imem_rdata)
  );

  soc_imem imem_i (
      .clk_i         (clk),
      .rst_ni        (rst_n),
      .instr_req_i   (1'b0),
      .instr_addr_i  (32'h0),
      .instr_gnt_o   (),
      .instr_rvalid_o(),
      .instr_rdata_o (),
      .data_req_i    (imem_req),
      .data_we_i     (imem_we),
      .data_be_i     (imem_be),
      .data_addr_i   (imem_addr),
      .data_wdata_i  (imem_wdata),
      .data_gnt_o    (imem_gnt),
      .data_rvalid_o (imem_rvalid),
      .data_rdata_o  (imem_rdata),
      .boot_req_i    (1'b0),
      .boot_we_i     (1'b0),
      .boot_be_i     (4'h0),
      .boot_addr_i   (32'h0),
      .boot_wdata_i  (32'h0),
      .boot_gnt_o    ()
  );

  always #5 clk = ~clk;

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
    int timeout;
    begin
      s_axi_awaddr  = addr;
      s_axi_awprot  = 3'b000;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = strb;
      s_axi_wvalid  = 1'b1;
      s_axi_bready  = 1'b1;

      timeout = 0;
      while (!(s_axi_awready && s_axi_wready)) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI write handshake timeout");
        end
      end

      @(posedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      timeout = 0;
      while (!s_axi_bvalid) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI write response timeout");
        end
      end

      if (s_axi_bresp != 2'b00) begin
        $fatal(1, "AXI write failed resp=%b", s_axi_bresp);
      end

      @(posedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
    int timeout;
    begin
      s_axi_araddr  = addr;
      s_axi_arprot  = 3'b000;
      s_axi_arvalid = 1'b1;
      s_axi_rready  = 1'b1;

      timeout = 0;
      while (!s_axi_arready) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI read address handshake timeout");
        end
      end

      @(posedge clk);
      s_axi_arvalid = 1'b0;

      timeout = 0;
      while (!s_axi_rvalid) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI read data timeout");
        end
      end

      if (s_axi_rresp != 2'b00) begin
        $fatal(1, "AXI read failed resp=%b", s_axi_rresp);
      end
      data = s_axi_rdata;
      @(posedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

  logic [31:0] read_data;

  initial begin
    clk           = 1'b0;
    rst_n         = 1'b0;
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

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    axi_write(SOC_IMEM_BASE_ADDR, 32'hA5A5_5A5A, 4'hF);
    axi_read(SOC_IMEM_BASE_ADDR, read_data);
    if (read_data !== 32'hA5A5_5A5A) begin
      $fatal(1, "IMEM full write/read mismatch %h", read_data);
    end

    axi_write(SOC_IMEM_BASE_ADDR, 32'h1122_3344, 4'b0011);
    axi_read(SOC_IMEM_BASE_ADDR, read_data);
    if (read_data !== 32'hA5A5_3344) begin
      $fatal(1, "IMEM byte write/read mismatch %h", read_data);
    end

    $display("PASS: soc_axi_lite_imem smoke test passed");
    $finish;
  end

endmodule
