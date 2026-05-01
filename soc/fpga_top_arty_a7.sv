module fpga_top_arty_a7 #(
    parameter logic [31:0] BOOT_ADDR             = 32'h0000_0000,
    parameter logic [31:0] MTVEC_ADDR            = 32'h0000_0000,
    parameter logic [31:0] DM_HALT_ADDR          = 32'h0000_0000,
    parameter logic [31:0] DM_EXCEPTION_ADDR     = 32'h0000_0000,
    parameter logic [31:0] HART_ID               = 32'h0000_0000,
    parameter              ROM_INIT_FILE         = "",
    parameter              IMEM_INIT_FILE        = "",
    parameter bit          BOOT_COPY_XIP_ENABLE  = 1'b0,
    parameter bit          QSPI_INIT_ENABLE      = 1'b1,
    parameter int unsigned EXT_AXI_RAM_WORDS     = 1024
) (
    input  wire        CLK100MHZ,
    input  wire [3:0]  btn,
    input  wire [3:0]  sw,
    output wire [3:0]  led,
    output wire        led0_r,
    output wire        led1_r,
    output wire        led2_r,
    output wire        led3_r,

    input  wire        uart_rxd_out,
    output wire        uart_txd_in,
    input  wire        ja0_i,
    output wire        ja1_o,

    output wire        ck_scl,
    inout  wire        ck_sda,

    output wire        qspi_cs,
    inout  wire [3:0]  qspi_dq
);

  logic       clk_50_q;
  logic       clk_50;
  logic       rst_ni;
  logic [7:0] sw_i;
  logic [7:0] led_o;
  logic       qspi_sck;

  always_ff @(posedge CLK100MHZ or posedge btn[0]) begin
    if (btn[0]) begin
      clk_50_q <= 1'b0;
    end else begin
      clk_50_q <= ~clk_50_q;
    end
  end

  BUFG soc_clk_bufg_i (
      .I(clk_50_q),
      .O(clk_50)
  );

  assign rst_ni = ~btn[0];
  assign sw_i   = {btn[3:1], 1'b0, sw};

  assign led    = led_o[3:0];
  assign led0_r = led_o[4];
  assign led1_r = led_o[5];
  assign led2_r = led_o[6];
  assign led3_r = led_o[7];

  fpga_top #(
      .BOOT_ADDR            (BOOT_ADDR),
      .MTVEC_ADDR           (MTVEC_ADDR),
      .DM_HALT_ADDR         (DM_HALT_ADDR),
      .DM_EXCEPTION_ADDR    (DM_EXCEPTION_ADDR),
      .HART_ID              (HART_ID),
      .ROM_INIT_FILE        (ROM_INIT_FILE),
      .IMEM_INIT_FILE       (IMEM_INIT_FILE),
      .BOOT_COPY_XIP_ENABLE (BOOT_COPY_XIP_ENABLE),
      .QSPI_INIT_ENABLE     (QSPI_INIT_ENABLE),
      .EXT_AXI_RAM_WORDS    (EXT_AXI_RAM_WORDS)
  ) fpga_top_i (
      .clk_i       (clk_50),
      .rst_ni      (rst_ni),
      .uart0_rx_i  (uart_rxd_out),
      .uart0_tx_o  (uart_txd_in),
      .uart1_rx_i  (ja0_i),
      .uart1_tx_o  (ja1_o),
      .sw_i        (sw_i),
      .led_o       (led_o),
      .i2c_scl_io  (ck_scl),
      .i2c_sda_io  (ck_sda),
      .qspi_cs_n_o (qspi_cs),
      .qspi_sck_o  (qspi_sck),
      .qspi_dq_io  (qspi_dq)
  );

  STARTUPE2 #(
      .PROG_USR("FALSE"),
      .SIM_CCLK_FREQ(0.0)
  ) startup_i (
      .CFGCLK(),
      .CFGMCLK(),
      .EOS(),
      .PREQ(),
      .CLK(1'b0),
      .GSR(1'b0),
      .GTS(1'b0),
      .KEYCLEARB(1'b1),
      .PACK(1'b0),
      .USRCCLKO(qspi_sck),
      .USRCCLKTS(1'b0),
      .USRDONEO(1'b1),
      .USRDONETS(1'b1)
  );

endmodule
