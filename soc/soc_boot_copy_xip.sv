module soc_boot_copy_xip #(
    parameter bit BOOT_ENABLE = 1'b0,
    parameter logic [31:0] XIP_BASE_ADDR = 32'h3000_0000,
    parameter logic [31:0] IMEM_BASE_ADDR = 32'h0001_0000,
    parameter int COPY_WORDS = 2048
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        start_i,
    output logic        boot_active_o,
    output logic        boot_done_o,
    output logic [31:0] m_axi_awaddr_o,
    output logic [ 2:0] m_axi_awprot_o,
    output logic        m_axi_awvalid_o,
    input  logic        m_axi_awready_i,
    output logic [31:0] m_axi_wdata_o,
    output logic [ 3:0] m_axi_wstrb_o,
    output logic        m_axi_wvalid_o,
    input  logic        m_axi_wready_i,
    input  logic [ 1:0] m_axi_bresp_i,
    input  logic        m_axi_bvalid_i,
    output logic        m_axi_bready_o,
    output logic [31:0] m_axi_araddr_o,
    output logic [ 2:0] m_axi_arprot_o,
    output logic        m_axi_arvalid_o,
    input  logic        m_axi_arready_i,
    input  logic [31:0] m_axi_rdata_i,
    input  logic [ 1:0] m_axi_rresp_i,
    input  logic        m_axi_rvalid_i,
    output logic        m_axi_rready_o,
    output logic        imem_req_o,
    output logic        imem_we_o,
    output logic [ 3:0] imem_be_o,
    output logic [31:0] imem_addr_o,
    output logic [31:0] imem_wdata_o,
    input  logic        imem_gnt_i
);

  localparam int COPY_WORDS_SAFE = (COPY_WORDS > 0) ? COPY_WORDS : 1;

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_READ_ADDR,
    ST_READ_DATA,
    ST_WRITE_IMEM
  } boot_state_e;

  boot_state_e state_q;
  logic [31:0] word_idx_q;
  logic [31:0] read_data_q;

  assign boot_active_o = BOOT_ENABLE && start_i && !boot_done_o;

  assign m_axi_awaddr_o  = 32'h0;
  assign m_axi_awprot_o  = 3'b000;
  assign m_axi_awvalid_o = 1'b0;
  assign m_axi_wdata_o   = 32'h0;
  assign m_axi_wstrb_o   = 4'h0;
  assign m_axi_wvalid_o  = 1'b0;
  assign m_axi_bready_o  = 1'b1;

  assign m_axi_araddr_o  = XIP_BASE_ADDR + (word_idx_q << 2);
  assign m_axi_arprot_o  = 3'b000;
  assign m_axi_arvalid_o = (state_q == ST_READ_ADDR) && boot_active_o;
  assign m_axi_rready_o  = (state_q == ST_READ_DATA) && boot_active_o;

  assign imem_req_o   = (state_q == ST_WRITE_IMEM) && boot_active_o;
  assign imem_we_o    = imem_req_o;
  assign imem_be_o    = 4'hF;
  assign imem_addr_o  = IMEM_BASE_ADDR + (word_idx_q << 2);
  assign imem_wdata_o = read_data_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q     <= ST_IDLE;
      word_idx_q  <= 32'h0;
      read_data_q <= 32'h0;
      boot_done_o <= !BOOT_ENABLE || (COPY_WORDS == 0);
    end else if (!BOOT_ENABLE || (COPY_WORDS == 0)) begin
      state_q     <= ST_IDLE;
      word_idx_q  <= 32'h0;
      read_data_q <= 32'h0;
      boot_done_o <= 1'b1;
    end else if (!start_i) begin
      state_q     <= ST_IDLE;
      word_idx_q  <= 32'h0;
      read_data_q <= 32'h0;
      boot_done_o <= 1'b0;
    end else begin
      unique case (state_q)
        ST_IDLE: begin
          state_q <= ST_READ_ADDR;
        end

        ST_READ_ADDR: begin
          if (m_axi_arready_i) begin
            state_q <= ST_READ_DATA;
          end
        end

        ST_READ_DATA: begin
          if (m_axi_rvalid_i) begin
`ifndef SYNTHESIS
            if (m_axi_rresp_i != 2'b00) begin
              $error("soc_boot_copy_xip: AXI read error %b at %h", m_axi_rresp_i, m_axi_araddr_o);
              $fatal(1);
            end
`endif
            read_data_q <= m_axi_rdata_i;
            state_q     <= ST_WRITE_IMEM;
          end
        end

        ST_WRITE_IMEM: begin
          if (imem_gnt_i) begin
            if (word_idx_q == (COPY_WORDS_SAFE - 1)) begin
              state_q     <= ST_IDLE;
              boot_done_o <= 1'b1;
            end else begin
              word_idx_q <= word_idx_q + 32'd1;
              state_q    <= ST_READ_ADDR;
            end
          end
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
