module soc_axi_lite_1x2 #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] LOCAL0_BASE_ADDR = 32'h1000_4000,
    parameter logic [ADDR_WIDTH-1:0] LOCAL0_SIZE_BYTES = 32'h0000_1000
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,

    input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr_i,
    input  logic [2:0]                s_axi_awprot_i,
    input  logic                      s_axi_awvalid_i,
    output logic                      s_axi_awready_o,
    input  logic [DATA_WIDTH-1:0]     s_axi_wdata_i,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb_i,
    input  logic                      s_axi_wvalid_i,
    output logic                      s_axi_wready_o,
    output logic [1:0]                s_axi_bresp_o,
    output logic                      s_axi_bvalid_o,
    input  logic                      s_axi_bready_i,
    input  logic [ADDR_WIDTH-1:0]     s_axi_araddr_i,
    input  logic [2:0]                s_axi_arprot_i,
    input  logic                      s_axi_arvalid_i,
    output logic                      s_axi_arready_o,
    output logic [DATA_WIDTH-1:0]     s_axi_rdata_o,
    output logic [1:0]                s_axi_rresp_o,
    output logic                      s_axi_rvalid_o,
    input  logic                      s_axi_rready_i,

    output logic [ADDR_WIDTH-1:0]     local0_axi_awaddr_o,
    output logic [2:0]                local0_axi_awprot_o,
    output logic                      local0_axi_awvalid_o,
    input  logic                      local0_axi_awready_i,
    output logic [DATA_WIDTH-1:0]     local0_axi_wdata_o,
    output logic [(DATA_WIDTH/8)-1:0] local0_axi_wstrb_o,
    output logic                      local0_axi_wvalid_o,
    input  logic                      local0_axi_wready_i,
    input  logic [1:0]                local0_axi_bresp_i,
    input  logic                      local0_axi_bvalid_i,
    output logic                      local0_axi_bready_o,
    output logic [ADDR_WIDTH-1:0]     local0_axi_araddr_o,
    output logic [2:0]                local0_axi_arprot_o,
    output logic                      local0_axi_arvalid_o,
    input  logic                      local0_axi_arready_i,
    input  logic [DATA_WIDTH-1:0]     local0_axi_rdata_i,
    input  logic [1:0]                local0_axi_rresp_i,
    input  logic                      local0_axi_rvalid_i,
    output logic                      local0_axi_rready_o,

    output logic [ADDR_WIDTH-1:0]     ext_axi_awaddr_o,
    output logic [2:0]                ext_axi_awprot_o,
    output logic                      ext_axi_awvalid_o,
    input  logic                      ext_axi_awready_i,
    output logic [DATA_WIDTH-1:0]     ext_axi_wdata_o,
    output logic [(DATA_WIDTH/8)-1:0] ext_axi_wstrb_o,
    output logic                      ext_axi_wvalid_o,
    input  logic                      ext_axi_wready_i,
    input  logic [1:0]                ext_axi_bresp_i,
    input  logic                      ext_axi_bvalid_i,
    output logic                      ext_axi_bready_o,
    output logic [ADDR_WIDTH-1:0]     ext_axi_araddr_o,
    output logic [2:0]                ext_axi_arprot_o,
    output logic                      ext_axi_arvalid_o,
    input  logic                      ext_axi_arready_i,
    input  logic [DATA_WIDTH-1:0]     ext_axi_rdata_i,
    input  logic [1:0]                ext_axi_rresp_i,
    input  logic                      ext_axi_rvalid_i,
    output logic                      ext_axi_rready_o
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_WRITE_REQ,
    ST_WRITE_RESP,
    ST_READ_REQ,
    ST_READ_RESP
  } state_t;

  state_t state_d, state_q;
  logic   wr_sel_d, wr_sel_q;
  logic   rd_sel_d, rd_sel_q;
  logic   aw_done_d, aw_done_q;
  logic   w_done_d, w_done_q;

  function automatic bit addr_hits_local0(input logic [ADDR_WIDTH-1:0] addr);
    logic [ADDR_WIDTH:0] end_addr;
    begin
      end_addr = {1'b0, LOCAL0_BASE_ADDR} + {1'b0, LOCAL0_SIZE_BYTES};
      return ({1'b0, addr} >= {1'b0, LOCAL0_BASE_ADDR}) &&
             ({1'b0, addr} < end_addr);
    end
  endfunction

  always_comb begin
    logic sel_wr_awready;
    logic sel_wr_wready;
    logic sel_wr_bvalid;
    logic [1:0] sel_wr_bresp;
    logic sel_rd_arready;
    logic sel_rd_rvalid;
    logic [1:0] sel_rd_rresp;
    logic [DATA_WIDTH-1:0] sel_rd_rdata;

    state_d   = state_q;
    wr_sel_d  = wr_sel_q;
    rd_sel_d  = rd_sel_q;
    aw_done_d = aw_done_q;
    w_done_d  = w_done_q;

    s_axi_awready_o = 1'b0;
    s_axi_wready_o  = 1'b0;
    s_axi_bresp_o   = 2'b00;
    s_axi_bvalid_o  = 1'b0;
    s_axi_arready_o = 1'b0;
    s_axi_rdata_o   = '0;
    s_axi_rresp_o   = 2'b00;
    s_axi_rvalid_o  = 1'b0;

    local0_axi_awaddr_o  = s_axi_awaddr_i;
    local0_axi_awprot_o  = s_axi_awprot_i;
    local0_axi_awvalid_o = 1'b0;
    local0_axi_wdata_o   = s_axi_wdata_i;
    local0_axi_wstrb_o   = s_axi_wstrb_i;
    local0_axi_wvalid_o  = 1'b0;
    local0_axi_bready_o  = 1'b0;
    local0_axi_araddr_o  = s_axi_araddr_i;
    local0_axi_arprot_o  = s_axi_arprot_i;
    local0_axi_arvalid_o = 1'b0;
    local0_axi_rready_o  = 1'b0;

    ext_axi_awaddr_o  = s_axi_awaddr_i;
    ext_axi_awprot_o  = s_axi_awprot_i;
    ext_axi_awvalid_o = 1'b0;
    ext_axi_wdata_o   = s_axi_wdata_i;
    ext_axi_wstrb_o   = s_axi_wstrb_i;
    ext_axi_wvalid_o  = 1'b0;
    ext_axi_bready_o  = 1'b0;
    ext_axi_araddr_o  = s_axi_araddr_i;
    ext_axi_arprot_o  = s_axi_arprot_i;
    ext_axi_arvalid_o = 1'b0;
    ext_axi_rready_o  = 1'b0;

    sel_wr_awready = wr_sel_q ? ext_axi_awready_i : local0_axi_awready_i;
    sel_wr_wready  = wr_sel_q ? ext_axi_wready_i  : local0_axi_wready_i;
    sel_wr_bvalid  = wr_sel_q ? ext_axi_bvalid_i  : local0_axi_bvalid_i;
    sel_wr_bresp   = wr_sel_q ? ext_axi_bresp_i   : local0_axi_bresp_i;

    sel_rd_arready = rd_sel_q ? ext_axi_arready_i : local0_axi_arready_i;
    sel_rd_rvalid  = rd_sel_q ? ext_axi_rvalid_i  : local0_axi_rvalid_i;
    sel_rd_rresp   = rd_sel_q ? ext_axi_rresp_i   : local0_axi_rresp_i;
    sel_rd_rdata   = rd_sel_q ? ext_axi_rdata_i   : local0_axi_rdata_i;

    unique case (state_q)
      ST_IDLE: begin
        aw_done_d = 1'b0;
        w_done_d  = 1'b0;

        if (s_axi_awvalid_i || s_axi_wvalid_i) begin
          wr_sel_d = addr_hits_local0(s_axi_awaddr_i) ? 1'b0 : 1'b1;
          state_d  = ST_WRITE_REQ;
        end else if (s_axi_arvalid_i) begin
          rd_sel_d = addr_hits_local0(s_axi_araddr_i) ? 1'b0 : 1'b1;
          state_d  = ST_READ_REQ;
        end
      end

      ST_WRITE_REQ: begin
        if (!wr_sel_q) begin
          local0_axi_awvalid_o = ~aw_done_q & s_axi_awvalid_i;
          local0_axi_wvalid_o  = ~w_done_q  & s_axi_wvalid_i;
        end else begin
          ext_axi_awvalid_o = ~aw_done_q & s_axi_awvalid_i;
          ext_axi_wvalid_o  = ~w_done_q  & s_axi_wvalid_i;
        end

        s_axi_awready_o = ~aw_done_q & sel_wr_awready;
        s_axi_wready_o  = ~w_done_q  & sel_wr_wready;

        if (!aw_done_q && s_axi_awvalid_i && sel_wr_awready) begin
          aw_done_d = 1'b1;
        end

        if (!w_done_q && s_axi_wvalid_i && sel_wr_wready) begin
          w_done_d = 1'b1;
        end

        if ((aw_done_q || (s_axi_awvalid_i && sel_wr_awready)) &&
            (w_done_q  || (s_axi_wvalid_i  && sel_wr_wready))) begin
          state_d = ST_WRITE_RESP;
        end
      end

      ST_WRITE_RESP: begin
        s_axi_bvalid_o = sel_wr_bvalid;
        s_axi_bresp_o  = sel_wr_bresp;

        if (!wr_sel_q) begin
          local0_axi_bready_o = s_axi_bready_i;
        end else begin
          ext_axi_bready_o = s_axi_bready_i;
        end

        if (sel_wr_bvalid && s_axi_bready_i) begin
          state_d = ST_IDLE;
        end
      end

      ST_READ_REQ: begin
        if (!rd_sel_q) begin
          local0_axi_arvalid_o = s_axi_arvalid_i;
        end else begin
          ext_axi_arvalid_o = s_axi_arvalid_i;
        end

        s_axi_arready_o = sel_rd_arready;

        if (s_axi_arvalid_i && sel_rd_arready) begin
          state_d = ST_READ_RESP;
        end
      end

      ST_READ_RESP: begin
        s_axi_rvalid_o = sel_rd_rvalid;
        s_axi_rresp_o  = sel_rd_rresp;
        s_axi_rdata_o  = sel_rd_rdata;

        if (!rd_sel_q) begin
          local0_axi_rready_o = s_axi_rready_i;
        end else begin
          ext_axi_rready_o = s_axi_rready_i;
        end

        if (sel_rd_rvalid && s_axi_rready_i) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= ST_IDLE;
      wr_sel_q  <= 1'b1;
      rd_sel_q  <= 1'b1;
      aw_done_q <= 1'b0;
      w_done_q  <= 1'b0;
    end else begin
      state_q   <= state_d;
      wr_sel_q  <= wr_sel_d;
      rd_sel_q  <= rd_sel_d;
      aw_done_q <= aw_done_d;
      w_done_q  <= w_done_d;
    end
  end

endmodule
