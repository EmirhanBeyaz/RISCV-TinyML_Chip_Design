module cv32e40p_obi_to_axi_lite #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,

    input  logic                  obi_req_i,
    input  logic                  obi_we_i,
    input  logic [(DATA_WIDTH/8)-1:0] obi_be_i,
    input  logic [ADDR_WIDTH-1:0] obi_addr_i,
    input  logic [DATA_WIDTH-1:0] obi_wdata_i,
    output logic                  obi_gnt_o,
    output logic                  obi_rvalid_o,
    output logic [DATA_WIDTH-1:0] obi_rdata_o,

    output logic [ADDR_WIDTH-1:0] m_axi_awaddr_o,
    output logic [          2:0]  m_axi_awprot_o,
    output logic                  m_axi_awvalid_o,
    input  logic                  m_axi_awready_i,
    output logic [DATA_WIDTH-1:0] m_axi_wdata_o,
    output logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb_o,
    output logic                      m_axi_wvalid_o,
    input  logic                      m_axi_wready_i,
    input  logic [               1:0] m_axi_bresp_i,
    input  logic                      m_axi_bvalid_i,
    output logic                      m_axi_bready_o,
    output logic [ADDR_WIDTH-1:0]     m_axi_araddr_o,
    output logic [               2:0] m_axi_arprot_o,
    output logic                      m_axi_arvalid_o,
    input  logic                      m_axi_arready_i,
    input  logic [DATA_WIDTH-1:0]     m_axi_rdata_i,
    input  logic [               1:0] m_axi_rresp_i,
    input  logic                      m_axi_rvalid_i,
    output logic                      m_axi_rready_o
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_WRITE_REQ,
    ST_WRITE_RESP,
    ST_READ_REQ,
    ST_READ_RESP
  } state_t;

  state_t                state_d, state_q;
  logic [ADDR_WIDTH-1:0] req_addr_d, req_addr_q;
  logic [DATA_WIDTH-1:0] req_wdata_d, req_wdata_q;
  logic [ STRB_WIDTH-1:0] req_strb_d, req_strb_q;
  logic                  aw_done_d, aw_done_q;
  logic                  w_done_d, w_done_q;

  always_comb begin
    state_d    = state_q;
    req_addr_d = req_addr_q;
    req_wdata_d = req_wdata_q;
    req_strb_d = req_strb_q;
    aw_done_d  = aw_done_q;
    w_done_d   = w_done_q;

    obi_gnt_o    = 1'b0;
    obi_rvalid_o = 1'b0;
    obi_rdata_o  = '0;

    m_axi_awaddr_o  = '0;
    m_axi_awprot_o  = 3'b000;
    m_axi_awvalid_o = 1'b0;
    m_axi_wdata_o   = '0;
    m_axi_wstrb_o   = '0;
    m_axi_wvalid_o  = 1'b0;
    m_axi_bready_o  = 1'b0;
    m_axi_araddr_o  = '0;
    m_axi_arprot_o  = 3'b000;
    m_axi_arvalid_o = 1'b0;
    m_axi_rready_o  = 1'b0;

    unique case (state_q)
      ST_IDLE: begin
        aw_done_d = 1'b0;
        w_done_d  = 1'b0;

        if (obi_req_i) begin
          if (obi_we_i) begin
            m_axi_awaddr_o  = obi_addr_i;
            m_axi_awvalid_o = 1'b1;
            m_axi_wdata_o   = obi_wdata_i;
            m_axi_wstrb_o   = obi_be_i;
            m_axi_wvalid_o  = 1'b1;

            if (m_axi_awready_i && m_axi_wready_i) begin
              obi_gnt_o = 1'b1;
              state_d   = ST_WRITE_RESP;
            end else begin
              req_addr_d  = obi_addr_i;
              req_wdata_d = obi_wdata_i;
              req_strb_d  = obi_be_i;
              aw_done_d   = m_axi_awready_i;
              w_done_d    = m_axi_wready_i;
              state_d     = ST_WRITE_REQ;
            end
          end else begin
            m_axi_araddr_o  = obi_addr_i;
            m_axi_arvalid_o = 1'b1;

            if (m_axi_arready_i) begin
              obi_gnt_o = 1'b1;
              state_d   = ST_READ_RESP;
            end else begin
              req_addr_d = obi_addr_i;
              state_d    = ST_READ_REQ;
            end
          end
        end
      end

      ST_WRITE_REQ: begin
        m_axi_awaddr_o  = req_addr_q;
        m_axi_awvalid_o = ~aw_done_q;
        m_axi_wdata_o   = req_wdata_q;
        m_axi_wstrb_o   = req_strb_q;
        m_axi_wvalid_o  = ~w_done_q;

        if (!aw_done_q && m_axi_awready_i) begin
          aw_done_d = 1'b1;
        end

        if (!w_done_q && m_axi_wready_i) begin
          w_done_d = 1'b1;
        end

        if ((aw_done_q || m_axi_awready_i) && (w_done_q || m_axi_wready_i)) begin
          obi_gnt_o = 1'b1;
          aw_done_d = 1'b0;
          w_done_d  = 1'b0;
          state_d   = ST_WRITE_RESP;
        end
      end

      ST_WRITE_RESP: begin
        m_axi_bready_o = 1'b1;
        if (m_axi_bvalid_i) begin
          // CV32E40P top-level interface has no bus error signal, so BRESP is ignored for now.
          obi_rvalid_o = 1'b1;
          state_d      = ST_IDLE;
        end
      end

      ST_READ_REQ: begin
        m_axi_araddr_o  = req_addr_q;
        m_axi_arvalid_o = 1'b1;

        if (m_axi_arready_i) begin
          obi_gnt_o = 1'b1;
          state_d   = ST_READ_RESP;
        end
      end

      ST_READ_RESP: begin
        m_axi_rready_o = 1'b1;
        if (m_axi_rvalid_i) begin
          // CV32E40P top-level interface has no bus error signal, so RRESP is ignored for now.
          obi_rvalid_o = 1'b1;
          obi_rdata_o  = m_axi_rdata_i;
          state_d      = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q     <= ST_IDLE;
      req_addr_q  <= '0;
      req_wdata_q <= '0;
      req_strb_q  <= '0;
      aw_done_q   <= 1'b0;
      w_done_q    <= 1'b0;
    end else begin
      state_q     <= state_d;
      req_addr_q  <= req_addr_d;
      req_wdata_q <= req_wdata_d;
      req_strb_q  <= req_strb_d;
      aw_done_q   <= aw_done_d;
      w_done_q    <= w_done_d;
    end
  end

endmodule
