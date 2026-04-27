module cv32e40p_clock_gate (
    input  logic clk_i,
    input  logic en_i,
    input  logic scan_cg_en_i,
    output logic clk_o
);

  logic unused_inputs;

  // FPGA flow: keep the core functionally correct and avoid synthesizing the
  // simulation-only latch-based clock gate. Power-oriented clock gating can be
  // revisited later with a board-specific/global-clock primitive strategy.
  assign clk_o = clk_i;

  assign unused_inputs = en_i | scan_cg_en_i;

endmodule
