module soc_ai_uart_loader #(
    parameter int DEFAULT_INPUT_BYTES = 1960
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        start_i,
    input  logic [15:0] baud_div_i,
    input  logic [31:0] input_base_i,
    input  logic [31:0] input_len_i,
    input  logic        uart_rx_i,

    output logic        active_o,
    output logic        done_o,
    output logic        error_o,
    output logic [31:0] byte_count_o,

    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [ 3:0] mem_be_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] mem_wdata_o,
    input  logic        mem_gnt_i
);

  logic       rx_re;
  logic [7:0] rx_data;
  logic       rx_full;
  logic       rx_empty;
  logic       active_q;
  logic       done_q;
  logic       error_q;
  logic [31:0] byte_count_q;
  logic [31:0] target_len_q;
  logic [31:0] write_addr;
  logic [1:0]  byte_lane;
  logic        write_fire;

  uart_rx uart_rx_i_dut (
      .clk_i    (clk_i),
      .rst_i    (~rst_ni),
      .baud_div_i(baud_div_i),
      .re_i     (rx_re),
      .stall_i  (1'b0),
      .data_o   (rx_data),
      .full_o   (rx_full),
      .empty_o  (rx_empty),
      .rx_i     (uart_rx_i)
  );

  assign active_o     = active_q;
  assign done_o       = done_q;
  assign error_o      = error_q;
  assign byte_count_o = byte_count_q;

  assign write_addr = input_base_i + byte_count_q;
  assign byte_lane  = write_addr[1:0];
  assign mem_req_o  = active_q && !rx_empty && (byte_count_q < target_len_q);
  assign mem_we_o   = 1'b1;
  assign mem_addr_o = write_addr;
  assign mem_be_o   = 4'b0001 << byte_lane;
  assign mem_wdata_o = (byte_lane == 2'd0) ? {24'h0, rx_data} :
                       (byte_lane == 2'd1) ? {16'h0, rx_data, 8'h0} :
                       (byte_lane == 2'd2) ? {8'h0, rx_data, 16'h0} :
                                             {rx_data, 24'h0};
  assign write_fire = mem_req_o && mem_gnt_i;
  assign rx_re      = write_fire;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_q    <= 1'b0;
      done_q      <= 1'b0;
      error_q     <= 1'b0;
      byte_count_q <= '0;
      target_len_q <= DEFAULT_INPUT_BYTES;
    end else begin
      if (start_i) begin
        active_q     <= 1'b1;
        done_q       <= 1'b0;
        error_q      <= 1'b0;
        byte_count_q <= '0;
        target_len_q <= (input_len_i == 32'h0) ? DEFAULT_INPUT_BYTES : input_len_i;
      end else if (write_fire) begin
        byte_count_q <= byte_count_q + 1'b1;
        if ((byte_count_q + 1'b1) >= target_len_q) begin
          active_q <= 1'b0;
          done_q   <= 1'b1;
        end
      end
    end
  end

endmodule
