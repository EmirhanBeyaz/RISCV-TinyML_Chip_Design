`timescale 1ns/1ps

module tb_soc_benchmark_icarus;

  reg clk;
  reg rst_ni;

  reg        uart0_rx;
  wire       uart0_tx;
  reg        uart1_rx;
  wire       uart1_tx;

  reg  [7:0] sw;
  wire [7:0] led;

  wire       i2c_scl;
  wire       i2c_sda;

  wire       qspi_cs_n;
  wire       qspi_sck;
  wire [3:0] qspi_dq;

  localparam integer CLK_PERIOD_NS = 20;     // 50 MHz
  localparam integer UART_BIT_NS   = 8680;   // 50 MHz / 434 ~= 115200 baud
  localparam integer FINISH_LEN    = 19;

  integer uart_match_idx;

  fpga_top #(
      .BOOT_ADDR            (32'h0001_0000),
      .MTVEC_ADDR           (32'h0001_0000),
      .DM_HALT_ADDR         (32'h0000_0000),
      .DM_EXCEPTION_ADDR    (32'h0000_0000),
      .HART_ID              (32'h0000_0000),
      .ROM_INIT_FILE        (""),
      .IMEM_INIT_FILE       ("./soc/sw/benchmark_imem.hex"),
      .BOOT_COPY_XIP_ENABLE (1'b0),
      .QSPI_INIT_ENABLE     (1'b0),
      .EXT_AXI_RAM_WORDS    (1024)
  ) dut (
      .clk_i       (clk),
      .rst_ni      (rst_ni),

      .uart0_rx_i  (uart0_rx),
      .uart0_tx_o  (uart0_tx),
      .uart1_rx_i  (uart1_rx),
      .uart1_tx_o  (uart1_tx),

      .sw_i        (sw),
      .led_o       (led),

      .i2c_scl_io  (i2c_scl),
      .i2c_sda_io  (i2c_sda),

      .qspi_cs_n_o (qspi_cs_n),
      .qspi_sck_o  (qspi_sck),
      .qspi_dq_io  (qspi_dq)
  );

  always #(CLK_PERIOD_NS/2) clk = ~clk;

  task uart_wait_and_read_char;
    output [7:0] ch;
    integer i;
    begin
      ch = 8'h00;

      @(negedge uart0_tx);

      #(UART_BIT_NS + UART_BIT_NS/2);

      for (i = 0; i < 8; i = i + 1) begin
        ch[i] = uart0_tx;
        #(UART_BIT_NS);
      end

      // Stop bit süresi
      #(UART_BIT_NS);
    end
  endtask

  task update_finish_match;
    input [7:0] ch;
    reg [8*FINISH_LEN-1:0] target;
    begin
      target = "Benchmark finished.";

      if (ch == target[8*(FINISH_LEN-1-uart_match_idx) +: 8]) begin
        uart_match_idx = uart_match_idx + 1;
      end else begin
        uart_match_idx = 0;
      end

      if (uart_match_idx == FINISH_LEN) begin
        $display("\n[TB] Benchmark finished string yakalandi.");
        #1000;
        $display("[TB] LED final = %h", led);
        $display("---- SOC BENCHMARK TEST PASS ----");
        $finish;
      end
    end
  endtask

  initial begin
    reg [7:0] ch;

    forever begin
      uart_wait_and_read_char(ch);
      $write("%c", ch);
      update_finish_match(ch);
    end
  end

  initial begin
    $dumpfile("soc_benchmark.vcd");
    $dumpvars(0, tb_soc_benchmark_icarus);

    clk = 1'b0;
    rst_ni = 1'b0;

    uart0_rx = 1'b1;
    uart1_rx = 1'b1;
    sw = 8'h00;

    uart_match_idx = 0;

    repeat (20) @(posedge clk);
    rst_ni = 1'b1;

    $display("[TB] SoC benchmark simulation started.");
  end

  initial begin
    #500000000; // 500 ms timeout
    $display("\n[TIMEOUT] SoC benchmark simulasyonu zaman asimina ugradi.");
    $display("[TB] LED = %h", led);
    $finish;
  end

endmodule
