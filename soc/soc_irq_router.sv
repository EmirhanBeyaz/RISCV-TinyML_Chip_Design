module soc_irq_router (
    input  logic [31:0] ext_irq_i,
    input  logic [31:0] gpio_irq_i,
    input  logic        timer_irq_lo_i,
    input  logic        timer_irq_hi_i,
    input  logic        uart0_irq_i,
    input  logic        uart1_irq_i,
    input  logic        ai_irq_i,
    output logic [31:0] local_irq_o,
    output logic [31:0] core_irq_o
);

  import soc_map_pkg::*;

  always_comb begin
    local_irq_o = '0;

    // Keep standard interrupt IDs for the most common machine-level sources.
    local_irq_o[SOC_IRQ_MTI_BIT] = timer_irq_lo_i;
    local_irq_o[SOC_IRQ_MEI_BIT] = |gpio_irq_i;

    // Use custom fast interrupt lines for SoC-specific extensions.
    local_irq_o[SOC_IRQ_FAST_TIMER_HI_BIT] = timer_irq_hi_i;
    local_irq_o[SOC_IRQ_FAST_UART0_BIT]    = uart0_irq_i;
    local_irq_o[SOC_IRQ_FAST_UART1_BIT]    = uart1_irq_i;
    local_irq_o[SOC_IRQ_FAST_AI_BIT]       = ai_irq_i;

    core_irq_o = ext_irq_i | local_irq_o;
  end

endmodule
