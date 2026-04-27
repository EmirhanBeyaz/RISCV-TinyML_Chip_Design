module soc_axi_lite_uart #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
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
    input  logic                      uart_rx_i,
    output logic                      uart_tx_o
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  localparam logic [3:0] REG_CTRL   = 4'h0;
  localparam logic [3:0] REG_STATUS = 4'h4;
  localparam logic [3:0] REG_RXDATA = 4'h8;
  localparam logic [3:0] REG_TXDATA = 4'hc;

  logic                     aw_seen_q;
  logic                     w_seen_q;
  logic [ADDR_WIDTH-1:0]    aw_addr_q;
  logic [DATA_WIDTH-1:0]    wdata_q;
  logic [STRB_WIDTH-1:0]    wstrb_q;
  logic                     bvalid_q;
  logic                     rvalid_q;
  logic [DATA_WIDTH-1:0]    rdata_q;
  logic [1:0]               bresp_q;
  logic [1:0]               rresp_q;

  logic [15:0]              baud_div_q;
  logic                     tx_enable_q;
  logic                     rx_enable_q;
  logic                     tx_we_q;
  logic                     rx_re_q;
  logic [7:0]               tx_data_q;

  logic                     tx_full;
  logic                     tx_empty;
  logic                     rx_full;
  logic                     rx_empty;
  logic [7:0]               rx_data;

  integer byte_idx;

  uart_tx uart_tx_i (
      .clk_i    (clk_i),
      .rst_i    (~rst_ni),
      .baud_div_i(baud_div_q),
      .we_i     (tx_we_q),
      .stall_i  (~tx_enable_q),
      .data_i   (tx_data_q),
      .full_o   (tx_full),
      .empty_o  (tx_empty),
      .tx_o     (uart_tx_o)
  );

  uart_rx uart_rx_i_dut (
      .clk_i    (clk_i),
      .rst_i    (~rst_ni),
      .baud_div_i(baud_div_q),
      .re_i     (rx_re_q),
      .stall_i  (~rx_enable_q),
      .data_o   (rx_data),
      .full_o   (rx_full),
      .empty_o  (rx_empty),
      .rx_i     (uart_rx_i)
  );

  assign s_axi_awready_o = ~aw_seen_q & ~bvalid_q;
  assign s_axi_wready_o  = ~w_seen_q & ~bvalid_q;
  assign s_axi_bresp_o   = bresp_q;
  assign s_axi_bvalid_o  = bvalid_q;

  assign s_axi_arready_o = ~rvalid_q & ~bvalid_q & ~aw_seen_q & ~w_seen_q;
  assign s_axi_rdata_o   = rdata_q;
  assign s_axi_rresp_o   = rresp_q;
  assign s_axi_rvalid_o  = rvalid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_seen_q   <= 1'b0;
      w_seen_q    <= 1'b0;
      aw_addr_q   <= '0;
      wdata_q     <= '0;
      wstrb_q     <= '0;
      bvalid_q    <= 1'b0;
      rvalid_q    <= 1'b0;
      rdata_q     <= '0;
      bresp_q     <= 2'b00;
      rresp_q     <= 2'b00;
      baud_div_q  <= '0;
      tx_enable_q <= 1'b0;
      rx_enable_q <= 1'b0;
      tx_we_q     <= 1'b0;
      rx_re_q     <= 1'b0;
      tx_data_q   <= '0;
    end else begin
      logic aw_fire;
      logic w_fire;
      logic ar_fire;
      logic aw_complete;
      logic w_complete;
      logic [ADDR_WIDTH-1:0] write_addr_now;
      logic [DATA_WIDTH-1:0] write_data_now;
      logic [STRB_WIDTH-1:0] write_strb_now;
      logic [3:0]            reg_offset;
      logic [31:0]           next_ctrl;

      tx_we_q <= 1'b0;
      rx_re_q <= 1'b0;

      aw_fire = s_axi_awvalid_i && s_axi_awready_o;
      w_fire  = s_axi_wvalid_i && s_axi_wready_o;
      ar_fire = s_axi_arvalid_i && s_axi_arready_o;

      if (aw_fire) begin
        aw_seen_q <= 1'b1;
        aw_addr_q <= s_axi_awaddr_i;
      end

      if (w_fire) begin
        w_seen_q <= 1'b1;
        wdata_q  <= s_axi_wdata_i;
        wstrb_q  <= s_axi_wstrb_i;
      end

      aw_complete    = aw_seen_q | aw_fire;
      w_complete     = w_seen_q | w_fire;
      write_addr_now = aw_seen_q ? aw_addr_q : s_axi_awaddr_i;
      write_data_now = w_seen_q ? wdata_q : s_axi_wdata_i;
      write_strb_now = w_seen_q ? wstrb_q : s_axi_wstrb_i;

      if (!bvalid_q && aw_complete && w_complete) begin
        reg_offset = write_addr_now[3:0];
        bresp_q    <= 2'b00;

        unique case (reg_offset)
          REG_CTRL: begin
            next_ctrl = {baud_div_q, 14'b0, rx_enable_q, tx_enable_q};
            for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
              if (write_strb_now[byte_idx]) begin
                next_ctrl[8*byte_idx +: 8] = write_data_now[8*byte_idx +: 8];
              end
            end
            tx_enable_q <= next_ctrl[0];
            rx_enable_q <= next_ctrl[1];
            baud_div_q  <= next_ctrl[31:16];
          end

          REG_TXDATA: begin
            if (write_strb_now[0] && !tx_full) begin
              tx_data_q <= write_data_now[7:0];
              tx_we_q <= 1'b1;
            end else begin
              bresp_q <= 2'b10;
            end
          end

          default: begin
            bresp_q <= 2'b10;
          end
        endcase

        aw_seen_q <= 1'b0;
        w_seen_q  <= 1'b0;
        bvalid_q  <= 1'b1;
      end

      if (bvalid_q && s_axi_bready_i) begin
        bvalid_q <= 1'b0;
      end

      if (ar_fire) begin
        rresp_q <= 2'b00;

        unique case (s_axi_araddr_i[3:0])
          REG_CTRL: begin
            rdata_q <= {baud_div_q, 14'b0, rx_enable_q, tx_enable_q};
          end

          REG_STATUS: begin
            rdata_q <= {28'b0, rx_empty, rx_full, tx_empty, tx_full};
          end

          REG_RXDATA: begin
            rdata_q <= {24'b0, rx_data};
            if (!rx_empty) begin
              rx_re_q <= 1'b1;
            end
          end

          REG_TXDATA: begin
            rdata_q <= 32'h0;
          end

          default: begin
            rdata_q <= 32'h0;
            rresp_q <= 2'b10;
          end
        endcase

        rvalid_q <= 1'b1;
      end else if (rvalid_q && s_axi_rready_i) begin
        rvalid_q <= 1'b0;
      end
    end
  end

endmodule
