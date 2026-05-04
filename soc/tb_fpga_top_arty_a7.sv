module tb_fpga_top_arty_a7;
  logic CLK100MHZ;
  logic [3:0] sw;
  logic [3:0] btn;
  logic uart_txd_in;
  logic uart_rxd_out;
  logic ck_scl;
  wire ck_sda;
  wire [3:0] qspi_dq;
  logic qspi_cs;
  logic ja0_i, ja1_o;

  fpga_top_arty_a7 dut (
    .CLK100MHZ(CLK100MHZ),
    .sw(sw),
    .btn(btn),
    .uart_txd_in(uart_txd_in),
    .uart_rxd_out(uart_rxd_out),
    .ck_sda(ck_sda),
    .ck_scl(ck_scl),
    .qspi_dq(qspi_dq),
    .qspi_cs(qspi_cs),
    .ja0_i(ja0_i),
    .ja1_o(ja1_o),
    .led(),
    .led0_r(),
    .led1_r(),
    .led2_r(),
    .led3_r()
  );

  always #5 CLK100MHZ = ~CLK100MHZ; // 100MHz

  initial begin
    CLK100MHZ = 0;
    sw = '0;
    btn = '0;
    uart_rxd_out = 1;
    ja0_i = 1;
    
    // reset is active high on btn[0] in the Arty A7 top wrapper
    btn[0] = 1;
    #100 btn[0] = 0;
  end

endmodule
