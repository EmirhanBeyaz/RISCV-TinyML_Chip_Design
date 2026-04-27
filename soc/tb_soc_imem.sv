`timescale 1ns/1ps

module tb_soc_imem;

  import soc_map_pkg::*;

  logic        clk;
  logic        rst_n;
  logic        instr_req;
  logic [31:0] instr_addr;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_rdata;
  logic        boot_req;
  logic        boot_we;
  logic [ 3:0] boot_be;
  logic [31:0] boot_addr;
  logic [31:0] boot_wdata;
  logic        boot_gnt;

  soc_imem #(
      .INIT_FILE  ("test_imem.memh"),
      .DEPTH_WORDS(4)
  ) dut (
      .clk_i         (clk),
      .rst_ni        (rst_n),
      .instr_req_i   (instr_req),
      .instr_addr_i  (instr_addr),
      .instr_gnt_o   (instr_gnt),
      .instr_rvalid_o(instr_rvalid),
      .instr_rdata_o (instr_rdata),
      .data_req_i    (1'b0),
      .data_we_i     (1'b0),
      .data_be_i     (4'h0),
      .data_addr_i   (32'h0),
      .data_wdata_i  (32'h0),
      .data_gnt_o    (),
      .data_rvalid_o (),
      .data_rdata_o  (),
      .boot_req_i    (boot_req),
      .boot_we_i     (boot_we),
      .boot_be_i     (boot_be),
      .boot_addr_i   (boot_addr),
      .boot_wdata_i  (boot_wdata),
      .boot_gnt_o    (boot_gnt)
  );

  always #5 clk = ~clk;

  initial begin
    clk        = 1'b0;
    rst_n      = 1'b0;
    instr_req  = 1'b0;
    instr_addr = SOC_IMEM_BASE_ADDR;
    boot_req   = 1'b0;
    boot_we    = 1'b0;
    boot_be    = 4'h0;
    boot_addr  = SOC_IMEM_BASE_ADDR;
    boot_wdata = 32'h0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    @(posedge clk);
    instr_req  = 1'b1;
    instr_addr = SOC_IMEM_BASE_ADDR;
    #1;
    if (instr_gnt !== 1'b1) begin
      $display("tb_soc_imem: expected immediate grant");
      $fatal(1);
    end

    @(posedge clk);
    instr_req  = 1'b0;
    #1;
    if (!instr_rvalid || (instr_rdata !== 32'h11111111)) begin
      $display("tb_soc_imem: word0 mismatch %h", instr_rdata);
      $fatal(1);
    end

    @(posedge clk);
    instr_req  = 1'b1;
    instr_addr = SOC_IMEM_BASE_ADDR + 32'h4;
    #1;
    if (instr_gnt !== 1'b1) begin
      $display("tb_soc_imem: expected second grant");
      $fatal(1);
    end

    @(posedge clk);
    instr_req = 1'b0;
    #1;
    if (!instr_rvalid || (instr_rdata !== 32'h22222222)) begin
      $display("tb_soc_imem: word1 mismatch %h", instr_rdata);
      $fatal(1);
    end

    @(posedge clk);
    #1;
    if (instr_rvalid) begin
      $display("tb_soc_imem: unexpected extra response");
      $fatal(1);
    end

    @(posedge clk);
    boot_req   = 1'b1;
    boot_we    = 1'b1;
    boot_be    = 4'hF;
    boot_addr  = SOC_IMEM_BASE_ADDR + 32'h8;
    boot_wdata = 32'hA5A5_5A5A;
    #1;
    if (boot_gnt !== 1'b1) begin
      $display("tb_soc_imem: expected immediate boot grant");
      $fatal(1);
    end

    @(posedge clk);
    boot_req  = 1'b0;
    boot_we   = 1'b0;
    boot_be   = 4'h0;
    boot_addr = SOC_IMEM_BASE_ADDR;

    @(posedge clk);
    instr_req  = 1'b1;
    instr_addr = SOC_IMEM_BASE_ADDR + 32'h8;
    #1;
    if (instr_gnt !== 1'b1) begin
      $display("tb_soc_imem: expected grant after boot write");
      $fatal(1);
    end

    @(posedge clk);
    instr_req = 1'b0;
    #1;
    if (!instr_rvalid || (instr_rdata !== 32'hA5A5_5A5A)) begin
      $display("tb_soc_imem: boot-written word mismatch %h", instr_rdata);
      $fatal(1);
    end

    $display("tb_soc_imem: PASS");
    $finish;
  end

endmodule
