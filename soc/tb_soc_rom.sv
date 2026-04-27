`timescale 1ns/1ps

module tb_soc_rom;

  import soc_map_pkg::*;

  logic        clk;
  logic        rst_n;
  logic        req;
  logic [31:0] addr;
  logic        gnt;
  logic        rvalid;
  logic [31:0] rdata;

  soc_rom #(
      .INIT_FILE  ("test_rom.memh"),
      .DEPTH_WORDS(4)
  ) dut (
      .clk_i   (clk),
      .rst_ni  (rst_n),
      .req_i   (req),
      .addr_i  (addr),
      .gnt_o   (gnt),
      .rvalid_o(rvalid),
      .rdata_o (rdata)
  );

  always #5 clk = ~clk;

  initial begin
    clk  = 1'b0;
    rst_n = 1'b0;
    req  = 1'b0;
    addr = SOC_ROM_BASE_ADDR;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    @(posedge clk);
    req  = 1'b1;
    addr = SOC_ROM_BASE_ADDR;
    if (gnt !== 1'b1) begin
      $display("tb_soc_rom: expected immediate grant");
      $fatal(1);
    end

    @(posedge clk);
    req  = 1'b1;
    addr = SOC_ROM_BASE_ADDR + 32'h4;
    if (!rvalid || (rdata !== 32'hDEAD_BEEF)) begin
      $display("tb_soc_rom: word0 mismatch %h", rdata);
      $fatal(1);
    end

    @(posedge clk);
    req = 1'b0;
    if (!rvalid || (rdata !== 32'hCAFE_BABE)) begin
      $display("tb_soc_rom: word1 mismatch %h", rdata);
      $fatal(1);
    end

    $display("tb_soc_rom: PASS");
    $finish;
  end

endmodule
