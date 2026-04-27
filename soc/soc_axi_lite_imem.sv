module soc_axi_lite_imem (
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
    input  logic        s_axi_rready_i,
    output logic        imem_req_o,
    output logic        imem_we_o,
    output logic [ 3:0] imem_be_o,
    output logic [31:0] imem_addr_o,
    output logic [31:0] imem_wdata_o,
    input  logic        imem_gnt_i,
    input  logic        imem_rvalid_i,
    input  logic [31:0] imem_rdata_i
);

  logic        aw_seen_q;
  logic        w_seen_q;
  logic [31:0] aw_addr_q;
  logic [31:0] wdata_q;
  logic [ 3:0] wstrb_q;

  logic        req_active_q;
  logic        req_issued_q;
  logic        req_is_write_q;
  logic [31:0] req_addr_q;
  logic [31:0] req_wdata_q;
  logic [ 3:0] req_strb_q;

  logic        bvalid_q;
  logic [ 1:0] bresp_q;
  logic        rvalid_q;
  logic [31:0] rdata_q;
  logic [ 1:0] rresp_q;

  logic        aw_fire;
  logic        w_fire;
  logic        ar_fire;
  logic        aw_complete;
  logic        w_complete;
  logic [31:0] write_addr_now;
  logic [31:0] write_data_now;
  logic [ 3:0] write_strb_now;

  assign s_axi_awready_o = ~aw_seen_q & ~bvalid_q & ~rvalid_q & ~req_active_q;
  assign s_axi_wready_o  = ~w_seen_q  & ~bvalid_q & ~rvalid_q & ~req_active_q;
  assign s_axi_bresp_o   = bresp_q;
  assign s_axi_bvalid_o  = bvalid_q;
  assign s_axi_arready_o = ~aw_seen_q & ~w_seen_q & ~bvalid_q & ~rvalid_q & ~req_active_q;
  assign s_axi_rdata_o   = rdata_q;
  assign s_axi_rresp_o   = rresp_q;
  assign s_axi_rvalid_o  = rvalid_q;

  assign aw_fire        = s_axi_awvalid_i && s_axi_awready_o;
  assign w_fire         = s_axi_wvalid_i && s_axi_wready_o;
  assign ar_fire        = s_axi_arvalid_i && s_axi_arready_o;
  assign aw_complete    = aw_seen_q | aw_fire;
  assign w_complete     = w_seen_q | w_fire;
  assign write_addr_now = aw_seen_q ? aw_addr_q : s_axi_awaddr_i;
  assign write_data_now = w_seen_q ? wdata_q   : s_axi_wdata_i;
  assign write_strb_now = w_seen_q ? wstrb_q   : s_axi_wstrb_i;

  assign imem_req_o   = req_active_q && !req_issued_q;
  assign imem_we_o    = req_is_write_q;
  assign imem_be_o    = req_strb_q;
  assign imem_addr_o  = req_addr_q;
  assign imem_wdata_o = req_wdata_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_seen_q      <= 1'b0;
      w_seen_q       <= 1'b0;
      aw_addr_q      <= '0;
      wdata_q        <= '0;
      wstrb_q        <= '0;
      req_active_q   <= 1'b0;
      req_issued_q   <= 1'b0;
      req_is_write_q <= 1'b0;
      req_addr_q     <= '0;
      req_wdata_q    <= '0;
      req_strb_q     <= '0;
      bvalid_q       <= 1'b0;
      bresp_q        <= 2'b00;
      rvalid_q       <= 1'b0;
      rdata_q        <= '0;
      rresp_q        <= 2'b00;
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

      if (!req_active_q && !bvalid_q && !rvalid_q && aw_complete && w_complete) begin
        aw_seen_q      <= 1'b0;
        w_seen_q       <= 1'b0;
        req_active_q   <= 1'b1;
        req_issued_q   <= 1'b0;
        req_is_write_q <= 1'b1;
        req_addr_q     <= write_addr_now;
        req_wdata_q    <= write_data_now;
        req_strb_q     <= write_strb_now;
      end

      if (!req_active_q && !bvalid_q && !rvalid_q && ar_fire) begin
        req_active_q   <= 1'b1;
        req_issued_q   <= 1'b0;
        req_is_write_q <= 1'b0;
        req_addr_q     <= s_axi_araddr_i;
        req_wdata_q    <= 32'h0;
        req_strb_q     <= 4'h0;
      end

      if (imem_req_o && imem_gnt_i) begin
        req_issued_q <= 1'b1;
      end

      if (req_active_q && req_issued_q && imem_rvalid_i) begin
        req_active_q <= 1'b0;
        req_issued_q <= 1'b0;
        if (req_is_write_q) begin
          bvalid_q <= 1'b1;
          bresp_q  <= 2'b00;
        end else begin
          rvalid_q <= 1'b1;
          rresp_q  <= 2'b00;
          rdata_q  <= imem_rdata_i;
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

  logic _unused_ok;
  assign _unused_ok = &{1'b0, s_axi_awprot_i, s_axi_arprot_i};

endmodule
