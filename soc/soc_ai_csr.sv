module soc_ai_csr #(
    parameter logic [31:0] AI_ID = 32'h4149_4331
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
    input  logic        s_axi_rready_i,

    output logic        accel_start_o,
    output logic        uart_start_o,
    output logic [31:0] input_base_o,
    output logic [31:0] input_len_o,
    output logic [31:0] output_base_o,
    output logic [15:0] uart_baud_div_o,

    input  logic        accel_busy_i,
    input  logic        accel_done_i,
    input  logic [ 1:0] accel_result_class_i,
    input  logic signed [31:0] accel_result0_i,
    input  logic signed [31:0] accel_result1_i,
    input  logic signed [31:0] accel_result2_i,
    input  logic signed [31:0] accel_result3_i,
    input  logic [31:0] accel_cycle_count_i,
    input  logic        uart_active_i,
    input  logic        uart_done_i,
    input  logic        uart_error_i,
    input  logic [31:0] uart_byte_count_i,
    output logic        irq_o
);

  import soc_map_pkg::*;

  localparam logic [5:0] REG_ID           = 6'h00;
  localparam logic [5:0] REG_CTRL         = 6'h04;
  localparam logic [5:0] REG_STATUS       = 6'h08;
  localparam logic [5:0] REG_INPUT_BASE   = 6'h0c;
  localparam logic [5:0] REG_INPUT_LEN    = 6'h10;
  localparam logic [5:0] REG_OUTPUT_BASE  = 6'h14;
  localparam logic [5:0] REG_RESULT_CLASS = 6'h18;
  localparam logic [5:0] REG_RESULT0      = 6'h1c;
  localparam logic [5:0] REG_RESULT1      = 6'h20;
  localparam logic [5:0] REG_RESULT2      = 6'h24;
  localparam logic [5:0] REG_RESULT3      = 6'h28;
  localparam logic [5:0] REG_CYCLE_COUNT  = 6'h2c;
  localparam logic [5:0] REG_IRQ_CLEAR    = 6'h30;
  localparam logic [5:0] REG_UART_BAUD    = 6'h34;
  localparam logic [5:0] REG_UART_COUNT   = 6'h38;

  logic        aw_seen_q;
  logic        w_seen_q;
  logic [31:0] aw_addr_q;
  logic [31:0] wdata_q;
  logic [ 3:0] wstrb_q;
  logic        bvalid_q;
  logic        rvalid_q;
  logic [31:0] rdata_q;
  logic [ 1:0] bresp_q;
  logic [ 1:0] rresp_q;
  logic        irq_enable_q;
  logic        done_q;
  logic        irq_q;
  logic [31:0] input_base_q;
  logic [31:0] input_len_q;
  logic [31:0] output_base_q;
  logic [15:0] uart_baud_div_q;
  logic        accel_start_q;
  logic        uart_start_q;

  integer      byte_idx;

  function automatic logic [31:0] apply_wstrb(
      input logic [31:0] old_value,
      input logic [31:0] new_value,
      input logic [ 3:0] strb
  );
    logic [31:0] merged;
    integer idx;
    begin
      merged = old_value;
      for (idx = 0; idx < 4; idx = idx + 1) begin
        if (strb[idx]) begin
          merged[8*idx +: 8] = new_value[8*idx +: 8];
        end
      end
      return merged;
    end
  endfunction

  assign s_axi_awready_o = ~aw_seen_q & ~bvalid_q;
  assign s_axi_wready_o  = ~w_seen_q & ~bvalid_q;
  assign s_axi_bresp_o   = bresp_q;
  assign s_axi_bvalid_o  = bvalid_q;
  assign s_axi_arready_o = ~rvalid_q & ~bvalid_q & ~aw_seen_q & ~w_seen_q;
  assign s_axi_rdata_o   = rdata_q;
  assign s_axi_rresp_o   = rresp_q;
  assign s_axi_rvalid_o  = rvalid_q;

  assign accel_start_o    = accel_start_q;
  assign uart_start_o     = uart_start_q;
  assign input_base_o     = input_base_q;
  assign input_len_o      = input_len_q;
  assign output_base_o    = output_base_q;
  assign uart_baud_div_o  = uart_baud_div_q;
  assign irq_o            = irq_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_seen_q       <= 1'b0;
      w_seen_q        <= 1'b0;
      aw_addr_q       <= '0;
      wdata_q         <= '0;
      wstrb_q         <= '0;
      bvalid_q        <= 1'b0;
      rvalid_q        <= 1'b0;
      rdata_q         <= '0;
      bresp_q         <= 2'b00;
      rresp_q         <= 2'b00;
      irq_enable_q    <= 1'b0;
      done_q          <= 1'b0;
      irq_q           <= 1'b0;
      input_base_q    <= SOC_AI_MEM_BASE_ADDR;
      input_len_q     <= 32'd1960;
      output_base_q   <= SOC_AI_MEM_BASE_ADDR + 32'h0000_7000;
      uart_baud_div_q <= 16'h0000;
      accel_start_q   <= 1'b0;
      uart_start_q    <= 1'b0;
    end else begin
      logic aw_fire;
      logic w_fire;
      logic ar_fire;
      logic aw_complete;
      logic w_complete;
      logic [31:0] write_addr_now;
      logic [31:0] write_data_now;
      logic [ 3:0] write_strb_now;
      logic [5:0]  reg_offset;
      logic [31:0] status_word;
      logic [31:0] merged_word;

      accel_start_q <= 1'b0;
      uart_start_q  <= 1'b0;

      aw_fire = s_axi_awvalid_i && s_axi_awready_o;
      w_fire  = s_axi_wvalid_i && s_axi_wready_o;
      ar_fire = s_axi_arvalid_i && s_axi_arready_o;

      if (accel_done_i) begin
        done_q <= 1'b1;
        if (irq_enable_q) begin
          irq_q <= 1'b1;
        end
      end

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
        reg_offset = write_addr_now[5:0];
        bresp_q    <= 2'b00;

        unique case (reg_offset)
          REG_CTRL: begin
            if (write_strb_now[0]) begin
              accel_start_q <= write_data_now[0];
              irq_enable_q  <= write_data_now[1];
              uart_start_q  <= write_data_now[2];
              if (write_data_now[3]) begin
                done_q <= 1'b0;
                irq_q  <= 1'b0;
              end
            end
          end

          REG_INPUT_BASE: begin
            input_base_q <= apply_wstrb(input_base_q, write_data_now, write_strb_now);
          end

          REG_INPUT_LEN: begin
            input_len_q <= apply_wstrb(input_len_q, write_data_now, write_strb_now);
          end

          REG_OUTPUT_BASE: begin
            output_base_q <= apply_wstrb(output_base_q, write_data_now, write_strb_now);
          end

          REG_IRQ_CLEAR: begin
            if (write_strb_now[0] && write_data_now[0]) begin
              done_q <= 1'b0;
              irq_q  <= 1'b0;
            end
          end

          REG_UART_BAUD: begin
            merged_word = apply_wstrb({16'h0, uart_baud_div_q},
                                      write_data_now,
                                      write_strb_now);
            uart_baud_div_q <= merged_word[15:0];
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
        status_word = 32'h0;
        status_word[0] = accel_busy_i;
        status_word[1] = done_q;
        status_word[2] = irq_q;
        status_word[3] = uart_active_i;
        status_word[4] = uart_done_i;
        status_word[5] = uart_error_i;
        status_word[8] = 1'b1;  // Accelerator weights/model path is present.
        status_word[9] = 1'b1;  // AI_MEM is integrated.

        rresp_q <= 2'b00;
        unique case (s_axi_araddr_i[5:0])
          REG_ID:           rdata_q <= AI_ID;
          REG_CTRL:         rdata_q <= {30'h0, irq_enable_q, 1'b0};
          REG_STATUS:       rdata_q <= status_word;
          REG_INPUT_BASE:   rdata_q <= input_base_q;
          REG_INPUT_LEN:    rdata_q <= input_len_q;
          REG_OUTPUT_BASE:  rdata_q <= output_base_q;
          REG_RESULT_CLASS: rdata_q <= {30'h0, accel_result_class_i};
          REG_RESULT0:      rdata_q <= accel_result0_i;
          REG_RESULT1:      rdata_q <= accel_result1_i;
          REG_RESULT2:      rdata_q <= accel_result2_i;
          REG_RESULT3:      rdata_q <= accel_result3_i;
          REG_CYCLE_COUNT:  rdata_q <= accel_cycle_count_i;
          REG_IRQ_CLEAR:    rdata_q <= 32'h0;
          REG_UART_BAUD:    rdata_q <= {16'h0, uart_baud_div_q};
          REG_UART_COUNT:   rdata_q <= uart_byte_count_i;
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
