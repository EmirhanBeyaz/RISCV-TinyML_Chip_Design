module soc_dmem #(
    parameter int DEPTH_WORDS = 2048
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] s_axi_awaddr_i,
    input  logic [ 2:0] s_axi_awprot_i,
    input  logic        s_axi_awvalid_i,
    output logic        s_axi_awready_o,
    input  logic [31:0] s_axi_wdata_i,
    input  logic [ 3:0] s_axi_wstrb_i,
    input  logic        s_axi_wvalid_i,
    output logic        s_axi_wready_o,
    output logic [ 1:0] s_axi_bresp_o,
    output logic        s_axi_bvalid_o,
    input  logic        s_axi_bready_i,
    input  logic [31:0] s_axi_araddr_i,
    input  logic [ 2:0] s_axi_arprot_i,
    input  logic        s_axi_arvalid_i,
    output logic        s_axi_arready_o,
    output logic [31:0] s_axi_rdata_o,
    output logic [ 1:0] s_axi_rresp_o,
    output logic        s_axi_rvalid_o,
    input  logic        s_axi_rready_i
);

  import soc_map_pkg::*;

  logic        aw_seen_q;
  logic        w_seen_q;
  logic        mem_pending_q;
  logic        mem_is_write_q;
  logic [31:0] aw_addr_q;
  logic [31:0] wdata_q;
  logic [ 3:0] wstrb_q;
  logic        bvalid_q;
  logic        rvalid_q;
  logic [31:0] rdata_q;
  logic [ 1:0] bresp_q;
  logic [ 1:0] rresp_q;

  logic        mem_req;
  logic        mem_we;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [ 3:0] mem_be;
  logic        mem_rvalid;
  logic [31:0] mem_rdata;

  logic [31:0] local_mem_addr;
  logic        aw_fire;
  logic        w_fire;
  logic        ar_fire;
  logic        aw_complete;
  logic        w_complete;
  logic        issue_write;
  logic        issue_read;
  logic [31:0] write_addr_now;
  logic [31:0] write_data_now;
  logic [ 3:0] write_strb_now;

  assign s_axi_awready_o = ~aw_seen_q & ~bvalid_q & ~rvalid_q & ~mem_pending_q;
  assign s_axi_wready_o  = ~w_seen_q  & ~bvalid_q & ~rvalid_q & ~mem_pending_q;
  assign s_axi_bresp_o   = bresp_q;
  assign s_axi_bvalid_o  = bvalid_q;
  assign s_axi_arready_o = ~aw_seen_q & ~w_seen_q & ~bvalid_q & ~rvalid_q & ~mem_pending_q;
  assign s_axi_rdata_o   = rdata_q;
  assign s_axi_rresp_o   = rresp_q;
  assign s_axi_rvalid_o  = rvalid_q;
  assign aw_fire         = s_axi_awvalid_i && s_axi_awready_o;
  assign w_fire          = s_axi_wvalid_i && s_axi_wready_o;
  assign ar_fire         = s_axi_arvalid_i && s_axi_arready_o;
  assign aw_complete     = aw_seen_q | aw_fire;
  assign w_complete      = w_seen_q | w_fire;
  assign write_addr_now  = aw_seen_q ? aw_addr_q : s_axi_awaddr_i;
  assign write_data_now  = w_seen_q ? wdata_q   : s_axi_wdata_i;
  assign write_strb_now  = w_seen_q ? wstrb_q   : s_axi_wstrb_i;
  assign issue_write     = !mem_pending_q && !bvalid_q && !rvalid_q && aw_complete && w_complete;
  assign issue_read      = !mem_pending_q && !bvalid_q && !rvalid_q &&
                           ar_fire && !aw_complete && !w_complete;

  assign local_mem_addr = mem_addr - SOC_DMEM_BASE_ADDR;
  assign mem_req        = issue_write || issue_read;
  assign mem_we         = issue_write;
  assign mem_addr       = issue_write ? write_addr_now : s_axi_araddr_i;
  assign mem_wdata      = write_data_now;
  assign mem_be         = write_strb_now;

  soc_mem_sp #(
      .DEPTH_WORDS(DEPTH_WORDS),
      .READ_ONLY  (1'b0)
  ) mem_i (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .req_i   (mem_req),
      .we_i    (mem_we),
      .be_i    (mem_be),
      .addr_i  (local_mem_addr),
      .wdata_i (mem_wdata),
      .rvalid_o(mem_rvalid),
      .rdata_o (mem_rdata)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_seen_q     <= 1'b0;
      w_seen_q      <= 1'b0;
      mem_pending_q <= 1'b0;
      mem_is_write_q <= 1'b0;
      aw_addr_q     <= '0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      bvalid_q      <= 1'b0;
      rvalid_q      <= 1'b0;
      rdata_q       <= '0;
      bresp_q       <= 2'b00;
      rresp_q       <= 2'b00;
    end else begin
      if (aw_fire) begin
        aw_seen_q <= 1'b1;
        aw_addr_q <= s_axi_awaddr_i;
      end

      if (w_fire) begin
        w_seen_q <= 1'b1;
        wdata_q  <= s_axi_wdata_i;
        wstrb_q  <= s_axi_wstrb_i;
      end

      if (issue_write) begin
        aw_seen_q      <= 1'b0;
        w_seen_q       <= 1'b0;
        mem_pending_q  <= 1'b1;
        mem_is_write_q <= 1'b1;
        bresp_q        <= 2'b00;
      end

      if (issue_read) begin
        mem_pending_q  <= 1'b1;
        mem_is_write_q <= 1'b0;
        rresp_q        <= 2'b00;
      end

      if (mem_rvalid) begin
        mem_pending_q <= 1'b0;
        if (mem_is_write_q) begin
          bvalid_q <= 1'b1;
        end else begin
          rdata_q  <= mem_rdata;
          rvalid_q <= 1'b1;
        end
      end

      if (bvalid_q && s_axi_bready_i) begin
        bvalid_q <= 1'b0;
      end

      if (rvalid_q && s_axi_rready_i) begin
        rvalid_q <= 1'b0;
      end
    end
  end

endmodule
