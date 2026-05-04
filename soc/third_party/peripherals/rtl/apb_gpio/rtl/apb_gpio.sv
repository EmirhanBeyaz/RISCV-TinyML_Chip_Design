// Copyright 2021 QuickLogic.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`define REG_SETGPIO 12'h000
`define REG_CLRGPIO 12'h004
`define REG_TOGGPIO 12'h008

`define REG_PIN0 12'h010
`define REG_PIN1 12'h014
`define REG_PIN2 12'h018
`define REG_PIN3 12'h01C

`define REG_OUT0 12'h020
`define REG_OUT1 12'h024
`define REG_OUT2 12'h028
`define REG_OUT3 12'h02C


`define REG_SETSEL 12'h030
`define REG_RDSTAT 12'h034
`define REG_SETDIR 12'h038
`define REG_SETINT 12'h03C
`define REG_INTACK 12'H040


// Keep the GPIO width self-contained so GUI-based Vivado imports do not
// depend on include-path setup to parse this file.
`ifndef N_GPIO
`define N_GPIO 32
`endif

module apb_gpiov2 #(
    parameter APB_ADDR_WIDTH = 12
) (
    input logic HCLK,
    input logic HRESETn,
    input logic dft_cg_enable_i,

    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic [              31:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic [              31:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,

    input  logic [`N_GPIO-1:0] gpio_in,
    output logic [`N_GPIO-1:0] gpio_in_sync,
    output logic [`N_GPIO-1:0] gpio_out,
    output logic [`N_GPIO-1:0] gpio_dir,
    output logic [`N_GPIO-1:0] interrupt
);

  localparam int unsigned GPIO_COUNT = `N_GPIO;
  localparam int unsigned GPIO_SEL_W = (GPIO_COUNT > 1) ? $clog2(GPIO_COUNT) : 1;

  logic [GPIO_SEL_W-1:0] r_gpio_select;

  logic [GPIO_COUNT-1:0] r_gpio_inten;
  logic [2:0]            r_gpio_inttype [0:GPIO_COUNT-1];

  logic [GPIO_COUNT-1:0] r_gpio_out_reg;
  logic [1:0]            r_gpio_dir_mode [0:GPIO_COUNT-1];

  logic [GPIO_COUNT-1:0] r_gpio_sync0;
  logic [GPIO_COUNT-1:0] r_gpio_sync1;
  logic [GPIO_COUNT-1:0] r_gpio_in_reg;

  logic [GPIO_COUNT-1:0] r_gpio_rise;
  logic [GPIO_COUNT-1:0] r_gpio_fall;
  logic [GPIO_COUNT-1:0] s_is_int_rise;
  logic [GPIO_COUNT-1:0] s_is_int_fall;
  logic [GPIO_COUNT-1:0] s_is_int_low;
  logic [GPIO_COUNT-1:0] s_is_int_hi;
  logic [GPIO_COUNT-1:0] s_block_int;
  logic [GPIO_COUNT-1:0] block_int_next;

  integer idx;
  integer idx_ff;

  assign gpio_in_sync = r_gpio_in_reg;
  assign PREADY       = 1'b1;
  assign PSLVERR      = 1'b0;

  always_comb begin
    PRDATA = '0;
    block_int_next = s_block_int | s_is_int_low | s_is_int_hi;

    for (idx = 0; idx < GPIO_COUNT; idx = idx + 1) begin
      s_is_int_fall[idx] = r_gpio_inttype[idx][0] & r_gpio_fall[idx];
      s_is_int_rise[idx] = r_gpio_inttype[idx][1] & r_gpio_rise[idx];
      s_is_int_low[idx]  = (r_gpio_inttype[idx] == 3'b000) &
                           ~r_gpio_in_reg[idx] &
                           ~s_block_int[idx] &
                           r_gpio_inten[idx];
      s_is_int_hi[idx]   = (r_gpio_inttype[idx] == 3'b100) &
                           r_gpio_in_reg[idx] &
                           ~s_block_int[idx] &
                           r_gpio_inten[idx];
      interrupt[idx]     = (r_gpio_inten[idx] & (s_is_int_fall[idx] | s_is_int_rise[idx])) |
                           s_is_int_low[idx] | s_is_int_hi[idx];
      gpio_out[idx]      = r_gpio_dir_mode[idx][0] & r_gpio_out_reg[idx];
      gpio_dir[idx]      = r_gpio_dir_mode[idx][1] ? ~r_gpio_out_reg[idx] :
                                                 r_gpio_dir_mode[idx][0];
    end

    if (PSEL && PENABLE && PWRITE && (PADDR[11:0] == `REG_INTACK)) begin
      block_int_next[PWDATA[GPIO_SEL_W-1:0]] = 1'b0;
    end

    if (PSEL && PENABLE && !PWRITE) begin
      case (PADDR[11:0])
        `REG_RDSTAT: begin
          PRDATA[25:24]          = r_gpio_dir_mode[r_gpio_select];
          PRDATA[19:17]          = r_gpio_inttype[r_gpio_select];
          PRDATA[16]             = r_gpio_inten[r_gpio_select];
          PRDATA[12]             = r_gpio_in_reg[r_gpio_select];
          PRDATA[8]              = r_gpio_out_reg[r_gpio_select];
          PRDATA[GPIO_SEL_W-1:0] = r_gpio_select;
        end
        `REG_OUT0: begin
          PRDATA = r_gpio_out_reg;
        end
        `REG_PIN0: begin
          PRDATA = r_gpio_in_reg;
        end
        default: begin
          PRDATA = '0;
        end
      endcase
    end
  end

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (~HRESETn) begin
      r_gpio_select  <= '0;
      r_gpio_inten   <= '0;
      r_gpio_out_reg <= '0;
      r_gpio_sync0   <= '0;
      r_gpio_sync1   <= '0;
      r_gpio_in_reg  <= '0;
      r_gpio_rise    <= '0;
      r_gpio_fall    <= '0;
      s_block_int    <= '0;
      for (idx_ff = 0; idx_ff < GPIO_COUNT; idx_ff = idx_ff + 1) begin
        r_gpio_inttype[idx_ff] <= '0;
        r_gpio_dir_mode[idx_ff] <= '0;
      end
    end else begin
      r_gpio_sync0  <= gpio_in;
      r_gpio_sync1  <= r_gpio_sync0;
      r_gpio_in_reg <= r_gpio_sync1;
      r_gpio_rise   <= ~r_gpio_in_reg & r_gpio_sync1;
      r_gpio_fall   <= r_gpio_in_reg & ~r_gpio_sync1;
      s_block_int   <= block_int_next;

      if (PSEL && PENABLE && PWRITE) begin
        case (PADDR[11:0])
          `REG_SETSEL: begin
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_SETDIR: begin
            r_gpio_dir_mode[PWDATA[GPIO_SEL_W-1:0]] <= PWDATA[25:24];
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_SETINT: begin
            r_gpio_inttype[PWDATA[GPIO_SEL_W-1:0]] <= PWDATA[19:17];
            r_gpio_inten[PWDATA[GPIO_SEL_W-1:0]]   <= PWDATA[16];
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_SETGPIO: begin
            r_gpio_out_reg[PWDATA[GPIO_SEL_W-1:0]] <= 1'b1;
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_CLRGPIO: begin
            r_gpio_out_reg[PWDATA[GPIO_SEL_W-1:0]] <= 1'b0;
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_TOGGPIO: begin
            r_gpio_out_reg[PWDATA[GPIO_SEL_W-1:0]] <= ~r_gpio_out_reg[PWDATA[GPIO_SEL_W-1:0]];
            r_gpio_select <= PWDATA[GPIO_SEL_W-1:0];
          end
          `REG_OUT0: begin
            r_gpio_out_reg <= PWDATA[GPIO_COUNT-1:0];
          end
          default: begin
          end
        endcase
      end
    end
  end


endmodule
