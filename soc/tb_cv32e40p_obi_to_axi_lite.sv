`timescale 1ns/1ps

module tb_cv32e40p_obi_to_axi_lite;

  logic        clk;
  logic        rst_n;

  logic        obi_req;
  logic        obi_we;
  logic [ 3:0] obi_be;
  logic [31:0] obi_addr;
  logic [31:0] obi_wdata;
  logic        obi_gnt;
  logic        obi_rvalid;
  logic [31:0] obi_rdata;

  logic [31:0] m_axi_awaddr;
  logic [ 2:0] m_axi_awprot;
  logic        m_axi_awvalid;
  logic        m_axi_awready;
  logic [31:0] m_axi_wdata;
  logic [ 3:0] m_axi_wstrb;
  logic        m_axi_wvalid;
  logic        m_axi_wready;
  logic [ 1:0] m_axi_bresp;
  logic        m_axi_bvalid;
  logic        m_axi_bready;
  logic [31:0] m_axi_araddr;
  logic [ 2:0] m_axi_arprot;
  logic        m_axi_arvalid;
  logic        m_axi_arready;
  logic [31:0] m_axi_rdata;
  logic [ 1:0] m_axi_rresp;
  logic        m_axi_rvalid;
  logic        m_axi_rready;

  cv32e40p_obi_to_axi_lite dut (
      .clk_i           (clk),
      .rst_ni          (rst_n),
      .obi_req_i       (obi_req),
      .obi_we_i        (obi_we),
      .obi_be_i        (obi_be),
      .obi_addr_i      (obi_addr),
      .obi_wdata_i     (obi_wdata),
      .obi_gnt_o       (obi_gnt),
      .obi_rvalid_o    (obi_rvalid),
      .obi_rdata_o     (obi_rdata),
      .m_axi_awaddr_o  (m_axi_awaddr),
      .m_axi_awprot_o  (m_axi_awprot),
      .m_axi_awvalid_o (m_axi_awvalid),
      .m_axi_awready_i (m_axi_awready),
      .m_axi_wdata_o   (m_axi_wdata),
      .m_axi_wstrb_o   (m_axi_wstrb),
      .m_axi_wvalid_o  (m_axi_wvalid),
      .m_axi_wready_i  (m_axi_wready),
      .m_axi_bresp_i   (m_axi_bresp),
      .m_axi_bvalid_i  (m_axi_bvalid),
      .m_axi_bready_o  (m_axi_bready),
      .m_axi_araddr_o  (m_axi_araddr),
      .m_axi_arprot_o  (m_axi_arprot),
      .m_axi_arvalid_o (m_axi_arvalid),
      .m_axi_arready_i (m_axi_arready),
      .m_axi_rdata_i   (m_axi_rdata),
      .m_axi_rresp_i   (m_axi_rresp),
      .m_axi_rvalid_i  (m_axi_rvalid),
      .m_axi_rready_o  (m_axi_rready)
  );

  always #5 clk = ~clk;

  task automatic reset_dut;
    begin
      clk = 1'b0;
      rst_n = 1'b0;
      obi_req = 1'b0;
      obi_we = 1'b0;
      obi_be = 4'h0;
      obi_addr = 32'h0;
      obi_wdata = 32'h0;
      m_axi_awready = 1'b0;
      m_axi_wready = 1'b0;
      m_axi_bresp = 2'b00;
      m_axi_bvalid = 1'b0;
      m_axi_arready = 1'b0;
      m_axi_rdata = 32'h0;
      m_axi_rresp = 2'b00;
      m_axi_rvalid = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
      @(posedge clk);
    end
  endtask

  task automatic check_read_path;
    begin
      obi_addr = 32'h1000_0040;
      obi_we = 1'b0;
      obi_be = 4'hf;
      obi_req = 1'b1;

      @(posedge clk);
      if (!m_axi_arvalid || m_axi_araddr != 32'h1000_0040) begin
        $display("READ address phase failed");
        $fatal(1);
      end

      m_axi_arready = 1'b1;
      @(posedge clk);
      m_axi_arready = 1'b0;
      if (!obi_gnt) begin
        $display("READ grant missing");
        $fatal(1);
      end

      obi_req = 1'b0;
      m_axi_rdata = 32'hdead_beef;
      m_axi_rvalid = 1'b1;
      @(posedge clk);
      m_axi_rvalid = 1'b0;

      if (!obi_rvalid || obi_rdata != 32'hdead_beef) begin
        $display("READ response mismatch");
        $fatal(1);
      end
    end
  endtask

  task automatic check_write_path;
    begin
      obi_addr = 32'h2000_0004;
      obi_wdata = 32'h1234_5678;
      obi_be = 4'b1100;
      obi_we = 1'b1;
      obi_req = 1'b1;

      @(posedge clk);
      if (!m_axi_awvalid || !m_axi_wvalid) begin
        $display("WRITE request phase missing");
        $fatal(1);
      end

      m_axi_awready = 1'b1;
      @(posedge clk);
      m_axi_awready = 1'b0;
      if (obi_gnt) begin
        $display("WRITE grant arrived before W channel handshake");
        $fatal(1);
      end

      m_axi_wready = 1'b1;
      @(posedge clk);
      m_axi_wready = 1'b0;
      if (!obi_gnt) begin
        $display("WRITE grant missing after AW/W handshake");
        $fatal(1);
      end

      if (m_axi_wdata != 32'h1234_5678 || m_axi_wstrb != 4'b1100) begin
        $display("WRITE payload mismatch");
        $fatal(1);
      end

      obi_req = 1'b0;
      m_axi_bvalid = 1'b1;
      @(posedge clk);
      m_axi_bvalid = 1'b0;

      if (!obi_rvalid) begin
        $display("WRITE completion missing");
        $fatal(1);
      end
    end
  endtask

  initial begin
    reset_dut();
    check_read_path();
    check_write_path();
    $display("tb_cv32e40p_obi_to_axi_lite: PASS");
    $finish;
  end

endmodule
