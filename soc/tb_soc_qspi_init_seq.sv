`timescale 1ns/1ps

module tb_soc_qspi_init_seq;

  logic        clk;
  logic        rst_n;
  logic        cfg_cmd_valid;
  logic [31:0] cfg_cmd_data;
  logic        cfg_cmd_ready;
  logic        cfg_rsp_valid;
  logic [31:0] cfg_rsp_data;
  logic        init_active;
  logic        init_done;
  logic        init_error;
  logic [31:0] last_rsp_data;
  logic [31:0] cmd_log [0:15];
  integer      cmd_count_q;

  soc_qspi_init_seq dut (
      .clk_i          (clk),
      .rst_ni         (rst_n),
      .cfg_cmd_valid_o(cfg_cmd_valid),
      .cfg_cmd_data_o (cfg_cmd_data),
      .cfg_cmd_ready_i(cfg_cmd_ready),
      .cfg_rsp_valid_i(cfg_rsp_valid),
      .cfg_rsp_data_i (cfg_rsp_data),
      .init_active_o  (init_active),
      .init_done_o    (init_done),
      .init_error_o   (init_error),
      .last_rsp_data_o(last_rsp_data)
  );

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_count_q   <= 0;
      cfg_cmd_ready <= 1'b1;
      cfg_rsp_valid <= 1'b0;
      cfg_rsp_data  <= 32'h0;
    end else begin
      cfg_rsp_valid <= 1'b0;

      if (cfg_cmd_valid && cfg_cmd_ready) begin
        cmd_log[cmd_count_q] <= cfg_cmd_data;
        cmd_count_q          <= cmd_count_q + 1;
        cfg_cmd_ready        <= 1'b0;
      end else if (!cfg_cmd_ready) begin
        cfg_rsp_valid <= 1'b1;
        cfg_rsp_data  <= 32'hCAFE_0000 | cmd_count_q[15:0];
        cfg_cmd_ready <= 1'b1;
      end
    end
  end

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    cfg_cmd_ready = 1'b1;
    cfg_rsp_valid = 1'b0;
    cfg_rsp_data = 32'h0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    repeat (200) begin
      @(posedge clk);
      if (init_done) begin
        if (init_error) begin
          $fatal(1, "tb_soc_qspi_init_seq: unexpected init_error");
        end
        if (cmd_count_q != 16) begin
          $fatal(1, "tb_soc_qspi_init_seq: expected 16 commands, got %0d", cmd_count_q);
        end
        if (cmd_log[0]  != 32'h0000_1100) $fatal(1, "cmd0 mismatch %h", cmd_log[0]);
        if (cmd_log[1]  != 32'h0000_10ff) $fatal(1, "cmd1 mismatch %h", cmd_log[1]);
        if (cmd_log[7]  != 32'h0000_1100) $fatal(1, "cmd7 mismatch %h", cmd_log[7]);
        if (cmd_log[8]  != 32'h0000_10eb) $fatal(1, "cmd8 mismatch %h", cmd_log[8]);
        if (cmd_log[12] != 32'h0000_1aa0) $fatal(1, "cmd12 mismatch %h", cmd_log[12]);
        if (cmd_log[15] != 32'h0000_0100) $fatal(1, "cmd15 mismatch %h", cmd_log[15]);
        $display("tb_soc_qspi_init_seq: PASS");
        $finish;
      end
    end

    $fatal(1, "tb_soc_qspi_init_seq: timeout waiting for init_done");
  end

endmodule
