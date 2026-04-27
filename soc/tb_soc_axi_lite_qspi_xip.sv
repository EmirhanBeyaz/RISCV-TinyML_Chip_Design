module tb_soc_axi_lite_qspi_xip;

  localparam logic [31:0] XIP_BASE_ADDR = 32'h3000_0000;

  logic        clk;
  logic        rst_n;

  logic [31:0] s_axi_awaddr;
  logic [2:0]  s_axi_awprot;
  logic        s_axi_awvalid;
  logic        s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [3:0]  s_axi_wstrb;
  logic        s_axi_wvalid;
  logic        s_axi_wready;
  logic [1:0]  s_axi_bresp;
  logic        s_axi_bvalid;
  logic        s_axi_bready;
  logic [31:0] s_axi_araddr;
  logic [2:0]  s_axi_arprot;
  logic        s_axi_arvalid;
  logic        s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [1:0]  s_axi_rresp;
  logic        s_axi_rvalid;
  logic        s_axi_rready;

  logic        cfg_cmd_valid;
  logic [31:0] cfg_cmd_data;
  logic        cfg_cmd_ready;
  logic        cfg_rsp_valid;
  logic [31:0] cfg_rsp_data;
  logic        flash_busy;
  logic        flash_init_done;
  logic        qspi_cs_n;
  logic        qspi_sck;
  logic [1:0]  qspi_mod;
  logic [3:0]  qspi_dat_o;
  logic [3:0]  qspi_dat_i;

  soc_axi_lite_qspi_xip #(
      .XIP_BASE_ADDR(XIP_BASE_ADDR),
      .OPT_STARTUP  (1'b0)
  ) dut (
      .clk_i            (clk),
      .rst_ni           (rst_n),
      .s_axi_awaddr_i   (s_axi_awaddr),
      .s_axi_awprot_i   (s_axi_awprot),
      .s_axi_awvalid_i  (s_axi_awvalid),
      .s_axi_awready_o  (s_axi_awready),
      .s_axi_wdata_i    (s_axi_wdata),
      .s_axi_wstrb_i    (s_axi_wstrb),
      .s_axi_wvalid_i   (s_axi_wvalid),
      .s_axi_wready_o   (s_axi_wready),
      .s_axi_bresp_o    (s_axi_bresp),
      .s_axi_bvalid_o   (s_axi_bvalid),
      .s_axi_bready_i   (s_axi_bready),
      .s_axi_araddr_i   (s_axi_araddr),
      .s_axi_arprot_i   (s_axi_arprot),
      .s_axi_arvalid_i  (s_axi_arvalid),
      .s_axi_arready_o  (s_axi_arready),
      .s_axi_rdata_o    (s_axi_rdata),
      .s_axi_rresp_o    (s_axi_rresp),
      .s_axi_rvalid_o   (s_axi_rvalid),
      .s_axi_rready_i   (s_axi_rready),
      .cfg_cmd_valid_i  (cfg_cmd_valid),
      .cfg_cmd_data_i   (cfg_cmd_data),
      .cfg_cmd_ready_o  (cfg_cmd_ready),
      .cfg_rsp_valid_o  (cfg_rsp_valid),
      .cfg_rsp_data_o   (cfg_rsp_data),
      .flash_busy_o     (flash_busy),
      .flash_init_done_o(flash_init_done),
      .qspi_cs_n_o      (qspi_cs_n),
      .qspi_sck_o       (qspi_sck),
      .qspi_mod_o       (qspi_mod),
      .qspi_dat_o       (qspi_dat_o),
      .qspi_dat_i       (qspi_dat_i)
  );

  always #5 clk = ~clk;

  task automatic axi_read(input logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
    int timeout;
    begin
      s_axi_araddr  = addr;
      s_axi_arprot  = 3'b000;
      s_axi_arvalid = 1'b1;
      s_axi_rready  = 1'b1;
      timeout = 0;

      while (!s_axi_arready) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI read address handshake timeout");
        end
      end

      @(posedge clk);
      s_axi_arvalid = 1'b0;

      timeout = 0;
      while (!s_axi_rvalid) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 5000) begin
          $fatal(1, "AXI read data timeout");
        end
      end

      data = s_axi_rdata;
      resp = s_axi_rresp;
      @(posedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

  task automatic axi_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic [1:0] resp);
    int timeout;
    begin
      s_axi_awaddr  = addr;
      s_axi_awprot  = 3'b000;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = strb;
      s_axi_wvalid  = 1'b1;
      s_axi_bready  = 1'b1;

      timeout = 0;
      while (!(s_axi_awready && s_axi_wready)) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI write handshake timeout");
        end
      end

      @(posedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      timeout = 0;
      while (!s_axi_bvalid) begin
        @(posedge clk);
        timeout += 1;
        if (timeout > 50) begin
          $fatal(1, "AXI write response timeout");
        end
      end

      resp = s_axi_bresp;
      @(posedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  logic [31:0] read_data;
  logic [1:0]  read_resp;
  logic [1:0]  write_resp;

  initial begin
    clk           = 1'b0;
    rst_n         = 1'b0;
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
    cfg_cmd_valid = 1'b0;
    cfg_cmd_data  = '0;
    qspi_dat_i    = 4'h0;

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    axi_read(XIP_BASE_ADDR + 32'h10, read_data, read_resp);
    if (read_resp != 2'b00) begin
      $fatal(1, "Expected successful XIP read, got resp=%b", read_resp);
    end
    if (read_data != 32'h0000_0000) begin
      $fatal(1, "Expected zeroed flash data with tied-low qspi_dat_i, got %h", read_data);
    end

    axi_read(32'h4000_0000, read_data, read_resp);
    if (read_resp != 2'b10) begin
      $fatal(1, "Expected SLVERR on out-of-window read, got %b", read_resp);
    end

    axi_write(XIP_BASE_ADDR + 32'h20, 32'hDEAD_BEEF, 4'hF, write_resp);
    if (write_resp != 2'b10) begin
      $fatal(1, "Expected SLVERR on XIP write, got %b", write_resp);
    end

    $display("PASS: soc_axi_lite_qspi_xip smoke test passed");
    $finish;
  end

endmodule
