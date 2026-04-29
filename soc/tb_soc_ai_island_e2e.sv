`timescale 1ns/1ps

module tb_soc_ai_island_e2e;

  import soc_map_pkg::*;
  import soc_ai_model_golden_pkg::*;

  localparam logic [31:0] AI_BASE = SOC_AI_MEM_BASE_ADDR;
  localparam logic [31:0] AI_OUT_BASE = SOC_AI_MEM_BASE_ADDR + 32'h0000_7000;
  localparam logic [31:0] AI_CSR = SOC_AI_CSR_BASE_ADDR;
  localparam logic [31:0] REG_CTRL = AI_CSR + 32'h04;
  localparam logic [31:0] REG_STATUS = AI_CSR + 32'h08;
  localparam logic [31:0] REG_INPUT_BASE = AI_CSR + 32'h0c;
  localparam logic [31:0] REG_INPUT_LEN = AI_CSR + 32'h10;
  localparam logic [31:0] REG_OUTPUT_BASE = AI_CSR + 32'h14;
  localparam logic [31:0] REG_RESULT_CLASS = AI_CSR + 32'h18;
  localparam logic [31:0] REG_RESULT0 = AI_CSR + 32'h1c;
  localparam logic [31:0] REG_RESULT1 = AI_CSR + 32'h20;
  localparam logic [31:0] REG_RESULT2 = AI_CSR + 32'h24;
  localparam logic [31:0] REG_RESULT3 = AI_CSR + 32'h28;
  localparam logic [31:0] REG_CYCLES = AI_CSR + 32'h2c;
  localparam logic [31:0] REG_UART_BAUD = AI_CSR + 32'h34;
  localparam logic [31:0] REG_UART_COUNT = AI_CSR + 32'h38;

  logic clk;
  logic rst_n;

  logic [31:0] mem_awaddr;
  logic [2:0]  mem_awprot;
  logic        mem_awvalid;
  logic        mem_awready;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_wstrb;
  logic        mem_wvalid;
  logic        mem_wready;
  logic [1:0]  mem_bresp;
  logic        mem_bvalid;
  logic        mem_bready;
  logic [31:0] mem_araddr;
  logic [2:0]  mem_arprot;
  logic        mem_arvalid;
  logic        mem_arready;
  logic [31:0] mem_rdata;
  logic [1:0]  mem_rresp;
  logic        mem_rvalid;
  logic        mem_rready;

  logic [31:0] csr_awaddr;
  logic [2:0]  csr_awprot;
  logic        csr_awvalid;
  logic        csr_awready;
  logic [31:0] csr_wdata;
  logic [3:0]  csr_wstrb;
  logic        csr_wvalid;
  logic        csr_wready;
  logic [1:0]  csr_bresp;
  logic        csr_bvalid;
  logic        csr_bready;
  logic [31:0] csr_araddr;
  logic [2:0]  csr_arprot;
  logic        csr_arvalid;
  logic        csr_arready;
  logic [31:0] csr_rdata;
  logic [1:0]  csr_rresp;
  logic        csr_rvalid;
  logic        csr_rready;

  logic        accel_start;
  logic        uart_start;
  logic [31:0] input_base;
  logic [31:0] input_len;
  logic [31:0] output_base;
  logic [15:0] uart_baud_div;
  logic        accel_busy;
  logic        accel_done;
  logic [1:0]  accel_result_class;
  logic signed [31:0] accel_result0;
  logic signed [31:0] accel_result1;
  logic signed [31:0] accel_result2;
  logic signed [31:0] accel_result3;
  logic [31:0] accel_cycle_count;
  logic        ai_irq;
  logic        uart_rx;
  logic        uart_active;
  logic        uart_done;
  logic        uart_error;
  logic [31:0] uart_byte_count;

  logic        accel_mem_req;
  logic        accel_mem_we;
  logic [3:0]  accel_mem_be;
  logic [31:0] accel_mem_addr;
  logic [31:0] accel_mem_wdata;
  logic        accel_mem_gnt;
  logic        accel_mem_rvalid;
  logic [31:0] accel_mem_rdata;
  logic        uart_mem_req;
  logic        uart_mem_we;
  logic [3:0]  uart_mem_be;
  logic [31:0] uart_mem_addr;
  logic [31:0] uart_mem_wdata;
  logic        uart_mem_gnt;
  logic        mem_int_req;
  logic        mem_int_we;
  logic [3:0]  mem_int_be;
  logic [31:0] mem_int_addr;
  logic [31:0] mem_int_wdata;
  logic        mem_int_gnt;
  logic        mem_int_rvalid;
  logic [31:0] mem_int_rdata;
  logic        mem_rsp_accel_q;

`ifndef SOC_AI_E2E_USE_UART
  assign uart_active = 1'b0;
  assign uart_done = 1'b0;
  assign uart_error = 1'b0;
  assign uart_byte_count = 32'h0;
  assign uart_mem_req = 1'b0;
  assign uart_mem_we = 1'b0;
  assign uart_mem_be = 4'h0;
  assign uart_mem_addr = 32'h0;
  assign uart_mem_wdata = 32'h0;
