module soc_ai_tinyconv_accel #(
    parameter int INPUT_H = 49,
    parameter int INPUT_W = 40,
    parameter int OUT_H = 25,
    parameter int OUT_W = 20,
    parameter int CHANNELS = 8,
    parameter int K_H = 10,
    parameter int K_W = 8,
    parameter int PAD_H = 4,
    parameter int PAD_W = 3
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        start_i,
    input  logic [31:0] input_base_i,
    input  logic [31:0] input_len_i,
    input  logic [31:0] output_base_i,

    output logic        busy_o,
    output logic        done_o,
    output logic [ 1:0] result_class_o,
    output logic signed [31:0] result0_o,
    output logic signed [31:0] result1_o,
    output logic signed [31:0] result2_o,
    output logic signed [31:0] result3_o,
    output logic [31:0] cycle_count_o,

    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [ 3:0] mem_be_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] mem_wdata_o,
    input  logic        mem_gnt_i,
    input  logic        mem_rvalid_i,
    input  logic [31:0] mem_rdata_i
);

`ifdef SOC_AI_USE_MODEL_PKG
  import soc_ai_model_pkg::*;
`endif

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_KERNEL_REQ,
    ST_KERNEL_WAIT,
    ST_FEATURE_DONE,
    ST_FC_REQUANT,
    ST_ARGMAX,
    ST_WRITE_CLASS,
    ST_WRITE_SCORE0,
    ST_WRITE_SCORE1,
    ST_WRITE_SCORE2,
    ST_WRITE_SCORE3,
    ST_DONE
  } state_t;

  state_t state_q;

  int oh_q;
  int ow_q;
  int ch_q;
  int kh_q;
  int kw_q;
  logic signed [31:0] in_y_now;
  logic signed [31:0] in_x_now;
  logic signed [31:0] input_offset_now;
  logic [1:0] sample_lane_now;
  logic       sample_valid_now;
  logic [1:0] sample_lane_q;
  logic signed [31:0] conv_acc_q;
  logic signed [31:0] score0_q;
  logic signed [31:0] score1_q;
  logic signed [31:0] score2_q;
  logic signed [31:0] score3_q;
  logic [31:0] cycle_count_q;
  logic [1:0] result_class_q;
  logic done_q;
  logic busy_q;

  function automatic int depthwise_weight_index(
      input int ch,
      input int kh,
      input int kw
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return ((kh * soc_ai_model_pkg::AI_K_W) + kw) * soc_ai_model_pkg::AI_CHANNELS + ch;
`else
      return ((kh * K_W) + kw) * CHANNELS + ch;
`endif
    end
  endfunction

  function automatic int feature_index(
      input int oh,
      input int ow,
      input int ch
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return ((oh * soc_ai_model_pkg::AI_OUT_W) + ow) * soc_ai_model_pkg::AI_CHANNELS + ch;
`else
      return ((oh * OUT_W) + ow) * CHANNELS + ch;
`endif
    end
  endfunction

  function automatic int fc_weight_index(
      input int cls,
      input int oh,
      input int ow,
      input int ch
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return (cls * soc_ai_model_pkg::AI_OUT_H * soc_ai_model_pkg::AI_OUT_W *
              soc_ai_model_pkg::AI_CHANNELS) + feature_index(oh, ow, ch);
`else
      return (cls * OUT_H * OUT_W * CHANNELS) + feature_index(oh, ow, ch);
`endif
    end
  endfunction

  function automatic signed [31:0] input_zero_point();
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::AI_INPUT_ZERO_POINT;
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic signed [31:0] depthwise_output_zero_point();
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::AI_DW_OUTPUT_ZERO_POINT;
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic signed [31:0] output_zero_point();
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::AI_OUTPUT_ZERO_POINT;
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic int requant_shift();
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::AI_REQUANT_SHIFT;
`else
      return 0;
`endif
    end
  endfunction

  function automatic signed [31:0] depthwise_bias(
      input int ch
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_dw_bias(ch);
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic signed [7:0] depthwise_weight(
      input int ch,
      input int kh,
      input int kw
  );
    int v;
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_dw_weight(depthwise_weight_index(ch, kh, kw));
`else
      v = (ch * 3 + kh * 5 + kw * 7) % 5;
      return v - 2;
`endif
    end
  endfunction

  function automatic signed [31:0] depthwise_weight_zero_point(
      input int ch
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_dw_weight_zero_point(ch);
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic signed [31:0] depthwise_requant_multiplier(
      input int ch
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_dw_requant_multiplier(ch);
`else
      return 32'sd1;
`endif
    end
  endfunction

  function automatic signed [31:0] fc_bias(
      input int cls
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_fc_bias(cls);
`else
      unique case (cls)
        0: fc_bias = 32'sd13;
        1: fc_bias = -32'sd7;
        2: fc_bias = 32'sd3;
        default: fc_bias = -32'sd11;
      endcase
`endif
    end
  endfunction

  function automatic signed [7:0] fc_weight(
      input int cls,
      input int oh,
      input int ow,
      input int ch
  );
    int v;
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_fc_weight(fc_weight_index(cls, oh, ow, ch));
`else
      v = (cls * 11 + oh * 3 + ow * 5 + ch * 7) % 7;
      return v - 3;
`endif
    end
  endfunction

  function automatic signed [31:0] fc_weight_zero_point(
      input int cls
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_fc_weight_zero_point(cls);
`else
      return 32'sd0;
`endif
    end
  endfunction

  function automatic signed [31:0] fc_requant_multiplier(
      input int cls
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return soc_ai_model_pkg::ai_fc_requant_multiplier(cls);
`else
      return 32'sd1;
`endif
    end
  endfunction

  function automatic signed [31:0] rounded_shift(
      input signed [63:0] value,
      input int shift
  );
    logic signed [63:0] magnitude;
    logic signed [63:0] rounded;
    begin
      if (shift == 0) begin
        return value[31:0];
      end

      if (value >= 0) begin
        rounded = (value + (64'sd1 <<< (shift - 1))) >>> shift;
        return rounded[31:0];
      end

      magnitude = -value;
      rounded = (magnitude + (64'sd1 <<< (shift - 1))) >>> shift;
      return -rounded[31:0];
    end
  endfunction

  function automatic signed [31:0] requantize_fixed(
      input signed [31:0] value,
      input signed [31:0] multiplier,
      input int shift,
      input signed [31:0] zero_point
  );
    logic signed [63:0] product;
    begin
      product = value * multiplier;
      return rounded_shift(product, shift) + zero_point;
    end
  endfunction

  function automatic signed [31:0] clamp_int8(input signed [31:0] value);
    begin
      if (value > 32'sd127) begin
        return 32'sd127;
      end
      if (value < -32'sd128) begin
        return -32'sd128;
      end
      return value;
    end
  endfunction

  function automatic signed [31:0] depthwise_activation(input signed [31:0] value, input int ch);
    logic signed [31:0] quantized;
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      quantized = requantize_fixed(value,
                                   depthwise_requant_multiplier(ch),
                                   requant_shift(),
                                   depthwise_output_zero_point());
      if (quantized < depthwise_output_zero_point()) begin
        quantized = depthwise_output_zero_point();
      end
      return clamp_int8(quantized);
`else
      return relu_shift(value);
`endif
    end
  endfunction

  function automatic signed [31:0] fc_output_score(
      input int cls,
      input signed [31:0] value
  );
    begin
`ifdef SOC_AI_USE_MODEL_PKG
      return clamp_int8(requantize_fixed(value,
                                         fc_requant_multiplier(cls),
                                         requant_shift(),
                                         output_zero_point()));
`else
      return value;
`endif
    end
  endfunction

  function automatic signed [31:0] byte_to_sample(input logic [7:0] value);
    begin
      return {{24{value[7]}}, value};
    end
  endfunction

  function automatic logic [7:0] pick_byte(
      input logic [31:0] word,
      input logic [1:0] lane
  );
    begin
      unique case (lane)
        2'd0: pick_byte = word[7:0];
        2'd1: pick_byte = word[15:8];
        2'd2: pick_byte = word[23:16];
        default: pick_byte = word[31:24];
      endcase
    end
  endfunction

  function automatic signed [31:0] relu_shift(input signed [31:0] value);
    begin
      if (value <= 0) begin
        return 32'sd0;
      end
      return value >>> 5;
    end
  endfunction

  assign busy_o        = busy_q;
  assign done_o        = done_q;
  assign result_class_o = result_class_q;
  assign result0_o     = score0_q;
  assign result1_o     = score1_q;
  assign result2_o     = score2_q;
  assign result3_o     = score3_q;
  assign cycle_count_o = cycle_count_q;

  assign in_y_now = (oh_q * 2) + kh_q - PAD_H;
  assign in_x_now = (ow_q * 2) + kw_q - PAD_W;
  assign input_offset_now = (in_y_now * INPUT_W) + in_x_now;
  assign sample_lane_now = input_offset_now[1:0];
  assign sample_valid_now = (in_y_now >= 0) && (in_y_now < INPUT_H) &&
                            (in_x_now >= 0) && (in_x_now < INPUT_W) &&
                            ({1'b0, input_offset_now} < {1'b0, input_len_i});

  assign mem_req_o = (state_q == ST_KERNEL_REQ) && sample_valid_now ||
                     (state_q == ST_WRITE_CLASS) ||
                     (state_q == ST_WRITE_SCORE0) ||
                     (state_q == ST_WRITE_SCORE1) ||
                     (state_q == ST_WRITE_SCORE2) ||
                     (state_q == ST_WRITE_SCORE3);
  assign mem_we_o = (state_q == ST_WRITE_CLASS) || (state_q == ST_WRITE_SCORE0) ||
                    (state_q == ST_WRITE_SCORE1) || (state_q == ST_WRITE_SCORE2) ||
                    (state_q == ST_WRITE_SCORE3);
  assign mem_be_o = mem_we_o ? 4'hf : 4'h0;
  assign mem_addr_o = (state_q == ST_KERNEL_REQ) ? (input_base_i + input_offset_now[31:0]) :
                      (state_q == ST_WRITE_CLASS) ? output_base_i :
                      (state_q == ST_WRITE_SCORE0) ? (output_base_i + 32'd4) :
                      (state_q == ST_WRITE_SCORE1) ? (output_base_i + 32'd8) :
                      (state_q == ST_WRITE_SCORE2) ? (output_base_i + 32'd12) :
                                                    (output_base_i + 32'd16);
  assign mem_wdata_o = (state_q == ST_WRITE_CLASS) ? {30'h0, result_class_q} :
                       (state_q == ST_WRITE_SCORE0) ? score0_q :
                       (state_q == ST_WRITE_SCORE1) ? score1_q :
                       (state_q == ST_WRITE_SCORE2) ? score2_q :
                                                     score3_q;

  task automatic advance_kernel;
    begin
      if (kw_q == K_W - 1) begin
        kw_q <= 0;
        if (kh_q == K_H - 1) begin
          kh_q   <= 0;
          state_q <= ST_FEATURE_DONE;
        end else begin
          kh_q <= kh_q + 1;
          state_q <= ST_KERNEL_REQ;
        end
      end else begin
        kw_q <= kw_q + 1;
        state_q <= ST_KERNEL_REQ;
      end
    end
  endtask

  task automatic advance_feature;
    begin
      if (ch_q == CHANNELS - 1) begin
        ch_q <= 0;
        if (ow_q == OUT_W - 1) begin
          ow_q <= 0;
          if (oh_q == OUT_H - 1) begin
            state_q <= ST_FC_REQUANT;
          end else begin
            oh_q <= oh_q + 1;
            conv_acc_q <= depthwise_bias(0);
            state_q <= ST_KERNEL_REQ;
          end
        end else begin
          ow_q <= ow_q + 1;
          conv_acc_q <= depthwise_bias(0);
          state_q <= ST_KERNEL_REQ;
        end
      end else begin
        ch_q <= ch_q + 1;
        conv_acc_q <= depthwise_bias(ch_q + 1);
        state_q <= ST_KERNEL_REQ;
      end
    end
  endtask

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= ST_IDLE;
      oh_q          <= 0;
      ow_q          <= 0;
      ch_q          <= 0;
      kh_q          <= 0;
      kw_q          <= 0;
      sample_lane_q <= 2'b00;
      conv_acc_q    <= 32'sd0;
      score0_q      <= 32'sd0;
      score1_q      <= 32'sd0;
      score2_q      <= 32'sd0;
      score3_q      <= 32'sd0;
      cycle_count_q <= 32'h0;
      result_class_q <= 2'h0;
      done_q        <= 1'b0;
      busy_q        <= 1'b0;
    end else begin
      logic signed [31:0] relu_value;
      logic signed [31:0] sample_value;
      logic signed [31:0] next_conv;
      logic signed [31:0] best_score;

      done_q <= 1'b0;
      if (busy_q) begin
        cycle_count_q <= cycle_count_q + 1'b1;
      end

      unique case (state_q)
        ST_IDLE: begin
          busy_q <= 1'b0;
          if (start_i) begin
            busy_q         <= 1'b1;
            oh_q           <= 0;
            ow_q           <= 0;
            ch_q           <= 0;
            kh_q           <= 0;
            kw_q           <= 0;
            conv_acc_q     <= depthwise_bias(0);
            score0_q       <= fc_bias(0);
            score1_q       <= fc_bias(1);
            score2_q       <= fc_bias(2);
            score3_q       <= fc_bias(3);
            cycle_count_q  <= 32'h0;
            result_class_q <= 2'h0;
            state_q        <= ST_KERNEL_REQ;
          end
        end

        ST_KERNEL_REQ: begin
          sample_lane_q <= sample_lane_now;

          if (!sample_valid_now) begin
            advance_kernel();
          end else if (mem_gnt_i) begin
            state_q <= ST_KERNEL_WAIT;
          end
        end

        ST_KERNEL_WAIT: begin
          if (mem_rvalid_i) begin
            sample_value = byte_to_sample(pick_byte(mem_rdata_i, sample_lane_q)) - input_zero_point();
            next_conv    = conv_acc_q +
                           (sample_value *
                            (depthwise_weight(ch_q, kh_q, kw_q) -
                             depthwise_weight_zero_point(ch_q)));
            conv_acc_q   <= next_conv;
            advance_kernel();
          end
        end

        ST_FEATURE_DONE: begin
          relu_value = depthwise_activation(conv_acc_q, ch_q);
          score0_q <= score0_q + ((relu_value - depthwise_output_zero_point()) *
                                   (fc_weight(0, oh_q, ow_q, ch_q) -
                                    fc_weight_zero_point(0)));
          score1_q <= score1_q + ((relu_value - depthwise_output_zero_point()) *
                                   (fc_weight(1, oh_q, ow_q, ch_q) -
                                    fc_weight_zero_point(1)));
          score2_q <= score2_q + ((relu_value - depthwise_output_zero_point()) *
                                   (fc_weight(2, oh_q, ow_q, ch_q) -
                                    fc_weight_zero_point(2)));
          score3_q <= score3_q + ((relu_value - depthwise_output_zero_point()) *
                                   (fc_weight(3, oh_q, ow_q, ch_q) -
                                    fc_weight_zero_point(3)));
          advance_feature();
        end

        ST_FC_REQUANT: begin
          score0_q <= fc_output_score(0, score0_q);
          score1_q <= fc_output_score(1, score1_q);
          score2_q <= fc_output_score(2, score2_q);
          score3_q <= fc_output_score(3, score3_q);
          state_q <= ST_ARGMAX;
        end

        ST_ARGMAX: begin
          best_score = score0_q;
          result_class_q <= 2'd0;
          if (score1_q > best_score) begin
            best_score = score1_q;
            result_class_q <= 2'd1;
          end
          if (score2_q > best_score) begin
            best_score = score2_q;
            result_class_q <= 2'd2;
          end
          if (score3_q > best_score) begin
            result_class_q <= 2'd3;
          end
          state_q <= ST_WRITE_CLASS;
        end

        ST_WRITE_CLASS: begin
          if (mem_gnt_i) begin
            state_q <= ST_WRITE_SCORE0;
          end
        end

        ST_WRITE_SCORE0: begin
          if (mem_gnt_i) begin
            state_q <= ST_WRITE_SCORE1;
          end
        end

        ST_WRITE_SCORE1: begin
          if (mem_gnt_i) begin
            state_q <= ST_WRITE_SCORE2;
          end
        end

        ST_WRITE_SCORE2: begin
          if (mem_gnt_i) begin
            state_q <= ST_WRITE_SCORE3;
          end
        end

        ST_WRITE_SCORE3: begin
          if (mem_gnt_i) begin
            state_q <= ST_DONE;
          end
        end

        ST_DONE: begin
          busy_q  <= 1'b0;
          done_q  <= 1'b1;
          state_q <= ST_IDLE;
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
