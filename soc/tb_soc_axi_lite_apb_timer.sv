`timescale 1ns/1ps

module tb_soc_axi_lite_apb_timer;

  import soc_map_pkg::*;

  localparam logic [11:0] CFG_REG_LO   = 12'h000;
  localparam logic [11:0] TIMER_CMP_LO = 12'h010;
  localparam logic [11:0] TIMER_START_LO = 12'h018;
  localparam logic [31:0] CFG_LO_IRQ_ONE_SHOT = 32'h0000_0024;

  logic clk;
  logic rst_n;

  logic [31:0] s_axi_awaddr;
  logic [ 2:0] s_axi_awprot;
  logic        s_axi_awvalid;
  logic        s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [ 3:0] s_axi_wstrb;
  logic        s_axi_wvalid;
  logic        s_axi_wready;
  logic [ 1:0] s_axi_bresp;
  logic        s_axi_bvalid;
  logic        s_axi_bready;
  logic [31:0] s_axi_araddr;
  logic [ 2:0] s_axi_arprot;
  logic        s_axi_arvalid;
  logic        s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [ 1:0] s_axi_rresp;
  logic        s_axi_rvalid;
  logic        s_axi_rready;

  logic [31:0] apb_paddr;
  logic [ 2:0] apb_pprot;
  logic        apb_penable;
  logic        apb_pwrite;
  logic [31:0] apb_pwdata;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_psel;
  logic [SOC_MMIO_SLOT_COUNT-1:0][31:0] apb_prdata;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_pready;
  logic [SOC_MMIO_SLOT_COUNT-1:0] apb_pslverr;

  logic [31:0] timer_prdata;
  logic        timer_pready;
  logic        timer_pslverr;
  logic timer_irq_lo;
  logic timer_irq_hi;
  logic timer_busy;

  integer idx;

  soc_axi_lite_apb_island #(
      .NO_APB_SLOTS(SOC_MMIO_SLOT_COUNT)
  ) dut (
      .clk_i          (clk),
      .rst_ni         (rst_n),
      .s_axi_awaddr_i (s_axi_awaddr),
      .s_axi_awprot_i (s_axi_awprot),
      .s_axi_awvalid_i(s_axi_awvalid),
      .s_axi_awready_o(s_axi_awready),
      .s_axi_wdata_i  (s_axi_wdata),
      .s_axi_wstrb_i  (s_axi_wstrb),
      .s_axi_wvalid_i (s_axi_wvalid),
      .s_axi_wready_o (s_axi_wready),
      .s_axi_bresp_o  (s_axi_bresp),
      .s_axi_bvalid_o (s_axi_bvalid),
      .s_axi_bready_i (s_axi_bready),
      .s_axi_araddr_i (s_axi_araddr),
      .s_axi_arprot_i (s_axi_arprot),
      .s_axi_arvalid_i(s_axi_arvalid),
      .s_axi_arready_o(s_axi_arready),
      .s_axi_rdata_o  (s_axi_rdata),
      .s_axi_rresp_o  (s_axi_rresp),
      .s_axi_rvalid_o (s_axi_rvalid),
      .s_axi_rready_i (s_axi_rready),
      .paddr_o        (apb_paddr),
      .pprot_o        (apb_pprot),
      .penable_o      (apb_penable),
      .pwrite_o       (apb_pwrite),
      .pwdata_o       (apb_pwdata),
      .psel_o         (apb_psel),
      .prdata_i       (apb_prdata),
      .pready_i       (apb_pready),
      .pslverr_i      (apb_pslverr)
  );

  apb_timer_unit timer_i (
      .HCLK      (clk),
      .HRESETn   (rst_n),
      .PADDR     (apb_paddr[11:0]),
      .PWDATA    (apb_pwdata),
      .PWRITE    (apb_pwrite),
      .PSEL      (apb_psel[SOC_MMIO_TIMER]),
      .PENABLE   (apb_penable),
      .PRDATA    (timer_prdata),
      .PREADY    (timer_pready),
      .PSLVERR   (timer_pslverr),
      .ref_clk_i (1'b0),
      .stoptimer_i(1'b0),
      .event_lo_i(1'b0),
      .event_hi_i(1'b0),
      .irq_lo_o  (timer_irq_lo),
      .irq_hi_o  (timer_irq_hi),
      .busy_o    (timer_busy)
  );

  always_comb begin
    for (idx = 0; idx < SOC_MMIO_SLOT_COUNT; idx = idx + 1) begin
      apb_prdata[idx]  = '0;
      apb_pready[idx]  = 1'b1;
      apb_pslverr[idx] = 1'b1;
    end

    apb_prdata[SOC_MMIO_TIMER]  = timer_prdata;
    apb_pready[SOC_MMIO_TIMER]  = timer_pready;
    apb_pslverr[SOC_MMIO_TIMER] = timer_pslverr;
  end

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;

    s_axi_awaddr  = '0;
    s_axi_awprot  = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = '0;
    s_axi_wstrb   = '0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = '0;
    s_axi_arprot  = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    axi_write(SOC_TIMER_BASE_ADDR + TIMER_CMP_LO, 32'd5);
    axi_write(SOC_TIMER_BASE_ADDR + CFG_REG_LO, CFG_LO_IRQ_ONE_SHOT);
    axi_check_read(SOC_TIMER_BASE_ADDR + TIMER_CMP_LO, 32'd5);
    axi_check_read(SOC_TIMER_BASE_ADDR + CFG_REG_LO, CFG_LO_IRQ_ONE_SHOT);

    axi_write(SOC_TIMER_BASE_ADDR + TIMER_START_LO, 32'h1);

    repeat (20) begin
      @(posedge clk);
      if (timer_irq_lo) begin
        repeat (2) @(posedge clk);
        if (timer_busy) begin
          $display("tb_soc_axi_lite_apb_timer: timer IRQ arrived while busy remained set");
          $fatal(1);
        end
        $display("tb_soc_axi_lite_apb_timer: PASS");
        $finish;
      end
    end

    $display("tb_soc_axi_lite_apb_timer: timer IRQ did not assert");
    $fatal(1);
  end

  initial begin
    #5000;
    $display("tb_soc_axi_lite_apb_timer: TIMEOUT state");
    $display("  awvalid=%0b awready=%0b wvalid=%0b wready=%0b bvalid=%0b bresp=%0b",
             s_axi_awvalid, s_axi_awready, s_axi_wvalid, s_axi_wready, s_axi_bvalid, s_axi_bresp);
    $display("  arvalid=%0b arready=%0b rvalid=%0b rresp=%0b rdata=%h",
             s_axi_arvalid, s_axi_arready, s_axi_rvalid, s_axi_rresp, s_axi_rdata);
    $display("  psel=%h penable=%0b pwrite=%0b paddr=%h pwdata=%h",
             apb_psel, apb_penable, apb_pwrite, apb_paddr, apb_pwdata);
    $display("  timer_irq_lo=%0b timer_busy=%0b timer_prdata=%h pready=%0b pslverr=%0b",
             timer_irq_lo, timer_busy, timer_prdata, timer_pready, timer_pslverr);
    $fatal(1);
  end

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    begin
      s_axi_awaddr  = addr;
      s_axi_awprot  = 3'b000;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = 4'hf;
      s_axi_wvalid  = 1'b1;

      wait (s_axi_awready && s_axi_wready);
      @(posedge clk);
      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      s_axi_bready = 1'b1;
      while (!s_axi_bvalid) @(posedge clk);
      if (s_axi_bresp !== 2'b00) begin
        $display("tb_soc_axi_lite_apb_timer: write response error %b at %h", s_axi_bresp, addr);
        $fatal(1);
      end
      while (s_axi_bvalid) @(posedge clk);
      @(negedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic axi_check_read(input logic [31:0] addr, input logic [31:0] exp_data);
    begin
      s_axi_araddr  = addr;
      s_axi_arprot  = 3'b000;
      s_axi_arvalid = 1'b1;

      wait (s_axi_arready);
      @(posedge clk);
      @(negedge clk);
      s_axi_arvalid = 1'b0;

      s_axi_rready = 1'b1;
      while (!s_axi_rvalid) @(posedge clk);

      if (s_axi_rresp !== 2'b00) begin
        $display("tb_soc_axi_lite_apb_timer: read response error %b at %h", s_axi_rresp, addr);
        $fatal(1);
      end

      if (s_axi_rdata !== exp_data) begin
        $display("tb_soc_axi_lite_apb_timer: readback mismatch %h != %h at %h",
                 s_axi_rdata, exp_data, addr);
        $fatal(1);
      end

      while (s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
