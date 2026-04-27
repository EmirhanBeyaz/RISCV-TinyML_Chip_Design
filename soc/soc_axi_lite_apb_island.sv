module soc_axi_lite_apb_island #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NO_APB_SLOTS = 16
) (
    input  logic                           clk_i,
    input  logic                           rst_ni,

    input  logic [ADDR_WIDTH-1:0]          s_axi_awaddr_i,
    input  logic [2:0]                     s_axi_awprot_i,
    input  logic                           s_axi_awvalid_i,
    output logic                           s_axi_awready_o,
    input  logic [DATA_WIDTH-1:0]          s_axi_wdata_i,
    input  logic [(DATA_WIDTH/8)-1:0]      s_axi_wstrb_i,
    input  logic                           s_axi_wvalid_i,
    output logic                           s_axi_wready_o,
    output logic [1:0]                     s_axi_bresp_o,
    output logic                           s_axi_bvalid_o,
    input  logic                           s_axi_bready_i,
    input  logic [ADDR_WIDTH-1:0]          s_axi_araddr_i,
    input  logic [2:0]                     s_axi_arprot_i,
    input  logic                           s_axi_arvalid_i,
    output logic                           s_axi_arready_o,
    output logic [DATA_WIDTH-1:0]          s_axi_rdata_o,
    output logic [1:0]                     s_axi_rresp_o,
    output logic                           s_axi_rvalid_o,
    input  logic                           s_axi_rready_i,

    output logic [ADDR_WIDTH-1:0]          paddr_o,
    output logic [2:0]                     pprot_o,
    output logic                           penable_o,
    output logic                           pwrite_o,
    output logic [DATA_WIDTH-1:0]          pwdata_o,
    output logic [NO_APB_SLOTS-1:0]        psel_o,
    input  logic [NO_APB_SLOTS-1:0][DATA_WIDTH-1:0] prdata_i,
    input  logic [NO_APB_SLOTS-1:0]        pready_i,
    input  logic [NO_APB_SLOTS-1:0]        pslverr_i
);

  import soc_map_pkg::*;

  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int SLOT_ADDR_LSB = $clog2(SOC_MMIO_SLOT_BYTES);
  localparam int SLOT_IDX_WIDTH = (NO_APB_SLOTS > 1) ? $clog2(NO_APB_SLOTS) : 1;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_WRITE_SETUP,
    ST_WRITE_ACCESS,
    ST_WRITE_RESP,
    ST_READ_SETUP,
    ST_READ_ACCESS,
    ST_READ_RESP
  } state_t;

  state_t                    state_q;
  logic                      aw_seen_q;
  logic                      w_seen_q;
  logic [ADDR_WIDTH-1:0]     aw_addr_q;
  logic [2:0]                aw_prot_q;
  logic [DATA_WIDTH-1:0]     wdata_q;
  logic [STRB_WIDTH-1:0]     wstrb_q;
  logic [ADDR_WIDTH-1:0]     req_addr_q;
  logic [2:0]                req_prot_q;
  logic [DATA_WIDTH-1:0]     req_wdata_q;
  logic [SLOT_IDX_WIDTH-1:0] req_slot_q;
  logic [DATA_WIDTH-1:0]     resp_rdata_q;
  logic [1:0]                resp_code_q;

  logic [SLOT_IDX_WIDTH-1:0] selected_slot;
  logic                      selected_ready;
  logic                      selected_slverr;
  logic [DATA_WIDTH-1:0]     selected_rdata;
  logic                      apb_active;

  function automatic bit addr_in_apb_window(input logic [ADDR_WIDTH-1:0] addr);
    logic [ADDR_WIDTH:0] mmio_end;
    begin
      mmio_end = {1'b0, SOC_MMIO_BASE_ADDR} +
                 (NO_APB_SLOTS * {1'b0, SOC_MMIO_SLOT_BYTES});
      return ({1'b0, addr} >= {1'b0, SOC_MMIO_BASE_ADDR}) &&
             ({1'b0, addr} < mmio_end);
    end
  endfunction

  function automatic logic [SLOT_IDX_WIDTH-1:0] addr_to_slot(input logic [ADDR_WIDTH-1:0] addr);
    logic [ADDR_WIDTH-1:0] offset;
    begin
      offset = addr - SOC_MMIO_BASE_ADDR;
      return offset[SLOT_ADDR_LSB +: SLOT_IDX_WIDTH];
    end
  endfunction

  always_comb begin
    selected_slot   = req_slot_q;
    selected_ready  = pready_i[req_slot_q];
    selected_slverr = pslverr_i[req_slot_q];
    selected_rdata  = prdata_i[req_slot_q];
  end

  always_comb begin
    s_axi_awready_o = (state_q == ST_IDLE) && !aw_seen_q;
    s_axi_wready_o  = (state_q == ST_IDLE) && !w_seen_q;
    s_axi_arready_o = (state_q == ST_IDLE) && !aw_seen_q && !w_seen_q;

    s_axi_bresp_o  = resp_code_q;
    s_axi_bvalid_o = (state_q == ST_WRITE_RESP);
    s_axi_rdata_o  = resp_rdata_q;
    s_axi_rresp_o  = resp_code_q;
    s_axi_rvalid_o = (state_q == ST_READ_RESP);

    paddr_o   = req_addr_q;
    pprot_o   = req_prot_q;
    pwrite_o  = (state_q == ST_WRITE_SETUP) || (state_q == ST_WRITE_ACCESS);
    pwdata_o  = req_wdata_q;
    penable_o = (state_q == ST_WRITE_ACCESS) || (state_q == ST_READ_ACCESS);
    psel_o    = '0;

    apb_active = (state_q == ST_WRITE_SETUP) || (state_q == ST_WRITE_ACCESS) ||
                 (state_q == ST_READ_SETUP) || (state_q == ST_READ_ACCESS);
    if (apb_active) begin
      psel_o[req_slot_q] = 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= ST_IDLE;
      aw_seen_q    <= 1'b0;
      w_seen_q     <= 1'b0;
      aw_addr_q    <= '0;
      aw_prot_q    <= '0;
      wdata_q      <= '0;
      wstrb_q      <= '0;
      req_addr_q   <= '0;
      req_prot_q   <= '0;
      req_wdata_q  <= '0;
      req_slot_q   <= '0;
      resp_rdata_q <= '0;
      resp_code_q  <= 2'b00;
    end else begin
      logic aw_fire;
      logic w_fire;
      logic ar_fire;
      logic aw_complete;
      logic w_complete;
      logic [ADDR_WIDTH-1:0] write_addr;
      logic [2:0]            write_prot;
      logic [DATA_WIDTH-1:0] write_data;
      logic [STRB_WIDTH-1:0] write_strb;
      logic [SLOT_IDX_WIDTH-1:0] next_slot;
      logic decode_ok;

      aw_fire = s_axi_awvalid_i && s_axi_awready_o;
      w_fire  = s_axi_wvalid_i && s_axi_wready_o;
      ar_fire = s_axi_arvalid_i && s_axi_arready_o;

      if (aw_fire) begin
        aw_seen_q <= 1'b1;
        aw_addr_q <= s_axi_awaddr_i;
        aw_prot_q <= s_axi_awprot_i;
      end

      if (w_fire) begin
        w_seen_q <= 1'b1;
        wdata_q  <= s_axi_wdata_i;
        wstrb_q  <= s_axi_wstrb_i;
      end

      unique case (state_q)
        ST_IDLE: begin
          aw_complete = aw_seen_q || aw_fire;
          w_complete  = w_seen_q || w_fire;
          write_addr  = aw_seen_q ? aw_addr_q : s_axi_awaddr_i;
          write_prot  = aw_seen_q ? aw_prot_q : s_axi_awprot_i;
          write_data  = w_seen_q ? wdata_q : s_axi_wdata_i;
          write_strb  = w_seen_q ? wstrb_q : s_axi_wstrb_i;

          if (aw_complete && w_complete) begin
            next_slot = addr_to_slot(write_addr);
            decode_ok = addr_in_apb_window(write_addr) && (next_slot < NO_APB_SLOTS);

            req_addr_q  <= write_addr;
            req_prot_q  <= write_prot;
            req_wdata_q <= write_data;
            req_slot_q  <= next_slot;
            aw_seen_q   <= 1'b0;
            w_seen_q    <= 1'b0;

            if (write_strb != {STRB_WIDTH{1'b1}}) begin
              resp_code_q <= 2'b10;
              state_q     <= ST_WRITE_RESP;
            end else if (decode_ok) begin
              resp_code_q <= 2'b00;
              state_q     <= ST_WRITE_SETUP;
            end else begin
              resp_code_q <= 2'b11;
              state_q     <= ST_WRITE_RESP;
            end
          end else if (ar_fire) begin
            next_slot = addr_to_slot(s_axi_araddr_i);
            decode_ok = addr_in_apb_window(s_axi_araddr_i) && (next_slot < NO_APB_SLOTS);

            req_addr_q <= s_axi_araddr_i;
            req_prot_q <= s_axi_arprot_i;
            req_slot_q <= next_slot;

            if (decode_ok) begin
              state_q <= ST_READ_SETUP;
            end else begin
              resp_rdata_q <= 32'hDEA1_10C8;
              resp_code_q  <= 2'b11;
              state_q      <= ST_READ_RESP;
            end
          end
        end

        ST_WRITE_SETUP: begin
          state_q <= ST_WRITE_ACCESS;
        end

        ST_WRITE_ACCESS: begin
          if (selected_ready) begin
            resp_code_q <= selected_slverr ? 2'b10 : 2'b00;
            state_q     <= ST_WRITE_RESP;
          end
        end

        ST_WRITE_RESP: begin
          if (s_axi_bready_i) begin
            state_q <= ST_IDLE;
          end
        end

        ST_READ_SETUP: begin
          state_q <= ST_READ_ACCESS;
        end

        ST_READ_ACCESS: begin
          if (selected_ready) begin
            resp_rdata_q <= selected_rdata;
            resp_code_q  <= selected_slverr ? 2'b10 : 2'b00;
            state_q      <= ST_READ_RESP;
          end
        end

        ST_READ_RESP: begin
          if (s_axi_rready_i) begin
            state_q <= ST_IDLE;
          end
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