`endif

  assign mem_int_req = uart_mem_req || accel_mem_req;
  assign mem_int_we = uart_mem_req ? uart_mem_we : accel_mem_we;
  assign mem_int_be = uart_mem_req ? uart_mem_be : accel_mem_be;
  assign mem_int_addr = uart_mem_req ? uart_mem_addr : accel_mem_addr;
  assign mem_int_wdata = uart_mem_req ? uart_mem_wdata : accel_mem_wdata;
  assign uart_mem_gnt = uart_mem_req ? mem_int_gnt : 1'b0;
  assign accel_mem_gnt = (!uart_mem_req && accel_mem_req) ? mem_int_gnt : 1'b0;
  assign accel_mem_rvalid = mem_rsp_accel_q && mem_int_rvalid;
  assign accel_mem_rdata = mem_int_rdata;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rsp_accel_q <= 1'b0;
    end else begin
      if (mem_int_gnt) begin
        mem_rsp_accel_q <= !uart_mem_req && accel_mem_req && !accel_mem_we;
      end else if (mem_int_rvalid) begin
        mem_rsp_accel_q <= 1'b0;
      end
    end
  end

  soc_ai_mem ai_mem_i (
      .clk_i          (clk),
      .rst_ni         (rst_n),
      .s_axi_awaddr_i (mem_awaddr),
      .s_axi_awprot_i (mem_awprot),
      .s_axi_awvalid_i(mem_awvalid),
      .s_axi_awready_o(mem_awready),
      .s_axi_wdata_i  (mem_wdata),
      .s_axi_wstrb_i  (mem_wstrb),
      .s_axi_wvalid_i (mem_wvalid),
      .s_axi_wready_o (mem_wready),
      .s_axi_bresp_o  (mem_bresp),
      .s_axi_bvalid_o (mem_bvalid),
      .s_axi_bready_i (mem_bready),
      .s_axi_araddr_i (mem_araddr),
      .s_axi_arprot_i (mem_arprot),
      .s_axi_arvalid_i(mem_arvalid),
      .s_axi_arready_o(mem_arready),
      .s_axi_rdata_o  (mem_rdata),
      .s_axi_rresp_o  (mem_rresp),
      .s_axi_rvalid_o (mem_rvalid),
      .s_axi_rready_i (mem_rready),
      .ai_req_i       (mem_int_req),
      .ai_we_i        (mem_int_we),
      .ai_be_i        (mem_int_be),
      .ai_addr_i      (mem_int_addr),
      .ai_wdata_i     (mem_int_wdata),
      .ai_gnt_o       (mem_int_gnt),
      .ai_rvalid_o    (mem_int_rvalid),
      .ai_rdata_o     (mem_int_rdata)
  );

  soc_ai_csr ai_csr_i (
      .clk_i               (clk),
      .rst_ni              (rst_n),
      .s_axi_awaddr_i      (csr_awaddr),
      .s_axi_awprot_i      (csr_awprot),
      .s_axi_awvalid_i     (csr_awvalid),
      .s_axi_awready_o     (csr_awready),
      .s_axi_wdata_i       (csr_wdata),
      .s_axi_wstrb_i       (csr_wstrb),
      .s_axi_wvalid_i      (csr_wvalid),
      .s_axi_wready_o      (csr_wready),
      .s_axi_bresp_o       (csr_bresp),
      .s_axi_bvalid_o      (csr_bvalid),
      .s_axi_bready_i      (csr_bready),
      .s_axi_araddr_i      (csr_araddr),
      .s_axi_arprot_i      (csr_arprot),
      .s_axi_arvalid_i     (csr_arvalid),
      .s_axi_arready_o     (csr_arready),
      .s_axi_rdata_o       (csr_rdata),
      .s_axi_rresp_o       (csr_rresp),
      .s_axi_rvalid_o      (csr_rvalid),
      .s_axi_rready_i      (csr_rready),
      .accel_start_o       (accel_start),
      .uart_start_o        (uart_start),
      .input_base_o        (input_base),
      .input_len_o         (input_len),
      .output_base_o       (output_base),
      .uart_baud_div_o     (uart_baud_div),
      .accel_busy_i        (accel_busy),
      .accel_done_i        (accel_done),
      .accel_result_class_i(accel_result_class),
      .accel_result0_i     (accel_result0),
      .accel_result1_i     (accel_result1),
      .accel_result2_i     (accel_result2),
      .accel_result3_i     (accel_result3),
      .accel_cycle_count_i (accel_cycle_count),
      .uart_active_i       (uart_active),
      .uart_done_i         (uart_done),
      .uart_error_i        (uart_error),
      .uart_byte_count_i   (uart_byte_count),
      .irq_o               (ai_irq)
  );

`ifdef SOC_AI_E2E_USE_UART
  soc_ai_uart_loader #(
      .DEFAULT_INPUT_BYTES(9)
  ) uart_loader_i (
      .clk_i       (clk),
      .rst_ni      (rst_n),
      .start_i     (uart_start),
      .baud_div_i  (uart_baud_div),
      .input_base_i(input_base),
      .input_len_i (input_len),
      .uart_rx_i   (uart_rx),
      .active_o    (uart_active),
      .done_o      (uart_done),
      .error_o     (uart_error),
      .byte_count_o(uart_byte_count),
      .mem_req_o   (uart_mem_req),
      .mem_we_o    (uart_mem_we),
      .mem_be_o    (uart_mem_be),
      .mem_addr_o  (uart_mem_addr),
      .mem_wdata_o (uart_mem_wdata),
      .mem_gnt_i   (uart_mem_gnt)
  );
