`timescale 1ns/1ps

module tb_gpio_icarus;

  reg clk;
  reg rst_ni;

  reg  [11:0] paddr;
  reg  [31:0] pwdata;
  reg         pwrite;
  reg         psel;
  reg         penable;
  wire [31:0] prdata;
  wire        pready;
  wire        pslverr;

  reg  [31:0] gpio_in;
  wire [31:0] gpio_in_sync;
  wire [31:0] gpio_out;
  wire [31:0] gpio_dir;
  wire [31:0] gpio_irq;

  reg [31:0] rd;
  integer i;

  localparam [11:0] REG_SETGPIO = 12'h000;
  localparam [11:0] REG_CLRGPIO = 12'h004;
  localparam [11:0] REG_TOGGPIO = 12'h008;
  localparam [11:0] REG_PIN0    = 12'h010;
  localparam [11:0] REG_OUT0    = 12'h020;
  localparam [11:0] REG_SETSEL  = 12'h030;
  localparam [11:0] REG_RDSTAT  = 12'h034;
  localparam [11:0] REG_SETDIR  = 12'h038;
  localparam [11:0] REG_SETINT  = 12'h03C;
  localparam [11:0] REG_INTACK  = 12'h040;

  soc_apb_gpio dut (
      .clk_i          (clk),
      .rst_ni         (rst_ni),
      .paddr_i        (paddr),
      .pwdata_i       (pwdata),
      .pwrite_i       (pwrite),
      .psel_i         (psel),
      .penable_i      (penable),
      .prdata_o       (prdata),
      .pready_o       (pready),
      .pslverr_o      (pslverr),
      .gpio_in_i      (gpio_in),
      .gpio_in_sync_o (gpio_in_sync),
      .gpio_out_o     (gpio_out),
      .gpio_dir_o     (gpio_dir),
      .gpio_irq_o     (gpio_irq)
  );

  always #5 clk = ~clk;

  task apb_write;
    input [11:0] addr;
    input [31:0] data;
    integer timeout_cnt;
    begin
      @(posedge clk);
      paddr   = addr;
      pwdata  = data;
      pwrite  = 1'b1;
      psel    = 1'b1;
      penable = 1'b0;
      
      @(posedge clk);
      penable = 1'b1;
      #1;
      timeout_cnt = 0;
      while (!pready) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] APB WRITE pready beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      if (pslverr) begin
        $display("[ERR] APB WRITE pslverr addr=%h data=%h", addr, data);
        $finish;
      end

      @(posedge clk);
      psel    = 1'b0;
      penable = 1'b0;
      pwrite  = 1'b0;
      paddr   = 12'h000;
      pwdata  = 32'h0000_0000;
    end
  endtask

  task apb_read;
    input  [11:0] addr;
    output [31:0] data;
    integer timeout_cnt;
    begin
      @(posedge clk);
      paddr   = addr;
      pwdata  = 32'h0000_0000;
      pwrite  = 1'b0;
      psel    = 1'b1;
      penable = 1'b0;

      @(posedge clk);
      penable = 1'b1;
      #1;
      timeout_cnt = 0;
      while (!pready) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
        if (timeout_cnt > 100) begin
          $display("[TIMEOUT] APB READ pready beklerken takildi. addr=%h", addr);
          $finish;
        end
      end

      if (pslverr) begin
        $display("[ERR] APB READ pslverr addr=%h", addr);
        $finish;
      end

      data = prdata;

      @(posedge clk);
      psel    = 1'b0;
      penable = 1'b0;
      paddr   = 12'h000;
    end
  endtask

  task gpio_set_output;
    input integer pin;
    begin
      // REG_SETDIR:
      // PWDATA[25:24] = 2'b01 normal output mode
      // PWDATA[4:0]   = pin select
      apb_write(REG_SETDIR, 32'h0100_0000 | pin[4:0]);
    end
  endtask

  initial begin
    clk = 1'b0;
  end

  initial begin
    $display("[TB] GPIO simulation started");

    $dumpfile("gpio.vcd");
    $dumpvars(0, tb_gpio_icarus);

    rst_ni  = 1'b0;
    paddr   = 12'h000;
    pwdata  = 32'h0000_0000;
    pwrite  = 1'b0;
    psel    = 1'b0;
    penable = 1'b0;
    gpio_in = 32'h0000_0000;

    repeat (5) @(posedge clk);
    rst_ni = 1'b1;
    repeat (5) @(posedge clk);

    $display("---- GPIO TEST BASLADI ----");

    gpio_in = 32'h0000_00A5;

    // GPIO input iki senkron flop üzerinden geliyor.
    repeat (6) @(posedge clk);

    apb_read(REG_PIN0, rd);
    $display("PIN0 = %h", rd);

    if (rd[7:0] !== 8'hA5) begin
      $display("[FAIL] PIN0 beklenen 0xA5 degil. rd=%h", rd);
      $finish;
    end

    // İlk 8 pini output yap.
    for (i = 0; i < 8; i = i + 1) begin
      gpio_set_output(i);
    end

    repeat (2) @(posedge clk);
    $display("gpio_dir = %h", gpio_dir);

    if (gpio_dir[7:0] !== 8'hFF) begin
      $display("[FAIL] gpio_dir[7:0] beklenen 0xFF degil. gpio_dir=%h", gpio_dir);
      $finish;
    end

    // Tüm output registerını yaz.
    apb_write(REG_OUT0, 32'h0000_005A);

    repeat (2) @(posedge clk);
    $display("gpio_out = %h", gpio_out);

    if (gpio_out[7:0] !== 8'h5A) begin
      $display("[FAIL] gpio_out[7:0] beklenen 0x5A degil. gpio_out=%h", gpio_out);
      $finish;
    end

    // SETGPIO pin index ile tek bit set ediyor.
    apb_write(REG_SETGPIO, 32'd0);
    apb_write(REG_SETGPIO, 32'd2);

    repeat (2) @(posedge clk);
    $display("gpio_out after SETGPIO = %h", gpio_out);

    if (gpio_out[7:0] !== 8'h5F) begin
      $display("[FAIL] SETGPIO sonrasi beklenen 0x5F degil. gpio_out=%h", gpio_out);
      $finish;
    end

    // CLRGPIO pin index ile tek bit clear ediyor.
    apb_write(REG_CLRGPIO, 32'd0);
    apb_write(REG_CLRGPIO, 32'd1);
    apb_write(REG_CLRGPIO, 32'd2);
    apb_write(REG_CLRGPIO, 32'd3);

    repeat (2) @(posedge clk);
    $display("gpio_out after CLRGPIO = %h", gpio_out);

    if (gpio_out[7:0] !== 8'h50) begin
      $display("[FAIL] CLRGPIO sonrasi beklenen 0x50 degil. gpio_out=%h", gpio_out);
      $finish;
    end

    apb_read(REG_OUT0, rd);
    $display("OUT0 readback = %h", rd);

    if (rd[7:0] !== 8'h50) begin
      $display("[FAIL] OUT0 readback beklenen 0x50 degil. rd=%h", rd);
      $finish;
    end

    $display("---- GPIO TEST PASS ----");
    $finish;
  end

  initial begin
    #2000000;
    $display("[TIMEOUT] GPIO simulasyonu 2 ms icinde bitmedi.");
    $finish;
  end

endmodule
