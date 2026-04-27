`timescale 1ns/1ps

module tb_soc_axi_lite_apb_gpio;

  import soc_map_pkg::*;

  localparam logic [11:0] REG_SETGPIO = 12'h000;
  localparam logic [11:0] REG_CLRGPIO = 12'h004;
  localparam logic [11:0] REG_PIN0    = 12'h010;
  localparam logic [11:0] REG_OUT0    = 12'h020;
  localparam logic [11:0] REG_SETSEL  = 12'h030;
  localparam logic [11:0] REG_RDSTAT  = 12'h034;
  localparam logic [11:0] REG_SETDIR  = 12'h038;

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

  logic [31:0] gpio_prdata;
  logic        gpio_pready;
  logic        gpio_pslverr;
  logic [31:0] gpio_in;
  logic [31:0] gpio_in_sync;
  logic [31:0] gpio_out;
  logic [31:0] gpio_dir;
  logic [31:0] gpio_irq;

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

  apb_gpiov2 gpio_i (
      .HCLK           (clk),
      .HRESETn        (rst_n),
      .dft_cg_enable_i(1'b0),
      .PADDR          (apb_paddr[11:0]),
      .PWDATA         (apb_pwdata),
      .PWRITE         (apb_pwrite),
      .PSEL           (apb_psel[SOC_MMIO_GPIO]),
      .PENABLE        (apb_penable),
      .PRDATA         (gpio_prdata),
      .PREADY         (gpio_pready),
      .PSLVERR        (gpio_pslverr),
      .gpio_in        (gpio_in),
      .gpio_in_sync   (gpio_in_sync),
      .gpio_out       (gpio_out),
      .gpio_dir       (gpio_dir),
      .interrupt      (gpio_irq)
  );

  always_comb begin
    for (idx = 0; idx < SOC_MMIO_SLOT_COUNT; idx = idx + 1) begin
      apb_prdata[idx]  = '0;
      apb_pready[idx]  = 1'b1;
      apb_pslverr[idx] = 1'b1;
    end

    apb_prdata[SOC_MMIO_GPIO]  = gpio_prdata;
    apb_pready[SOC_MMIO_GPIO]  = gpio_pready;
    apb_pslverr[SOC_MMIO_GPIO] = gpio_pslverr;
  end

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    gpio_in = '0;

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

    // Configure GPIO3 as push-pull output and set it high.
    axi_write(SOC_GPIO_BASE_ADDR + REG_SETDIR, 32'h0100_0003);
    axi_write(SOC_GPIO_BASE_ADDR + REG_SETGPIO, 32'h0000_0003);
    axi_check_read(SOC_GPIO_BASE_ADDR + REG_OUT0, 32'h0000_0008);
    axi_check_read(SOC_GPIO_BASE_ADDR + REG_RDSTAT, 32'h0100_0103);

    if (gpio_out[3] !== 1'b1 || gpio_dir[3] !== 1'b1) begin
      $display("tb_soc_axi_lite_apb_gpio: GPIO3 output/dir mismatch out=%0b dir=%0b",
               gpio_out[3], gpio_dir[3]);
      $fatal(1);
    end

    axi_write(SOC_GPIO_BASE_ADDR + REG_CLRGPIO, 32'h0000_0003);
    axi_check_read(SOC_GPIO_BASE_ADDR + REG_OUT0, 32'h0000_0000);

    // Select GPIO7 and verify synchronized input observation.
    gpio_in[7] = 1'b1;
    repeat (3) @(posedge clk);
    axi_write(SOC_GPIO_BASE_ADDR + REG_SETSEL, 32'h0000_0007);
    axi_check_read(SOC_GPIO_BASE_ADDR + REG_PIN0, 32'h0000_0080);
    axi_check_read(SOC_GPIO_BASE_ADDR + REG_RDSTAT, 32'h0000_1007);

    $display("tb_soc_axi_lite_apb_gpio: PASS");
    $finish;
  end

  initial begin
    #5000;
    $display("tb_soc_axi_lite_apb_gpio: TIMEOUT");
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
        $display("tb_soc_axi_lite_apb_gpio: write response error %b at %h", s_axi_bresp, addr);
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
        $display("tb_soc_axi_lite_apb_gpio: read response error %b at %h", s_axi_rresp, addr);
        $fatal(1);
      end

      if (s_axi_rdata !== exp_data) begin
        $display("tb_soc_axi_lite_apb_gpio: readback mismatch %h != %h at %h",
                 s_axi_rdata, exp_data, addr);
        $fatal(1);
      end

      while (s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

endmodule
