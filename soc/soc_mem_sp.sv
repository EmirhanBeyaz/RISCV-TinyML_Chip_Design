module soc_mem_sp #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH_WORDS = 2048,
    parameter bit READ_ONLY = 1'b0
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic                      req_i,
    input  logic                      we_i,
    input  logic [(DATA_WIDTH/8)-1:0] be_i,
    input  logic [ADDR_WIDTH-1:0]     addr_i,
    input  logic [DATA_WIDTH-1:0]     wdata_i,
    output logic                      rvalid_o,
    output logic [DATA_WIDTH-1:0]     rdata_o
);

  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int WORD_ADDR_WIDTH = (DEPTH_WORDS > 1) ? $clog2(DEPTH_WORDS) : 1;

  (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem[0:DEPTH_WORDS-1];

  integer init_idx;
  integer byte_idx;

  function automatic logic [WORD_ADDR_WIDTH-1:0] word_index(input logic [ADDR_WIDTH-1:0] addr);
    return addr[WORD_ADDR_WIDTH+1:2];
  endfunction

  function automatic bit addr_in_range(input logic [ADDR_WIDTH-1:0] addr);
    return word_index(addr) < DEPTH_WORDS;
  endfunction

  initial begin
    for (init_idx = 0; init_idx < DEPTH_WORDS; init_idx = init_idx + 1) begin
      mem[init_idx] = '0;
    end

  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      rvalid_o <= 1'b0;
      rdata_o  <= '0;
    end else begin
      logic [WORD_ADDR_WIDTH-1:0] idx;
      logic [DATA_WIDTH-1:0] next_word;

      rvalid_o <= req_i && addr_in_range(addr_i);

      if (req_i) begin
        rdata_o <= '0;

        if (!addr_in_range(addr_i)) begin
`ifndef SYNTHESIS
          $error("soc_mem_sp: address %h outside %0d-word memory", addr_i, DEPTH_WORDS);
          $fatal(1);
`endif
        end else begin
          idx       = word_index(addr_i);
          next_word = mem[idx];
          rdata_o   <= mem[idx];

          if (we_i) begin
            if (READ_ONLY) begin
`ifndef SYNTHESIS
              $error("soc_mem_sp: write attempted to read-only memory at %h", addr_i);
              $fatal(1);
`endif
            end else begin
              for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
                if (be_i[byte_idx]) begin
                  next_word[8*byte_idx +: 8] = wdata_i[8*byte_idx +: 8];
                end
              end

              mem[idx] <= next_word;
            end
          end
        end
      end
    end
  end

endmodule
