`timescale 1ns/1ps

module tb_soc_ai_tinyconv_accel_full_model;

  import soc_map_pkg::*;
  import soc_ai_model_pkg::*;
  import soc_ai_model_golden_pkg::*;

  localparam logic [31:0] AI_BASE = SOC_AI_MEM_BASE_ADDR;
  localparam logic [31:0] OUTPUT_BASE = SOC_AI_MEM_BASE_ADDR + 32'h0000_7000;
  localparam int INPUT_BYTES = AI_INPUT_H * AI_INPUT_W;
  localparam int MAX_CYCLES = 2_000_000;

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
  logic [7:0] input_mem[0:INPUT_BYTES-1];
  logic [31:0] output_class_word;
  logic signed [31:0] output_score0;
  logic signed [31:0] output_score1;
  logic signed [31:0] output_score2;
  logic signed [31:0] output_score3;
  int write_count;
  int cycle_idx;
  string input_memh_file;

  soc_ai_tinyconv_accel dut (
      .clk_i         (clk),
      .rst_ni        (rst_n),
      .start_i       (start),
      .input_base_i  (AI_BASE),
      .input_len_i   (INPUT_BYTES),
      .output_base_i (OUTPUT_BASE),
      .busy_o        (busy),
      .done_o        (done),
      .result_class_o(result_class),
      .result0_o     (result0),
      .result1_o     (result1),
      .result2_o     (result2),
      .result3_o     (result3),
      .cycle_count_o (cycle_count),
      .mem_req_o     (mem_req),
      .mem_we_o      (mem_we),
      .mem_be_o      (mem_be),
      .mem_addr_o    (mem_addr),
      .mem_wdata_o   (mem_wdata),
      .mem_gnt_i     (mem_gnt),
      .mem_rvalid_i  (mem_rvalid),
      .mem_rdata_i   (mem_rdata)
  );

  assign mem_gnt = mem_req;

  always #5 clk = ~clk;

  function automatic logic [7:0] input_byte(input logic [31:0] offset);
    begin
      if (offset < INPUT_BYTES) begin
        return input_mem[offset];
      end
      return 8'h00;
    end
  endfunction

  function automatic logic [31:0] input_word(input logic [31:0] addr);
    logic [31:0] offset;
    logic [31:0] aligned;
    begin
      offset = addr - AI_BASE;
      aligned = {offset[31:2], 2'b00};
      return {input_byte(aligned + 32'd3),
              input_byte(aligned + 32'd2),
              input_byte(aligned + 32'd1),
              input_byte(aligned)};
    end
  endfunction

  task automatic check_score(
      input string what,
      input logic signed [31:0] got,
      input logic signed [31:0] exp
  );
    begin
      if (got !== exp) begin
        $display("tb_soc_ai_tinyconv_accel_full_model: %s mismatch got=%0d exp=%0d",
                 what, got, exp);
        $fatal(1);
      end
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rvalid <= 1'b0;
      mem_rdata <= '0;
      done_seen <= 1'b0;
      write_count <= 0;
      output_class_word <= '0;
      output_score0 <= '0;
      output_score1 <= '0;
      output_score2 <= '0;
      output_score3 <= '0;
    end else begin
      mem_rvalid <= mem_req && !mem_we;
      if (mem_req && !mem_we) begin
        mem_rdata <= input_word(mem_addr);
      end

      if (mem_req && mem_we) begin
        if (mem_be !== 4'hf) begin
          $display("tb_soc_ai_tinyconv_accel_full_model: bad write strobe %b", mem_be);
          $fatal(1);
        end

        write_count <= write_count + 1;
        unique case (mem_addr - OUTPUT_BASE)
          32'h00: output_class_word <= mem_wdata;
          32'h04: output_score0 <= mem_wdata;
          32'h08: output_score1 <= mem_wdata;
          32'h0c: output_score2 <= mem_wdata;
          32'h10: output_score3 <= mem_wdata;
          default: begin
            $display("tb_soc_ai_tinyconv_accel_full_model: unexpected write addr=%h data=%h",
                     mem_addr, mem_wdata);
            $fatal(1);
          end
        endcase
      end

      if (done) begin
        done_seen <= 1'b1;
      end
    end
  end

  initial begin
    if (!$value$plusargs("input_memh=%s", input_memh_file)) begin
      input_memh_file = "build/ai_model_tflm_demo_golden/input_vector.memh";
    end
    $readmemh(input_memh_file, input_mem);

    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    for (cycle_idx = 0; cycle_idx < MAX_CYCLES && !done_seen; cycle_idx = cycle_idx + 1) begin
      @(posedge clk);
    end

    if (!done_seen) begin
      $display("tb_soc_ai_tinyconv_accel_full_model: TIMEOUT state=%0d oh=%0d ow=%0d ch=%0d kh=%0d kw=%0d",
               dut.state_q, dut.oh_q, dut.ow_q, dut.ch_q, dut.kh_q, dut.kw_q);
      $fatal(1);
    end

    if (busy || cycle_count == 32'h0 || write_count != 5) begin
      $display("tb_soc_ai_tinyconv_accel_full_model: bad finish busy=%b cycles=%0d writes=%0d",
               busy, cycle_count, write_count);
      $fatal(1);
    end

    if (result_class !== AI_GOLDEN_RESULT_CLASS[1:0]) begin
      $display("tb_soc_ai_tinyconv_accel_full_model: class mismatch got=%0d exp=%0d",
               result_class, AI_GOLDEN_RESULT_CLASS);
      $fatal(1);
    end

    if (output_class_word[1:0] !== AI_GOLDEN_RESULT_CLASS[1:0]) begin
      $display("tb_soc_ai_tinyconv_accel_full_model: output class word mismatch got=%h exp=%0d",
               output_class_word, AI_GOLDEN_RESULT_CLASS);
      $fatal(1);
    end

    check_score("result0", result0, AI_GOLDEN_SCORE0);
    check_score("result1", result1, AI_GOLDEN_SCORE1);
    check_score("result2", result2, AI_GOLDEN_SCORE2);
    check_score("result3", result3, AI_GOLDEN_SCORE3);
    check_score("output_score0", output_score0, AI_GOLDEN_SCORE0);
    check_score("output_score1", output_score1, AI_GOLDEN_SCORE1);
    check_score("output_score2", output_score2, AI_GOLDEN_SCORE2);
    check_score("output_score3", output_score3, AI_GOLDEN_SCORE3);

    $display("tb_soc_ai_tinyconv_accel_full_model: PASS class=%0d scores=%0d,%0d,%0d,%0d cycles=%0d",
             result_class, result0, result1, result2, result3, cycle_count);
    $finish;
  end

endmodule