`endif

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
  ) accel_i (
      .clk_i         (clk),
      .rst_ni        (rst_n),
      .start_i       (accel_start),
      .input_base_i  (input_base),
      .input_len_i   (input_len),
      .output_base_i (output_base),
      .busy_o        (accel_busy),
      .done_o        (accel_done),
      .result_class_o(accel_result_class),
      .result0_o     (accel_result0),
      .result1_o     (accel_result1),
      .result2_o     (accel_result2),
      .result3_o     (accel_result3),
      .cycle_count_o (accel_cycle_count),
      .mem_req_o     (accel_mem_req),
      .mem_we_o      (accel_mem_we),
      .mem_be_o      (accel_mem_be),
      .mem_addr_o    (accel_mem_addr),
      .mem_wdata_o   (accel_mem_wdata),
      .mem_gnt_i     (accel_mem_gnt),
      .mem_rvalid_i  (accel_mem_rvalid),
      .mem_rdata_i   (accel_mem_rdata)
  );

  always #5 clk = ~clk;

  task automatic axi_mem_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
    begin
      @(posedge clk);
      mem_awaddr <= addr;
      mem_awvalid <= 1'b1;
      mem_wdata <= data;
      mem_wstrb <= strb;
      mem_wvalid <= 1'b1;
      mem_bready <= 1'b1;
      while (!mem_awready || !mem_wready) @(posedge clk);
      @(posedge clk);
      mem_awvalid <= 1'b0;
      mem_wvalid <= 1'b0;
      while (!mem_bvalid) @(posedge clk);
      @(posedge clk);
      mem_bready <= 1'b0;
    end
  endtask

  task automatic axi_mem_read(input logic [31:0] addr, output logic [31:0] data);
    begin
      @(posedge clk);
      mem_araddr <= addr;
      mem_arvalid <= 1'b1;
      mem_rready <= 1'b1;
      while (!mem_arready) @(posedge clk);
      @(posedge clk);
      mem_arvalid <= 1'b0;
      while (!mem_rvalid) @(posedge clk);
      data = mem_rdata;
      @(posedge clk);
      mem_rready <= 1'b0;
    end
  endtask

  task automatic axi_csr_write(input logic [31:0] addr, input logic [31:0] data);
    begin
      @(posedge clk);
      csr_awaddr <= addr;
      csr_awvalid <= 1'b1;
      csr_wdata <= data;
      csr_wstrb <= 4'hf;
      csr_wvalid <= 1'b1;
      csr_bready <= 1'b1;
      while (!csr_awready || !csr_wready) @(posedge clk);
      @(posedge clk);
      csr_awvalid <= 1'b0;
      csr_wvalid <= 1'b0;
      while (!csr_bvalid) @(posedge clk);
      @(posedge clk);
      csr_bready <= 1'b0;
    end
  endtask

  task automatic axi_csr_read(input logic [31:0] addr, output logic [31:0] data);
    begin
      @(posedge clk);
      csr_araddr <= addr;
      csr_arvalid <= 1'b1;
      csr_rready <= 1'b1;
      while (!csr_arready) @(posedge clk);
      @(posedge clk);
      csr_arvalid <= 1'b0;
      while (!csr_rvalid) @(posedge clk);
      data = csr_rdata;
      @(posedge clk);
      csr_rready <= 1'b0;
    end
  endtask

  task automatic check_word(input string what, input logic [31:0] got, input logic [31:0] exp);
    begin
      if (got !== exp) begin
        $display("tb_soc_ai_island_e2e: %s mismatch got=%h exp=%h", what, got, exp);
        $fatal(1);
      end
    end
  endtask

  task automatic check_score(input string what, input logic [31:0] got, input logic signed [31:0] exp);
    begin
      if ($signed(got) !== exp) begin
        $display("tb_soc_ai_island_e2e: %s mismatch got=%0d exp=%0d", what, $signed(got), exp);
        $fatal(1);
      end
    end
  endtask

  initial begin
    logic [31:0] data;
    int poll_idx;
    bit done_seen;

    clk = 1'b0;
    rst_n = 1'b0;
    mem_awaddr = '0;
    mem_awprot = '0;
    mem_awvalid = 1'b0;
    mem_wdata = '0;
    mem_wstrb = '0;
    mem_wvalid = 1'b0;
    mem_bready = 1'b0;
    mem_araddr = '0;
    mem_arprot = '0;
    mem_arvalid = 1'b0;
    mem_rready = 1'b0;
    csr_awaddr = '0;
    csr_awprot = '0;
    csr_awvalid = 1'b0;
    csr_wdata = '0;
    csr_wstrb = '0;
    csr_wvalid = 1'b0;
    csr_bready = 1'b0;
    csr_araddr = '0;
    csr_arprot = '0;
    csr_arvalid = 1'b0;
    csr_rready = 1'b0;
    uart_rx = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

`ifdef SOC_AI_E2E_USE_UART
    @(negedge clk);
    uart_loader_i.uart_rx_i_dut.queue[0] = 8'h00;
    uart_loader_i.uart_rx_i_dut.queue[1] = 8'h01;
    uart_loader_i.uart_rx_i_dut.queue[2] = 8'h02;
    uart_loader_i.uart_rx_i_dut.queue[3] = 8'h03;
    uart_loader_i.uart_rx_i_dut.queue[4] = 8'h04;
    uart_loader_i.uart_rx_i_dut.queue[5] = 8'h05;
    uart_loader_i.uart_rx_i_dut.queue[6] = 8'h06;
    uart_loader_i.uart_rx_i_dut.queue[7] = 8'h07;
    uart_loader_i.uart_rx_i_dut.queue[8] = 8'h08;
    uart_loader_i.uart_rx_i_dut.read_ptr = 5'd0;
    uart_loader_i.uart_rx_i_dut.write_ptr = 5'd9;
