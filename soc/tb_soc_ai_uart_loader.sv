`timescale 1ns/1ps

module tb_soc_ai_uart_loader;

  import soc_map_pkg::*;

  logic clk;
  logic rst_n;
  logic start;
  logic [15:0] baud_div;
  logic [31:0] input_base;
  logic [31:0] input_len;
  logic uart_rx;
  logic active;
  logic done;
  logic error;
  logic [31:0] byte_count;
  logic mem_req;
  logic mem_we;
  logic [3:0] mem_be;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic mem_gnt;
  logic [31:0] packed_word;

  soc_ai_uart_loader dut (
      .clk_i       (clk),
      .rst_ni      (rst_n),
      .start_i     (start),
      .baud_div_i  (baud_div),
      .input_base_i(input_base),
      .input_len_i (input_len),
      .uart_rx_i   (uart_rx),
      .active_o    (active),
      .done_o      (done),
      .error_o     (error),
      .byte_count_o(byte_count),
      .mem_req_o   (mem_req),
      .mem_we_o    (mem_we),
      .mem_be_o    (mem_be),
      .mem_addr_o  (mem_addr),
      .mem_wdata_o (mem_wdata),
      .mem_gnt_i   (mem_gnt)
  );

  assign mem_gnt = mem_req;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (mem_req && mem_gnt) begin
      unique case (mem_be)
        4'b0001: packed_word[7:0]   <= mem_wdata[7:0];
        4'b0010: packed_word[15:8]  <= mem_wdata[15:8];
        4'b0100: packed_word[23:16] <= mem_wdata[23:16];
        4'b1000: packed_word[31:24] <= mem_wdata[31:24];
        default: begin
          $display("tb_soc_ai_uart_loader: bad byte enable %b", mem_be);
          $fatal(1);
        end
      endcase
    end
  end

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    baud_div = 16'h0;
    input_base = SOC_AI_MEM_BASE_ADDR;
    input_len = 32'd4;
    uart_rx = 1'b1;
    packed_word = '0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);
    dut.uart_rx_i_dut.queue[0] = 8'h11;
    dut.uart_rx_i_dut.queue[1] = 8'h22;
    dut.uart_rx_i_dut.queue[2] = 8'h33;
    dut.uart_rx_i_dut.queue[3] = 8'h44;
    dut.uart_rx_i_dut.read_ptr = 5'd0;
    dut.uart_rx_i_dut.write_ptr = 5'd4;

    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    wait (done);
    if (error || byte_count !== 32'd4 || packed_word !== 32'h4433_2211) begin
      $display("tb_soc_ai_uart_loader: mismatch error=%b count=%0d word=%h",
               error, byte_count, packed_word);
      $fatal(1);
    end

    $display("tb_soc_ai_uart_loader: PASS");
    $finish;
  end

  initial begin
    #5000;
    $display("tb_soc_ai_uart_loader: TIMEOUT");
    $fatal(1);
  end

endmodule
