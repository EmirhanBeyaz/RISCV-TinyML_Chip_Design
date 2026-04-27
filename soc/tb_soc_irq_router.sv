`timescale 1ns/1ps

module tb_soc_irq_router;

  import soc_map_pkg::*;

  logic [31:0] ext_irq;
  logic [31:0] gpio_irq;
  logic        timer_irq_lo;
  logic        timer_irq_hi;
  logic        uart0_irq;
  logic        uart1_irq;
  logic        ai_irq;
  logic [31:0] local_irq;
  logic [31:0] core_irq;

  soc_irq_router dut (
      .ext_irq_i      (ext_irq),
      .gpio_irq_i     (gpio_irq),
      .timer_irq_lo_i (timer_irq_lo),
      .timer_irq_hi_i (timer_irq_hi),
      .uart0_irq_i    (uart0_irq),
      .uart1_irq_i    (uart1_irq),
      .ai_irq_i       (ai_irq),
      .local_irq_o    (local_irq),
      .core_irq_o     (core_irq)
  );

  task automatic check_eq(input logic [31:0] got, input logic [31:0] exp, input string what);
    begin
      if (got !== exp) begin
        $display("tb_soc_irq_router: %s mismatch got=%h exp=%h", what, got, exp);
        $fatal(1);
      end
    end
  endtask

  initial begin
    ext_irq      = '0;
    gpio_irq     = '0;
    timer_irq_lo = 1'b0;
    timer_irq_hi = 1'b0;
    uart0_irq    = 1'b0;
    uart1_irq    = 1'b0;
    ai_irq       = 1'b0;

    #1;
    check_eq(local_irq, 32'h0000_0000, "local_irq reset");
    check_eq(core_irq, 32'h0000_0000, "core_irq reset");

    timer_irq_lo = 1'b1;
    #1;
    check_eq(local_irq, 32'h0000_0080, "timer low maps to MTI");
    check_eq(core_irq, 32'h0000_0080, "core_irq timer low");

    timer_irq_lo = 1'b0;
    timer_irq_hi = 1'b1;
    #1;
    check_eq(local_irq, 32'h0001_0000, "timer high maps to fast irq");
    check_eq(core_irq, 32'h0001_0000, "core_irq timer high");

    timer_irq_hi = 1'b0;
    gpio_irq[5]  = 1'b1;
    #1;
    check_eq(local_irq, 32'h0000_0800, "gpio summary maps to MEI");
    check_eq(core_irq, 32'h0000_0800, "core_irq gpio summary");

    gpio_irq = '0;
    uart0_irq = 1'b1;
    uart1_irq = 1'b1;
    ai_irq    = 1'b1;
    #1;
    check_eq(local_irq, 32'h000E_0000, "custom fast irqs");
    check_eq(core_irq, 32'h000E_0000, "core_irq custom fast");

    ext_irq   = 32'h8000_0000;
    gpio_irq[0] = 1'b1;
    #1;
    check_eq(local_irq, 32'h000E_0800, "local_irq with gpio and fast");
    check_eq(core_irq, 32'h800E_0800, "external irq OR local");

    $display("tb_soc_irq_router: PASS");
    $finish;
  end

endmodule