`else
    axi_mem_write(AI_BASE + 32'h0, 32'h0302_0100, 4'hf);
    axi_mem_write(AI_BASE + 32'h4, 32'h0706_0504, 4'hf);
    axi_mem_write(AI_BASE + 32'h8, 32'h0000_0008, 4'h1);
`endif

    axi_csr_write(REG_INPUT_BASE, AI_BASE);
    axi_csr_write(REG_INPUT_LEN, 32'd9);
    axi_csr_write(REG_OUTPUT_BASE, AI_OUT_BASE);
    axi_csr_write(REG_UART_BAUD, 32'h0);
    axi_csr_write(REG_CTRL, 32'h0000_0008);

`ifdef SOC_AI_E2E_USE_UART
    axi_csr_write(REG_CTRL, 32'h0000_0004);

    done_seen = 1'b0;
    for (poll_idx = 0; poll_idx < 2000 && !done_seen; poll_idx = poll_idx + 1) begin
      axi_csr_read(REG_STATUS, data);
      done_seen = data[4];
    end

    if (!done_seen) begin
      $display("tb_soc_ai_island_e2e: UART loader done timeout");
      $fatal(1);
    end
    if (data[5]) begin
      $display("tb_soc_ai_island_e2e: UART loader error status=%h", data);
      $fatal(1);
    end

    axi_csr_read(REG_UART_COUNT, data);
    check_word("UART byte count", data, 32'd9);
    axi_mem_read(AI_BASE + 32'h0, data);
    check_word("UART input word0", data, 32'h0302_0100);
    axi_mem_read(AI_BASE + 32'h4, data);
    check_word("UART input word1", data, 32'h0706_0504);
    axi_mem_read(AI_BASE + 32'h8, data);
    check_word("UART input word2", {24'h0, data[7:0]}, 32'h0000_0008);

    axi_csr_write(REG_CTRL, 32'h0000_0008);
`endif
    axi_csr_write(REG_CTRL, 32'h0000_0003);

    done_seen = 1'b0;
    for (poll_idx = 0; poll_idx < 2000 && !done_seen; poll_idx = poll_idx + 1) begin
      axi_csr_read(REG_STATUS, data);
      done_seen = data[1];
    end

    if (!done_seen) begin
      $display("tb_soc_ai_island_e2e: accelerator done timeout");
      $fatal(1);
    end
    if (!ai_irq) begin
      $display("tb_soc_ai_island_e2e: IRQ missing after done");
      $fatal(1);
    end

    axi_csr_read(REG_RESULT_CLASS, data);
    check_word("CSR class", {30'h0, data[1:0]}, {30'h0, AI_GOLDEN_RESULT_CLASS[1:0]});
    axi_csr_read(REG_RESULT0, data);
    check_score("CSR score0", data, AI_GOLDEN_SCORE0);
    axi_csr_read(REG_RESULT1, data);
    check_score("CSR score1", data, AI_GOLDEN_SCORE1);
    axi_csr_read(REG_RESULT2, data);
    check_score("CSR score2", data, AI_GOLDEN_SCORE2);
    axi_csr_read(REG_RESULT3, data);
    check_score("CSR score3", data, AI_GOLDEN_SCORE3);
    axi_csr_read(REG_CYCLES, data);
    if (data == 32'h0) begin
      $display("tb_soc_ai_island_e2e: cycle counter did not advance");
      $fatal(1);
    end

    axi_mem_read(AI_OUT_BASE + 32'h00, data);
    check_word("AI_MEM class", {30'h0, data[1:0]}, {30'h0, AI_GOLDEN_RESULT_CLASS[1:0]});
    axi_mem_read(AI_OUT_BASE + 32'h04, data);
    check_score("AI_MEM score0", data, AI_GOLDEN_SCORE0);
    axi_mem_read(AI_OUT_BASE + 32'h08, data);
    check_score("AI_MEM score1", data, AI_GOLDEN_SCORE1);
    axi_mem_read(AI_OUT_BASE + 32'h0c, data);
    check_score("AI_MEM score2", data, AI_GOLDEN_SCORE2);
    axi_mem_read(AI_OUT_BASE + 32'h10, data);
    check_score("AI_MEM score3", data, AI_GOLDEN_SCORE3);

    $display("tb_soc_ai_island_e2e: PASS class=%0d scores=%0d,%0d,%0d,%0d",
             AI_GOLDEN_RESULT_CLASS,
             AI_GOLDEN_SCORE0,
             AI_GOLDEN_SCORE1,
             AI_GOLDEN_SCORE2,
             AI_GOLDEN_SCORE3);
    $finish;
  end

  initial begin
    repeat (5000) @(posedge clk);
    $display("tb_soc_ai_island_e2e: TIMEOUT");
    $fatal(1);
  end

endmodule
