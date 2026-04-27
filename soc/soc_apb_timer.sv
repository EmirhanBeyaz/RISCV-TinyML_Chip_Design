module soc_apb_timer #(
    parameter int APB_ADDR_WIDTH = 12
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0]               pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [31:0]               prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,
    input  logic                      timer_ref_clk_i,
    input  logic                      timer_stoptimer_i,
    input  logic                      timer_event_lo_i,
    input  logic                      timer_event_hi_i,
    output logic                      timer_irq_lo_o,
    output logic                      timer_irq_hi_o,
    output logic                      timer_busy_o
);

  apb_timer_unit #(
      .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
  ) timer_i (
      .HCLK       (clk_i),
      .HRESETn    (rst_ni),
      .PADDR      (paddr_i),
      .PWDATA     (pwdata_i),
      .PWRITE     (pwrite_i),
      .PSEL       (psel_i),
      .PENABLE    (penable_i),
      .PRDATA     (prdata_o),
      .PREADY     (pready_o),
      .PSLVERR    (pslverr_o),
      .ref_clk_i  (timer_ref_clk_i),
      .stoptimer_i(timer_stoptimer_i),
      .event_lo_i (timer_event_lo_i),
      .event_hi_i (timer_event_hi_i),
      .irq_lo_o   (timer_irq_lo_o),
      .irq_hi_o   (timer_irq_hi_o),
      .busy_o     (timer_busy_o)
  );

endmodule
