module soc_apb_i2c_master #(
    parameter int APB_ADDR_WIDTH = 12
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [31:0]               pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [31:0]               prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,
    input  logic                      i2c_sda_i,
    output logic                      i2c_scl_o,
    output logic                      i2c_scl_oe_o,
    output logic                      i2c_sda_o,
    output logic                      i2c_sda_oe_o
);

  localparam logic [11:0] REG_ID       = 12'h000;
  localparam logic [11:0] REG_VERSION  = 12'h004;
  localparam logic [11:0] REG_PRESCALE = 12'h008;
  localparam logic [11:0] REG_CTRL     = 12'h00C;
  localparam logic [11:0] REG_STATUS   = 12'h010;
  localparam logic [11:0] REG_TXRX     = 12'h014;
  localparam logic [11:0] REG_CMD      = 12'h018;

  localparam logic [31:0] I2C_ID      = 32'h4932_434d;  // "I2CM"
  localparam logic [31:0] I2C_VERSION = 32'h0001_0000;

  typedef enum logic [4:0] {
    ST_IDLE,
    ST_START_PREP,
    ST_START_ASSERT,
    ST_WRITE_SETUP,
    ST_WRITE_HIGH,
    ST_WRITE_SAMPLE,
    ST_WRITE_ACK_SETUP,
    ST_WRITE_ACK_HIGH,
    ST_WRITE_ACK_SAMPLE,
    ST_READ_SETUP,
    ST_READ_HIGH,
    ST_READ_SAMPLE,
    ST_READ_ACK_SETUP,
    ST_READ_ACK_HIGH,
    ST_READ_ACK_SAMPLE,
    ST_STOP_PREP,
    ST_STOP_RAISE,
    ST_STOP_RELEASE
  } state_t;

  logic        reg_access;
  logic        reg_write;
  logic        reg_read;
  logic [11:0] reg_addr;
  logic [31:0] status_word;
  logic        busy;

  logic [15:0] prescale_q;
  logic        ctrl_enable_q;
  logic [7:0]  tx_data_q;
  logic [7:0]  rx_data_q;
  logic [31:0] last_cmd_q;
  logic        cmd_done_q;
  logic        ack_error_q;
  logic        rx_valid_q;
  logic        bus_owned_q;

  logic        cmd_start_q;
  logic        cmd_stop_q;
  logic        cmd_write_q;
  logic        cmd_read_q;
  logic        cmd_read_nack_q;
  logic [7:0]  shifter_q;
  logic [2:0]  bit_idx_q;
  logic [15:0] prescale_cnt_q;
  logic        scl_drive_low_q;
  logic        sda_drive_low_q;
  state_t      state_q;

  logic        cmd_reg_access;
  logic        cmd_has_write;
  logic        cmd_has_read;
  logic        cmd_op_valid;
  logic        cmd_can_start;
  logic        cmd_accept;
  logic        reg_addr_valid;
  logic        reg_write_valid;

  assign reg_access = psel_i && penable_i;
  assign reg_write  = reg_access && pwrite_i;
  assign reg_read   = reg_access && !pwrite_i;
  assign reg_addr   = {paddr_i[APB_ADDR_WIDTH-1:2], 2'b00};
  assign busy       = (state_q != ST_IDLE);

  assign cmd_reg_access = reg_write && (reg_addr == REG_CMD);
  assign cmd_has_write  = pwdata_i[2];
  assign cmd_has_read   = pwdata_i[3];
  assign cmd_op_valid   = cmd_has_write ^ cmd_has_read;
  assign cmd_can_start  = pwdata_i[0] || bus_owned_q;
  assign cmd_accept     = cmd_reg_access && ctrl_enable_q && !busy && cmd_op_valid && cmd_can_start;

  assign reg_addr_valid = (reg_addr == REG_ID)       ||
                          (reg_addr == REG_VERSION)  ||
                          (reg_addr == REG_PRESCALE) ||
                          (reg_addr == REG_CTRL)     ||
                          (reg_addr == REG_STATUS)   ||
                          (reg_addr == REG_TXRX)     ||
                          (reg_addr == REG_CMD);

  assign reg_write_valid = (reg_addr == REG_PRESCALE) ||
                           (reg_addr == REG_CTRL)     ||
                           (reg_addr == REG_TXRX)     ||
                           (reg_addr == REG_CMD);

  assign pready_o = 1'b1;

  always_comb begin
    pslverr_o = 1'b0;

    if (reg_access) begin
      if (!reg_addr_valid) begin
        pslverr_o = 1'b1;
      end else if (pwrite_i && !reg_write_valid) begin
        pslverr_o = 1'b1;
      end else if (cmd_reg_access && !cmd_accept) begin
        pslverr_o = 1'b1;
      end
    end
  end

  assign status_word = {
      24'h0,
      bus_owned_q,
      ~scl_drive_low_q,
      i2c_sda_i,
      ctrl_enable_q && !busy,
      rx_valid_q,
      ack_error_q,
      cmd_done_q,
      busy
  };

  always_comb begin
    prdata_o = 32'h0;

    unique case (reg_addr)
      REG_ID:       prdata_o = I2C_ID;
      REG_VERSION:  prdata_o = I2C_VERSION;
      REG_PRESCALE: prdata_o = {16'h0, prescale_q};
      REG_CTRL:     prdata_o = {31'h0, ctrl_enable_q};
      REG_STATUS:   prdata_o = status_word;
      REG_TXRX:     prdata_o = {24'h0, rx_data_q};
      REG_CMD:      prdata_o = last_cmd_q;
      default:      prdata_o = 32'h0;
    endcase
  end

  assign i2c_scl_o    = 1'b0;
  assign i2c_sda_o    = 1'b0;
  assign i2c_scl_oe_o = scl_drive_low_q;
  assign i2c_sda_oe_o = sda_drive_low_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prescale_q      <= 16'd4;
      ctrl_enable_q   <= 1'b0;
      tx_data_q       <= 8'h0;
      rx_data_q       <= 8'h0;
      last_cmd_q      <= 32'h0;
      cmd_done_q      <= 1'b0;
      ack_error_q     <= 1'b0;
      rx_valid_q      <= 1'b0;
      bus_owned_q     <= 1'b0;
      cmd_start_q     <= 1'b0;
      cmd_stop_q      <= 1'b0;
      cmd_write_q     <= 1'b0;
      cmd_read_q      <= 1'b0;
      cmd_read_nack_q <= 1'b0;
      shifter_q       <= 8'h0;
      bit_idx_q       <= 3'd7;
      prescale_cnt_q  <= 16'd4;
      scl_drive_low_q <= 1'b0;
      sda_drive_low_q <= 1'b0;
      state_q         <= ST_IDLE;
    end else begin
      if (reg_write && !pslverr_o) begin
        unique case (reg_addr)
          REG_PRESCALE: prescale_q    <= (pwdata_i[15:0] == 16'h0) ? 16'd1 : pwdata_i[15:0];
          REG_CTRL:     ctrl_enable_q <= pwdata_i[0];
          REG_TXRX: begin
            tx_data_q   <= pwdata_i[7:0];
            rx_valid_q  <= 1'b0;
          end
          default: begin
          end
        endcase
      end

      if (cmd_accept) begin
        last_cmd_q      <= pwdata_i;
        cmd_done_q      <= 1'b0;
        ack_error_q     <= 1'b0;
        if (!pwdata_i[3]) begin
          rx_valid_q <= 1'b0;
        end
        cmd_start_q     <= pwdata_i[0];
        cmd_stop_q      <= pwdata_i[1];
        cmd_write_q     <= pwdata_i[2];
        cmd_read_q      <= pwdata_i[3];
        cmd_read_nack_q <= pwdata_i[4];
        shifter_q       <= tx_data_q;
        bit_idx_q       <= 3'd7;
        prescale_cnt_q  <= prescale_q;

        if (pwdata_i[0]) begin
          scl_drive_low_q <= 1'b0;
          sda_drive_low_q <= 1'b0;
          state_q         <= ST_START_PREP;
        end else if (pwdata_i[2]) begin
          scl_drive_low_q <= 1'b1;
          sda_drive_low_q <= ~tx_data_q[7];
          state_q         <= ST_WRITE_SETUP;
        end else begin
          scl_drive_low_q <= 1'b1;
          sda_drive_low_q <= 1'b0;
          state_q         <= ST_READ_SETUP;
        end
      end else if (busy) begin
        if (prescale_cnt_q != 16'h0) begin
          prescale_cnt_q <= prescale_cnt_q - 16'd1;
        end else begin
          prescale_cnt_q <= prescale_q;

          unique case (state_q)
            ST_START_PREP: begin
              scl_drive_low_q <= 1'b0;
              sda_drive_low_q <= 1'b0;
              state_q         <= ST_START_ASSERT;
            end

            ST_START_ASSERT: begin
              scl_drive_low_q <= 1'b0;
              sda_drive_low_q <= 1'b1;
              state_q         <= cmd_write_q ? ST_WRITE_SETUP : ST_READ_SETUP;
            end

            ST_WRITE_SETUP: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= ~shifter_q[bit_idx_q];
              state_q         <= ST_WRITE_HIGH;
            end

            ST_WRITE_HIGH: begin
              scl_drive_low_q <= 1'b0;
              state_q         <= ST_WRITE_SAMPLE;
            end

            ST_WRITE_SAMPLE: begin
              scl_drive_low_q <= 1'b1;
              if (bit_idx_q == 3'd0) begin
                sda_drive_low_q <= 1'b0;
                state_q         <= ST_WRITE_ACK_SETUP;
              end else begin
                bit_idx_q <= bit_idx_q - 3'd1;
                state_q   <= ST_WRITE_SETUP;
              end
            end

            ST_WRITE_ACK_SETUP: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= 1'b0;
              state_q         <= ST_WRITE_ACK_HIGH;
            end

            ST_WRITE_ACK_HIGH: begin
              scl_drive_low_q <= 1'b0;
              state_q         <= ST_WRITE_ACK_SAMPLE;
            end

            ST_WRITE_ACK_SAMPLE: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= 1'b0;
              ack_error_q     <= i2c_sda_i;
              if (cmd_stop_q) begin
                state_q <= ST_STOP_PREP;
              end else begin
                cmd_done_q  <= 1'b1;
                bus_owned_q <= 1'b1;
                state_q     <= ST_IDLE;
              end
            end

            ST_READ_SETUP: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= 1'b0;
              state_q         <= ST_READ_HIGH;
            end

            ST_READ_HIGH: begin
              scl_drive_low_q <= 1'b0;
              state_q         <= ST_READ_SAMPLE;
            end

            ST_READ_SAMPLE: begin
              scl_drive_low_q      <= 1'b1;
              shifter_q[bit_idx_q] <= i2c_sda_i;
              if (bit_idx_q == 3'd0) begin
                state_q <= ST_READ_ACK_SETUP;
              end else begin
                bit_idx_q <= bit_idx_q - 3'd1;
                state_q   <= ST_READ_SETUP;
              end
            end

            ST_READ_ACK_SETUP: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= !cmd_read_nack_q;
              state_q         <= ST_READ_ACK_HIGH;
            end

            ST_READ_ACK_HIGH: begin
              scl_drive_low_q <= 1'b0;
              state_q         <= ST_READ_ACK_SAMPLE;
            end

            ST_READ_ACK_SAMPLE: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= 1'b0;
              rx_data_q       <= shifter_q;
              rx_valid_q      <= 1'b1;
              if (cmd_stop_q) begin
                state_q <= ST_STOP_PREP;
              end else begin
                cmd_done_q  <= 1'b1;
                bus_owned_q <= 1'b1;
                state_q     <= ST_IDLE;
              end
            end

            ST_STOP_PREP: begin
              scl_drive_low_q <= 1'b1;
              sda_drive_low_q <= 1'b1;
              state_q         <= ST_STOP_RAISE;
            end

            ST_STOP_RAISE: begin
              scl_drive_low_q <= 1'b0;
              sda_drive_low_q <= 1'b1;
              state_q         <= ST_STOP_RELEASE;
            end

            ST_STOP_RELEASE: begin
              scl_drive_low_q <= 1'b0;
              sda_drive_low_q <= 1'b0;
              cmd_done_q      <= 1'b1;
              bus_owned_q     <= 1'b0;
              state_q         <= ST_IDLE;
            end

            default: begin
              state_q <= ST_IDLE;
            end
          endcase
        end
      end else begin
        prescale_cnt_q <= prescale_q;
        if (bus_owned_q) begin
          scl_drive_low_q <= 1'b1;
          sda_drive_low_q <= 1'b0;
        end else begin
          scl_drive_low_q <= 1'b0;
          sda_drive_low_q <= 1'b0;
        end
      end
    end
  end

endmodule
