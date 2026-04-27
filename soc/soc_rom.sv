module soc_rom #(
    parameter string INIT_FILE = "",
    parameter int DEPTH_WORDS = 1024
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        req_i,
    input  logic [31:0] addr_i,
    output logic        gnt_o,
    output logic        rvalid_o,
    output logic [31:0] rdata_o
);

  import soc_map_pkg::*;

  logic [31:0] local_addr;

  assign gnt_o     = req_i;
  assign local_addr = addr_i - SOC_ROM_BASE_ADDR;

  soc_mem_sp #(
      .DEPTH_WORDS(DEPTH_WORDS),
      .READ_ONLY  (1'b1)
  ) mem_i (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .req_i   (req_i),
      .we_i    (1'b0),
      .be_i    (4'h0),
      .addr_i  (local_addr),
      .wdata_i (32'h0),
      .rvalid_o(rvalid_o),
      .rdata_o (rdata_o)
  );

  initial begin
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem_i.mem);
    end
  end

endmodule
