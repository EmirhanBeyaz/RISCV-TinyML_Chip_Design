// Keep the wrapper self-contained for Vivado GUI projects.
`ifndef N_GPIO
`define N_GPIO 32
`endif

module soc_apb_gpio #(
    parameter int APB_ADDR_WIDTH = 12
) (
    input  logic                 clk_i,
    input  logic                 rst_ni,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0]          pwdata_i,
    input  logic                 pwrite_i,
    input  logic                 psel_i,
    input  logic                 penable_i,
    output logic [31:0]          prdata_o,
    output logic                 pready_o,
    output logic                 pslverr_o,
    input  logic [`N_GPIO-1:0]   gpio_in_i,
    output logic [`N_GPIO-1:0]   gpio_in_sync_o,
    output logic [`N_GPIO-1:0]   gpio_out_o,
    output logic [`N_GPIO-1:0]   gpio_dir_o,
    output logic [`N_GPIO-1:0]   gpio_irq_o
);

  apb_gpiov2 #(
      .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
  ) gpio_i (
      .HCLK           (clk_i),
      .HRESETn        (rst_ni),
      .dft_cg_enable_i(1'b0),
      .PADDR          (paddr_i),
      .PWDATA         (pwdata_i),
      .PWRITE         (pwrite_i),
      .PSEL           (psel_i),
      .PENABLE        (penable_i),
      .PRDATA         (prdata_o),
      .PREADY         (pready_o),
      .PSLVERR        (pslverr_o),
      .gpio_in        (gpio_in_i),
      .gpio_in_sync   (gpio_in_sync_o),
      .gpio_out       (gpio_out_o),
      .gpio_dir       (gpio_dir_o),
      .interrupt      (gpio_irq_o)
  );

endmodule
