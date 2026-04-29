module soc_imem #(
    parameter INIT_FILE = "",
    parameter int DEPTH_WORDS = 2048
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        instr_req_i,
    input  logic [31:0] instr_addr_i,
    output logic        instr_gnt_o,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o,
    input  logic        data_req_i,
    input  logic        data_we_i,
    input  logic [ 3:0] data_be_i,
    input  logic [31:0] data_addr_i,
    input  logic [31:0] data_wdata_i,
    output logic        data_gnt_o,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o,
    input  logic        boot_req_i,
    input  logic        boot_we_i,
    input  logic [ 3:0] boot_be_i,
    input  logic [31:0] boot_addr_i,
    input  logic [31:0] boot_wdata_i,
    output logic        boot_gnt_o
);

  import soc_map_pkg::*;

  logic        mem_req;
  logic        mem_we;
  logic [ 3:0] mem_be;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic        mem_rvalid;
  logic [31:0] mem_rdata;
  typedef enum logic [1:0] {
    MEM_SRC_NONE  = 2'b00,
    MEM_SRC_INSTR = 2'b01,
    MEM_SRC_DATA  = 2'b10,
    MEM_SRC_BOOT  = 2'b11
  } mem_src_e;
  mem_src_e     mem_src_q;
  logic        mem_is_write_q;
  logic        sel_instr;
  logic        sel_data;
  logic        sel_boot;

  assign sel_boot  = boot_req_i;
  assign sel_data  = !boot_req_i && data_req_i;
  assign sel_instr = !boot_req_i && !data_req_i && instr_req_i;

  assign instr_gnt_o = sel_instr;
  assign data_gnt_o  = sel_data;
  assign boot_gnt_o  = sel_boot;

  assign mem_req   = sel_boot || sel_data || sel_instr;
  assign mem_we    = sel_boot ? boot_we_i : (sel_data ? data_we_i : 1'b0);
  assign mem_be    = sel_boot ? boot_be_i : (sel_data ? data_be_i : 4'h0);
  assign mem_addr  = (sel_boot ? boot_addr_i : (sel_data ? data_addr_i : instr_addr_i)) - SOC_IMEM_BASE_ADDR;
  assign mem_wdata = sel_boot ? boot_wdata_i : (sel_data ? data_wdata_i : 32'h0);

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (instr_req_i && instr_gnt_o && (instr_addr_i[1:0] != 2'b00)) begin
      $error("soc_imem: misaligned fetch at %h", instr_addr_i);
      $fatal(1);
    end
  end
`endif

  assign instr_rvalid_o = mem_rvalid && (mem_src_q == MEM_SRC_INSTR) && !mem_is_write_q;
  assign instr_rdata_o  = mem_rdata;
  assign data_rvalid_o  = mem_rvalid && (mem_src_q == MEM_SRC_DATA);
  assign data_rdata_o   = mem_rdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_src_q      <= MEM_SRC_NONE;
      mem_is_write_q <= 1'b0;
    end else if (mem_req) begin
      mem_src_q      <= sel_boot ? MEM_SRC_BOOT : (sel_data ? MEM_SRC_DATA : MEM_SRC_INSTR);
      mem_is_write_q <= mem_we;
    end
  end

  soc_mem_sp #(
      .DEPTH_WORDS(DEPTH_WORDS),
      .READ_ONLY  (1'b0)
  ) mem_i (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .req_i   (mem_req),
      .we_i    (mem_we),
      .be_i    (mem_be),
      .addr_i  (mem_addr),
      .wdata_i (mem_wdata),
      .rvalid_o(mem_rvalid),
      .rdata_o (mem_rdata)
  );

  initial begin
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem_i.mem);
    end
  end

endmodule
