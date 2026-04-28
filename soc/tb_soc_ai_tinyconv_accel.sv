`timescale 1ns/1ps

module tb_soc_ai_tinyconv_accel;

  import soc_map_pkg::*;

  logic clk;
  logic rst_n;
  logic start;
  logic busy;
  logic done;
  logic [1:0] result_class;
  logic signed [31:0] result0;
  logic signed [31:0] result1;
  logic signed [31:0] result2;
  logic signed [31:0] result3;
  logic [31:0] cycle_count;
  logic mem_req;
  logic mem_we;
  logic [3:0] mem_be;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic mem_gnt;
  logic mem_rvalid;
  logic [31:0] mem_rdata;
  logic done_seen;
  int write_count;
  localparam logic [31:0] AI_BASE = 32'h2000_0000;

  soc_ai_tinyconv_accel #(
      .INPUT_H (3),
      .INPUT_W (3),
      .OUT_H   (1),
      .OUT_W   (1),
      .CHANNELS(2),
      .K_H     (2),
      .K_W     (2),
      .PAD_H   (0),
      .PAD_W   (0)
  ) dut (
      .clk_i        (clk),
      .rst_ni       (rst_n),
      .start_i      (start),
      .input_base_i (AI_BASE),
      .input_len_i  (32'd9),
      .output_base_i(AI_BASE + 32'h100),
      .busy_o       (busy),
      .done_o       (done),
      .result_class_o(result_class),
      .result0_o    (result0),
      .result1_o    (result1),
      .result2_o    (result2),
      .result3_o    (result3),
      .cycle_count_o(cycle_count),
      .mem_req_o    (mem_req),
      .mem_we_o     (mem_we),
      .mem_be_o     (mem_be),
      .mem_addr_o   (mem_addr),
      .mem_wdata_o  (mem_wdata),
      .mem_gnt_i    (mem_gnt),
      .mem_rvalid_i (mem_rvalid),
      .mem_rdata_i  (mem_rdata)
  );

  assign mem_gnt = mem_req;

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rvalid <= 1'b0;
      mem_rdata <= '0;
      done_seen <= 1'b0;
      write_count <= 0;
    end else begin
      mem_rvalid <= mem_req && !mem_we;
      if (mem_req && !mem_we) begin
        mem_rdata <= {8'(mem_addr[7:0] + 8'd3),
                      8'(mem_addr[7:0] + 8'd2),
                      8'(mem_addr[7:0] + 8'd1),
                      8'(mem_addr[7:0])};
      end
      if (mem_req && mem_we) begin
        if (mem_be !== 4'hf) begin
          $display("tb_soc_ai_tinyconv_accel: bad result write strobe %b", mem_be);
          $fatal(1);
        end
        write_count <= write_count + 1;
      end
      if (done) begin
        done_seen <= 1'b1;
      end
    end
  end

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    wait (done_seen);
    if (busy || cycle_count == 32'h0 || write_count != 5) begin
      $display("tb_soc_ai_tinyconv_accel: bad finish busy=%b cycles=%0d writes=%0d",
               busy, cycle_count, write_count);
      $fatal(1);
    end

    $display("tb_soc_ai_tinyconv_accel: PASS class=%0d scores=%0d,%0d,%0d,%0d cycles=%0d",
             result_class, result0, result1, result2, result3, cycle_count);
    $finish;
  end

  initial begin
    #20000;
    $display("tb_soc_ai_tinyconv_accel: TIMEOUT state=%0d oh=%0d ow=%0d ch=%0d kh=%0d kw=%0d mem_req=%b mem_gnt=%b mem_rvalid=%b",
             dut.state_q, dut.oh_q, dut.ow_q, dut.ch_q, dut.kh_q, dut.kw_q,
             mem_req, mem_gnt, mem_rvalid);
    $fatal(1);
  end

endmodule
