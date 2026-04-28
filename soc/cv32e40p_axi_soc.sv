module cv32e40p_axi_soc #(
    parameter bit COREV_PULP = 0,
    parameter bit COREV_CLUSTER = 0,
    parameter bit FPU = 0,
    parameter int FPU_ADDMUL_LAT = 0,
    parameter int FPU_OTHERS_LAT = 0,
    parameter bit ZFINX = 0,
    parameter int NUM_MHPMCOUNTERS = 1,
    parameter string ROM_INIT_FILE = "",
    parameter string IMEM_INIT_FILE = "",
    parameter bit QSPI_SIM_XIP_ENABLE = 1'b0,
    parameter string QSPI_SIM_XIP_INIT_FILE = "",
    parameter int QSPI_SIM_XIP_DEPTH_WORDS = 256,
    parameter bit BOOT_COPY_XIP_ENABLE = 1'b0,
    parameter bit QSPI_INIT_ENABLE = 1'b1,
    parameter int BOOT_COPY_WORDS = 2048
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        fetch_enable_i,
    input  logic        pulp_clock_en_i,
    input  logic        scan_cg_en_i,
    input  logic [31:0] boot_addr_i,
    input  logic [31:0] mtvec_addr_i,
    input  logic [31:0] dm_halt_addr_i,
    input  logic [31:0] hart_id_i,
    input  logic [31:0] dm_exception_addr_i,

    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    input  logic        instr_rvalid_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,

    input  logic [31:0] irq_i,
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    input  logic debug_req_i,
    output logic debug_havereset_o,
    output logic debug_running_o,
    output logic debug_halted_o,
    output logic core_sleep_o,

    input  logic uart0_rx_i,
    output logic uart0_tx_o,
    input  logic uart1_rx_i,
    output logic uart1_tx_o,
    input  logic [31:0] gpio_in_i,
    output logic [31:0] gpio_out_o,
    output logic [31:0] gpio_dir_o,
    output logic [31:0] gpio_irq_o,
    input  logic        timer_ref_clk_i,
    input  logic        timer_stoptimer_i,
    input  logic        timer_event_lo_i,
    input  logic        timer_event_hi_i,
    output logic        timer_irq_lo_o,
    output logic        timer_irq_hi_o,
    output logic        timer_busy_o,
    input  logic        i2c_sda_i,
    output logic        i2c_scl_o,
    output logic        i2c_scl_oe_o,
    output logic        i2c_sda_o,
    output logic        i2c_sda_oe_o,
    output logic        qspi_cs_n_o,
    output logic        qspi_sck_o,
    output logic [ 1:0] qspi_mod_o,
    output logic [ 3:0] qspi_dat_o,
    input  logic [ 3:0] qspi_dat_i,

    output logic [31:0] m_axi_awaddr_o,
    output logic [ 2:0] m_axi_awprot_o,
    output logic        m_axi_awvalid_o,
    input  logic        m_axi_awready_i,
    output logic [31:0] m_axi_wdata_o,
    output logic [ 3:0] m_axi_wstrb_o,
    output logic        m_axi_wvalid_o,
    input  logic        m_axi_wready_i,
    input  logic [ 1:0] m_axi_bresp_i,
    input  logic        m_axi_bvalid_i,
    output logic        m_axi_bready_o,
    output logic [31:0] m_axi_araddr_o,
    output logic [ 2:0] m_axi_arprot_o,
    output logic        m_axi_arvalid_o,
    input  logic        m_axi_arready_i,
    input  logic [31:0] m_axi_rdata_i,
    input  logic [ 1:0] m_axi_rresp_i,
    input  logic        m_axi_rvalid_i,
    output logic        m_axi_rready_o
);

  import soc_map_pkg::*;
  localparam logic [31:0] MMIO_WINDOW_BYTES = SOC_MMIO_SLOT_COUNT * SOC_MMIO_SLOT_BYTES;
  localparam int NO_APB_SLOTS = SOC_MMIO_SLOT_COUNT;
  localparam int INSTR_TRACK_DEPTH = 8;
  localparam int INSTR_TRACK_W = (INSTR_TRACK_DEPTH > 1) ? $clog2(INSTR_TRACK_DEPTH + 1) : 1;
  typedef enum logic [1:0] {
    INSTR_SRC_EXT  = 2'b00,
    INSTR_SRC_ROM  = 2'b01,
    INSTR_SRC_IMEM = 2'b10
  } instr_src_e;

  function automatic bit addr_in_rom_window(input logic [31:0] addr);
    logic [32:0] end_addr;
    begin
      end_addr = {1'b0, SOC_ROM_BASE_ADDR} + {1'b0, SOC_ROM_IMPL_BYTES};
      return {1'b0, addr} < end_addr;
    end
  endfunction

  function automatic bit addr_in_imem_window(input logic [31:0] addr);
    logic [32:0] end_addr;
    begin
      end_addr = {1'b0, SOC_IMEM_BASE_ADDR} + {1'b0, SOC_IMEM_IMPL_BYTES};
      return ({1'b0, addr} >= {1'b0, SOC_IMEM_BASE_ADDR}) &&
             ({1'b0, addr} < end_addr);
    end
  endfunction

  logic        core_instr_req;
  logic        core_instr_gnt;
  logic        core_instr_rvalid;
  logic [31:0] core_instr_addr;
  logic [31:0] core_instr_rdata;
  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [ 3:0] data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;
  logic [31:0] local_irq;
  logic [31:0] core_irq;
  logic        rom_instr_req;
  logic        rom_instr_gnt;
  logic        rom_instr_rvalid;
  logic [31:0] rom_instr_rdata;
  logic        imem_instr_req;
  logic        imem_instr_gnt;
  logic        imem_instr_rvalid;
  logic [31:0] imem_instr_rdata;
  logic        imem_data_req;
  logic        imem_data_gnt;
  logic        imem_data_rvalid;
  logic        imem_data_we;
  logic [ 3:0] imem_data_be;
  logic [31:0] imem_data_addr;
  logic [31:0] imem_data_wdata;
  logic [31:0] imem_data_rdata;
  logic        imem_boot_req;
  logic        imem_boot_we;
  logic [ 3:0] imem_boot_be;
  logic [31:0] imem_boot_addr;
  logic [31:0] imem_boot_wdata;
  logic        imem_boot_gnt;
  logic        qspi_boot_ready;
  instr_src_e  instr_req_src;
  logic        instr_can_accept;
  logic        instr_push;
  logic        instr_pop;
  instr_src_e  instr_src_q;
  logic [INSTR_TRACK_W-1:0] instr_outstanding_q;
  logic        boot_active;
  logic        boot_done;
  logic        core_rst_ni;

  logic [31:0] bridge_axi_awaddr;
  logic [ 2:0] bridge_axi_awprot;
  logic        bridge_axi_awvalid;
  logic        bridge_axi_awready;
  logic [31:0] bridge_axi_wdata;
  logic [ 3:0] bridge_axi_wstrb;
  logic        bridge_axi_wvalid;
  logic        bridge_axi_wready;
  logic [ 1:0] bridge_axi_bresp;
  logic        bridge_axi_bvalid;
  logic        bridge_axi_bready;
  logic [31:0] bridge_axi_araddr;
  logic [ 2:0] bridge_axi_arprot;
  logic        bridge_axi_arvalid;
  logic        bridge_axi_arready;
  logic [31:0] bridge_axi_rdata;
  logic [ 1:0] bridge_axi_rresp;
  logic        bridge_axi_rvalid;
  logic        bridge_axi_rready;

  logic [31:0] boot_axi_awaddr;
  logic [ 2:0] boot_axi_awprot;
  logic        boot_axi_awvalid;
  logic        boot_axi_awready;
  logic [31:0] boot_axi_wdata;
  logic [ 3:0] boot_axi_wstrb;
  logic        boot_axi_wvalid;
  logic        boot_axi_wready;
  logic [ 1:0] boot_axi_bresp;
  logic        boot_axi_bvalid;
  logic        boot_axi_bready;
  logic [31:0] boot_axi_araddr;
  logic [ 2:0] boot_axi_arprot;
  logic        boot_axi_arvalid;
  logic        boot_axi_arready;
  logic [31:0] boot_axi_rdata;
  logic [ 1:0] boot_axi_rresp;
  logic        boot_axi_rvalid;
  logic        boot_axi_rready;

  logic [31:0] fabric_axi_awaddr;
  logic [ 2:0] fabric_axi_awprot;
  logic        fabric_axi_awvalid;
  logic        fabric_axi_awready;
  logic [31:0] fabric_axi_wdata;
  logic [ 3:0] fabric_axi_wstrb;
  logic        fabric_axi_wvalid;
  logic        fabric_axi_wready;
  logic [ 1:0] fabric_axi_bresp;
  logic        fabric_axi_bvalid;
  logic        fabric_axi_bready;
  logic [31:0] fabric_axi_araddr;
  logic [ 2:0] fabric_axi_arprot;
  logic        fabric_axi_arvalid;
  logic        fabric_axi_arready;
  logic [31:0] fabric_axi_rdata;
  logic [ 1:0] fabric_axi_rresp;
  logic        fabric_axi_rvalid;
  logic        fabric_axi_rready;

  logic [31:0] mmio_axi_awaddr;
  logic [ 2:0] mmio_axi_awprot;
  logic        mmio_axi_awvalid;
  logic        mmio_axi_awready;
  logic [31:0] mmio_axi_wdata;
  logic [ 3:0] mmio_axi_wstrb;
  logic        mmio_axi_wvalid;
  logic        mmio_axi_wready;
  logic [ 1:0] mmio_axi_bresp;
  logic        mmio_axi_bvalid;
  logic        mmio_axi_bready;
  logic [31:0] mmio_axi_araddr;
  logic [ 2:0] mmio_axi_arprot;
  logic        mmio_axi_arvalid;
  logic        mmio_axi_arready;
  logic [31:0] mmio_axi_rdata;
  logic [ 1:0] mmio_axi_rresp;
  logic        mmio_axi_rvalid;
  logic        mmio_axi_rready;

  logic [31:0] dmem_axi_awaddr;
  logic [ 2:0] dmem_axi_awprot;
  logic        dmem_axi_awvalid;
  logic        dmem_axi_awready;
  logic [31:0] dmem_axi_wdata;
  logic [ 3:0] dmem_axi_wstrb;
  logic        dmem_axi_wvalid;
  logic        dmem_axi_wready;
  logic [ 1:0] dmem_axi_bresp;
  logic        dmem_axi_bvalid;
  logic        dmem_axi_bready;
  logic [31:0] dmem_axi_araddr;
  logic [ 2:0] dmem_axi_arprot;
  logic        dmem_axi_arvalid;
  logic        dmem_axi_arready;
  logic [31:0] dmem_axi_rdata;
  logic [ 1:0] dmem_axi_rresp;
  logic        dmem_axi_rvalid;
  logic        dmem_axi_rready;

  logic [31:0] pre_dmem_axi_awaddr;
  logic [ 2:0] pre_dmem_axi_awprot;
  logic        pre_dmem_axi_awvalid;
  logic        pre_dmem_axi_awready;
  logic [31:0] pre_dmem_axi_wdata;
  logic [ 3:0] pre_dmem_axi_wstrb;
  logic        pre_dmem_axi_wvalid;
  logic        pre_dmem_axi_wready;
  logic [ 1:0] pre_dmem_axi_bresp;
  logic        pre_dmem_axi_bvalid;
  logic        pre_dmem_axi_bready;
  logic [31:0] pre_dmem_axi_araddr;
  logic [ 2:0] pre_dmem_axi_arprot;
  logic        pre_dmem_axi_arvalid;
  logic        pre_dmem_axi_arready;
  logic [31:0] pre_dmem_axi_rdata;
  logic [ 1:0] pre_dmem_axi_rresp;
  logic        pre_dmem_axi_rvalid;
  logic        pre_dmem_axi_rready;

  logic [31:0] imem_axi_awaddr;
  logic [ 2:0] imem_axi_awprot;
  logic        imem_axi_awvalid;
  logic        imem_axi_awready;
  logic [31:0] imem_axi_wdata;
  logic [ 3:0] imem_axi_wstrb;
  logic        imem_axi_wvalid;
  logic        imem_axi_wready;
  logic [ 1:0] imem_axi_bresp;
  logic        imem_axi_bvalid;
  logic        imem_axi_bready;
  logic [31:0] imem_axi_araddr;
  logic [ 2:0] imem_axi_arprot;
  logic        imem_axi_arvalid;
  logic        imem_axi_arready;
  logic [31:0] imem_axi_rdata;
  logic [ 1:0] imem_axi_rresp;
  logic        imem_axi_rvalid;
  logic        imem_axi_rready;

  logic [31:0] sys_axi_awaddr;
  logic [ 2:0] sys_axi_awprot;
  logic        sys_axi_awvalid;
  logic        sys_axi_awready;
  logic [31:0] sys_axi_wdata;
  logic [ 3:0] sys_axi_wstrb;
  logic        sys_axi_wvalid;
  logic        sys_axi_wready;
  logic [ 1:0] sys_axi_bresp;
  logic        sys_axi_bvalid;
  logic        sys_axi_bready;
  logic [31:0] sys_axi_araddr;
  logic [ 2:0] sys_axi_arprot;
  logic        sys_axi_arvalid;
  logic        sys_axi_arready;
  logic [31:0] sys_axi_rdata;
  logic [ 1:0] sys_axi_rresp;
  logic        sys_axi_rvalid;
  logic        sys_axi_rready;

  logic [31:0] ext_axi_awaddr;
  logic [ 2:0] ext_axi_awprot;
  logic        ext_axi_awvalid;
  logic        ext_axi_awready;
  logic [31:0] ext_axi_wdata;
  logic [ 3:0] ext_axi_wstrb;
  logic        ext_axi_wvalid;
  logic        ext_axi_wready;
  logic [ 1:0] ext_axi_bresp;
  logic        ext_axi_bvalid;
  logic        ext_axi_bready;
  logic [31:0] ext_axi_araddr;
  logic [ 2:0] ext_axi_arprot;
  logic        ext_axi_arvalid;
  logic        ext_axi_arready;
  logic [31:0] ext_axi_rdata;
  logic [ 1:0] ext_axi_rresp;
  logic        ext_axi_rvalid;
  logic        ext_axi_rready;

  logic [31:0] pre_qspi_axi_awaddr;
  logic [ 2:0] pre_qspi_axi_awprot;
  logic        pre_qspi_axi_awvalid;
  logic        pre_qspi_axi_awready;
  logic [31:0] pre_qspi_axi_wdata;
  logic [ 3:0] pre_qspi_axi_wstrb;
  logic        pre_qspi_axi_wvalid;
  logic        pre_qspi_axi_wready;
  logic [ 1:0] pre_qspi_axi_bresp;
  logic        pre_qspi_axi_bvalid;
  logic        pre_qspi_axi_bready;
  logic [31:0] pre_qspi_axi_araddr;
  logic [ 2:0] pre_qspi_axi_arprot;
  logic        pre_qspi_axi_arvalid;
  logic        pre_qspi_axi_arready;
  logic [31:0] pre_qspi_axi_rdata;
  logic [ 1:0] pre_qspi_axi_rresp;
  logic        pre_qspi_axi_rvalid;
  logic        pre_qspi_axi_rready;

  logic [31:0] ai_mem_axi_awaddr;
  logic [ 2:0] ai_mem_axi_awprot;
  logic        ai_mem_axi_awvalid;
  logic        ai_mem_axi_awready;
  logic [31:0] ai_mem_axi_wdata;
  logic [ 3:0] ai_mem_axi_wstrb;
  logic        ai_mem_axi_wvalid;
  logic        ai_mem_axi_wready;
  logic [ 1:0] ai_mem_axi_bresp;
  logic        ai_mem_axi_bvalid;
  logic        ai_mem_axi_bready;
  logic [31:0] ai_mem_axi_araddr;
  logic [ 2:0] ai_mem_axi_arprot;
  logic        ai_mem_axi_arvalid;
  logic        ai_mem_axi_arready;
  logic [31:0] ai_mem_axi_rdata;
  logic [ 1:0] ai_mem_axi_rresp;
  logic        ai_mem_axi_rvalid;
  logic        ai_mem_axi_rready;

  logic [31:0] qspi_xip_axi_awaddr;
  logic [ 2:0] qspi_xip_axi_awprot;
  logic        qspi_xip_axi_awvalid;
  logic        qspi_xip_axi_awready;
  logic [31:0] qspi_xip_axi_wdata;
  logic [ 3:0] qspi_xip_axi_wstrb;
  logic        qspi_xip_axi_wvalid;
  logic        qspi_xip_axi_wready;
  logic [ 1:0] qspi_xip_axi_bresp;
  logic        qspi_xip_axi_bvalid;
  logic        qspi_xip_axi_bready;
  logic [31:0] qspi_xip_axi_araddr;
  logic [ 2:0] qspi_xip_axi_arprot;
  logic        qspi_xip_axi_arvalid;
  logic        qspi_xip_axi_arready;
  logic [31:0] qspi_xip_axi_rdata;
  logic [ 1:0] qspi_xip_axi_rresp;
  logic        qspi_xip_axi_rvalid;
  logic        qspi_xip_axi_rready;
  logic        qspi_flash_busy;
  logic        qspi_flash_init_done;
  logic        qspi_cfg_cmd_valid;
  logic [31:0] qspi_cfg_cmd_data;
  logic        qspi_cfg_cmd_ready;
  logic        qspi_cfg_rsp_valid;
  logic [31:0] qspi_cfg_rsp_data;
  logic        qspi_sw_cmd_valid;
  logic [31:0] qspi_sw_cmd_data;
  logic        qspi_init_cmd_valid;
  logic [31:0] qspi_init_cmd_data;
  logic        qspi_init_cmd_ready;
  logic        qspi_init_rsp_valid;
  logic [31:0] qspi_init_rsp_data;
  logic        qspi_sw_cmd_ready;
  logic        qspi_sw_rsp_valid;
  logic [31:0] qspi_sw_rsp_data;
  logic        qspi_init_active;
  logic        qspi_init_done;
  logic        qspi_init_error;
  logic [31:0] qspi_init_last_rsp;
  logic [31:0] qspi_init_last_cmd;
  logic [31:0] qspi_init_step;
  logic [31:0] qspi_init_error_code;

  logic [31:0] uart0_axi_awaddr;
  logic [ 2:0] uart0_axi_awprot;
  logic        uart0_axi_awvalid;
  logic        uart0_axi_awready;
  logic [31:0] uart0_axi_wdata;
  logic [ 3:0] uart0_axi_wstrb;
  logic        uart0_axi_wvalid;
  logic        uart0_axi_wready;
  logic [ 1:0] uart0_axi_bresp;
  logic        uart0_axi_bvalid;
  logic        uart0_axi_bready;
  logic [31:0] uart0_axi_araddr;
  logic [ 2:0] uart0_axi_arprot;
  logic        uart0_axi_arvalid;
  logic        uart0_axi_arready;
  logic [31:0] uart0_axi_rdata;
  logic [ 1:0] uart0_axi_rresp;
  logic        uart0_axi_rvalid;
  logic        uart0_axi_rready;

  logic [31:0] uart1_mux_axi_awaddr;
  logic [ 2:0] uart1_mux_axi_awprot;
  logic        uart1_mux_axi_awvalid;
  logic        uart1_mux_axi_awready;
  logic [31:0] uart1_mux_axi_wdata;
  logic [ 3:0] uart1_mux_axi_wstrb;
  logic        uart1_mux_axi_wvalid;
  logic        uart1_mux_axi_wready;
  logic [ 1:0] uart1_mux_axi_bresp;
  logic        uart1_mux_axi_bvalid;
  logic        uart1_mux_axi_bready;
  logic [31:0] uart1_mux_axi_araddr;
  logic [ 2:0] uart1_mux_axi_arprot;
  logic        uart1_mux_axi_arvalid;
  logic        uart1_mux_axi_arready;
  logic [31:0] uart1_mux_axi_rdata;
  logic [ 1:0] uart1_mux_axi_rresp;
  logic        uart1_mux_axi_rvalid;
  logic        uart1_mux_axi_rready;

  logic [31:0] uart1_axi_awaddr;
  logic [ 2:0] uart1_axi_awprot;
  logic        uart1_axi_awvalid;
  logic        uart1_axi_awready;
  logic [31:0] uart1_axi_wdata;
  logic [ 3:0] uart1_axi_wstrb;
  logic        uart1_axi_wvalid;
  logic        uart1_axi_wready;
  logic [ 1:0] uart1_axi_bresp;
  logic        uart1_axi_bvalid;
  logic        uart1_axi_bready;
  logic [31:0] uart1_axi_araddr;
  logic [ 2:0] uart1_axi_arprot;
  logic        uart1_axi_arvalid;
  logic        uart1_axi_arready;
  logic [31:0] uart1_axi_rdata;
  logic [ 1:0] uart1_axi_rresp;
  logic        uart1_axi_rvalid;
  logic        uart1_axi_rready;

  logic [31:0] ai_csr_mux_axi_awaddr;
  logic [ 2:0] ai_csr_mux_axi_awprot;
  logic        ai_csr_mux_axi_awvalid;
  logic        ai_csr_mux_axi_awready;
  logic [31:0] ai_csr_mux_axi_wdata;
  logic [ 3:0] ai_csr_mux_axi_wstrb;
  logic        ai_csr_mux_axi_wvalid;
  logic        ai_csr_mux_axi_wready;
  logic [ 1:0] ai_csr_mux_axi_bresp;
  logic        ai_csr_mux_axi_bvalid;
  logic        ai_csr_mux_axi_bready;
  logic [31:0] ai_csr_mux_axi_araddr;
  logic [ 2:0] ai_csr_mux_axi_arprot;
  logic        ai_csr_mux_axi_arvalid;
  logic        ai_csr_mux_axi_arready;
  logic [31:0] ai_csr_mux_axi_rdata;
  logic [ 1:0] ai_csr_mux_axi_rresp;
  logic        ai_csr_mux_axi_rvalid;
  logic        ai_csr_mux_axi_rready;

  logic [31:0] ai_csr_axi_awaddr;
  logic [ 2:0] ai_csr_axi_awprot;
  logic        ai_csr_axi_awvalid;
  logic        ai_csr_axi_awready;
  logic [31:0] ai_csr_axi_wdata;
  logic [ 3:0] ai_csr_axi_wstrb;
  logic        ai_csr_axi_wvalid;
  logic        ai_csr_axi_wready;
  logic [ 1:0] ai_csr_axi_bresp;
  logic        ai_csr_axi_bvalid;
  logic        ai_csr_axi_bready;
  logic [31:0] ai_csr_axi_araddr;
  logic [ 2:0] ai_csr_axi_arprot;
  logic        ai_csr_axi_arvalid;
  logic        ai_csr_axi_arready;
  logic [31:0] ai_csr_axi_rdata;
  logic [ 1:0] ai_csr_axi_rresp;
  logic        ai_csr_axi_rvalid;
  logic        ai_csr_axi_rready;

  logic [31:0] apb_axi_awaddr;
  logic [ 2:0] apb_axi_awprot;
  logic        apb_axi_awvalid;
  logic        apb_axi_awready;
  logic [31:0] apb_axi_wdata;
  logic [ 3:0] apb_axi_wstrb;
  logic        apb_axi_wvalid;
  logic        apb_axi_wready;
  logic [ 1:0] apb_axi_bresp;
  logic        apb_axi_bvalid;
  logic        apb_axi_bready;
  logic [31:0] apb_axi_araddr;
  logic [ 2:0] apb_axi_arprot;
  logic        apb_axi_arvalid;
  logic        apb_axi_arready;
  logic [31:0] apb_axi_rdata;
  logic [ 1:0] apb_axi_rresp;
  logic        apb_axi_rvalid;
  logic        apb_axi_rready;

  logic [31:0] apb_paddr;
  logic [ 2:0] apb_pprot;
  logic        apb_penable;
  logic        apb_pwrite;
  logic [31:0] apb_pwdata;
  logic [NO_APB_SLOTS-1:0] apb_psel;
  logic [NO_APB_SLOTS-1:0][31:0] apb_prdata;
  logic [NO_APB_SLOTS-1:0] apb_pready;
  logic [NO_APB_SLOTS-1:0] apb_pslverr;

  logic [31:0] qspi_cfg_prdata;
  logic        qspi_cfg_pready;
  logic        qspi_cfg_pslverr;
  logic [31:0] gpio_prdata;
  logic        gpio_pready;
  logic        gpio_pslverr;
  logic [31:0] gpio_in_sync;
  logic [31:0] timer_prdata;
  logic        timer_pready;
  logic        timer_pslverr;
  logic [31:0] i2c_prdata;
  logic        i2c_pready;
  logic        i2c_pslverr;
  logic        ai_irq;
  logic        ai_accel_start;
  logic        ai_uart_start;
  logic [31:0] ai_input_base;
  logic [31:0] ai_input_len;
  logic [31:0] ai_output_base;
  logic [15:0] ai_uart_baud_div;
  logic        ai_accel_busy;
  logic        ai_accel_done;
  logic [ 1:0] ai_result_class;
  logic signed [31:0] ai_result0;
  logic signed [31:0] ai_result1;
  logic signed [31:0] ai_result2;
  logic signed [31:0] ai_result3;
  logic [31:0] ai_cycle_count;
  logic        ai_uart_active;
  logic        ai_uart_done;
  logic        ai_uart_error;
  logic [31:0] ai_uart_byte_count;
  logic        ai_mem_int_req;
  logic        ai_mem_int_we;
  logic [ 3:0] ai_mem_int_be;
  logic [31:0] ai_mem_int_addr;
  logic [31:0] ai_mem_int_wdata;
  logic        ai_mem_int_gnt;
  logic        ai_mem_int_rvalid;
  logic [31:0] ai_mem_int_rdata;
  logic        ai_uart_mem_req;
  logic        ai_uart_mem_we;
  logic [ 3:0] ai_uart_mem_be;
  logic [31:0] ai_uart_mem_addr;
  logic [31:0] ai_uart_mem_wdata;
  logic        ai_uart_mem_gnt;
  logic        ai_accel_mem_req;
  logic        ai_accel_mem_we;
  logic [ 3:0] ai_accel_mem_be;
  logic [31:0] ai_accel_mem_addr;
  logic [31:0] ai_accel_mem_wdata;
  logic        ai_accel_mem_gnt;
  logic        ai_accel_mem_rvalid;
  logic [31:0] ai_accel_mem_rdata;
  logic        ai_mem_rsp_accel_q;
  integer      apb_idx;

  soc_irq_router irq_router_i (
      .ext_irq_i      (irq_i),
      .gpio_irq_i     (gpio_irq_o),
      .timer_irq_lo_i (timer_irq_lo_o),
      .timer_irq_hi_i (timer_irq_hi_o),
      .uart0_irq_i    (1'b0),
      .uart1_irq_i    (1'b0),
      .ai_irq_i       (ai_irq),
      .local_irq_o    (local_irq),
      .core_irq_o     (core_irq)
  );

  assign qspi_boot_ready = !QSPI_INIT_ENABLE || qspi_init_done;
  assign core_rst_ni = rst_ni && qspi_boot_ready && boot_done;

  assign instr_req_src = addr_in_rom_window(core_instr_addr)  ? INSTR_SRC_ROM  :
                         addr_in_imem_window(core_instr_addr) ? INSTR_SRC_IMEM :
                                                                INSTR_SRC_EXT;
  assign instr_can_accept = (instr_outstanding_q < INSTR_TRACK_DEPTH) &&
                            ((instr_outstanding_q == '0) ||
                             (instr_req_src == instr_src_q));
  assign rom_instr_req  = core_instr_req && (instr_req_src == INSTR_SRC_ROM)  && instr_can_accept;
  assign imem_instr_req = core_instr_req && (instr_req_src == INSTR_SRC_IMEM) && instr_can_accept;
  assign instr_req_o    = core_instr_req && (instr_req_src == INSTR_SRC_EXT)  && instr_can_accept;
  assign instr_addr_o = core_instr_addr;
  assign core_instr_gnt = (instr_req_src == INSTR_SRC_ROM)  ? (rom_instr_gnt  && instr_can_accept) :
                          (instr_req_src == INSTR_SRC_IMEM) ? (imem_instr_gnt && instr_can_accept) :
                                                               (instr_gnt_i    && instr_can_accept);
  assign core_instr_rvalid = (instr_outstanding_q != '0) &&
                             ((instr_src_q == INSTR_SRC_ROM)  ? rom_instr_rvalid  :
                              (instr_src_q == INSTR_SRC_IMEM) ? imem_instr_rvalid :
                                                                 instr_rvalid_i);
  assign core_instr_rdata = (instr_src_q == INSTR_SRC_ROM)  ? rom_instr_rdata  :
                            (instr_src_q == INSTR_SRC_IMEM) ? imem_instr_rdata :
                                                               instr_rdata_i;
  assign instr_push = core_instr_req && core_instr_gnt;
  assign instr_pop  = core_instr_rvalid;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_src_q        <= INSTR_SRC_EXT;
      instr_outstanding_q <= '0;
    end else begin
      if (instr_push && (instr_outstanding_q == '0)) begin
        instr_src_q <= instr_req_src;
      end

      unique case ({instr_push, instr_pop})
        2'b10: instr_outstanding_q <= instr_outstanding_q + 1'b1;
        2'b01: instr_outstanding_q <= instr_outstanding_q - 1'b1;
        default: instr_outstanding_q <= instr_outstanding_q;
      endcase
    end
  end

  soc_rom rom_i (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .req_i   (rom_instr_req),
      .addr_i  (core_instr_addr),
      .gnt_o   (rom_instr_gnt),
      .rvalid_o(rom_instr_rvalid),
      .rdata_o (rom_instr_rdata)
  );

`ifndef SYNTHESIS
  initial begin
    if (ROM_INIT_FILE != "") begin
      // Load after child memory init blocks have cleared the array.
      #1;
      $readmemh(ROM_INIT_FILE, rom_i.mem_i.mem);
    end
  end

  initial begin
    if (IMEM_INIT_FILE != "") begin
      // Load after child memory init blocks have cleared the array.
      #1;
      $readmemh(IMEM_INIT_FILE, imem_i.mem_i.mem);
    end
  end
`endif

  soc_imem imem_i (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .instr_req_i   (imem_instr_req),
      .instr_addr_i  (core_instr_addr),
      .instr_gnt_o   (imem_instr_gnt),
      .instr_rvalid_o(imem_instr_rvalid),
      .instr_rdata_o (imem_instr_rdata),
      .data_req_i    (imem_data_req),
      .data_we_i     (imem_data_we),
      .data_be_i     (imem_data_be),
      .data_addr_i   (imem_data_addr),
      .data_wdata_i  (imem_data_wdata),
      .data_gnt_o    (imem_data_gnt),
      .data_rvalid_o (imem_data_rvalid),
      .data_rdata_o  (imem_data_rdata),
      .boot_req_i    (imem_boot_req),
      .boot_we_i     (imem_boot_we),
      .boot_be_i     (imem_boot_be),
      .boot_addr_i   (imem_boot_addr),
      .boot_wdata_i  (imem_boot_wdata),
      .boot_gnt_o    (imem_boot_gnt)
  );

  soc_boot_copy_xip #(
      .BOOT_ENABLE   (BOOT_COPY_XIP_ENABLE),
      .XIP_BASE_ADDR (SOC_QSPI_XIP_BASE_ADDR),
      .IMEM_BASE_ADDR(SOC_IMEM_BASE_ADDR),
      .COPY_WORDS    (BOOT_COPY_WORDS)
  ) boot_copy_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .start_i        (qspi_boot_ready),
      .boot_active_o  (boot_active),
      .boot_done_o    (boot_done),
      .m_axi_awaddr_o (boot_axi_awaddr),
      .m_axi_awprot_o (boot_axi_awprot),
      .m_axi_awvalid_o(boot_axi_awvalid),
      .m_axi_awready_i(boot_axi_awready),
      .m_axi_wdata_o  (boot_axi_wdata),
      .m_axi_wstrb_o  (boot_axi_wstrb),
      .m_axi_wvalid_o (boot_axi_wvalid),
      .m_axi_wready_i (boot_axi_wready),
      .m_axi_bresp_i  (boot_axi_bresp),
      .m_axi_bvalid_i (boot_axi_bvalid),
      .m_axi_bready_o (boot_axi_bready),
      .m_axi_araddr_o (boot_axi_araddr),
      .m_axi_arprot_o (boot_axi_arprot),
      .m_axi_arvalid_o(boot_axi_arvalid),
      .m_axi_arready_i(boot_axi_arready),
      .m_axi_rdata_i  (boot_axi_rdata),
      .m_axi_rresp_i  (boot_axi_rresp),
      .m_axi_rvalid_i (boot_axi_rvalid),
      .m_axi_rready_o (boot_axi_rready),
      .imem_req_o     (imem_boot_req),
      .imem_we_o      (imem_boot_we),
      .imem_be_o      (imem_boot_be),
      .imem_addr_o    (imem_boot_addr),
      .imem_wdata_o   (imem_boot_wdata),
      .imem_gnt_i     (imem_boot_gnt)
  );

  cv32e40p_top #(
      .COREV_PULP       (COREV_PULP),
      .COREV_CLUSTER    (COREV_CLUSTER),
      .FPU              (FPU),
      .FPU_ADDMUL_LAT   (FPU_ADDMUL_LAT),
      .FPU_OTHERS_LAT   (FPU_OTHERS_LAT),
      .ZFINX            (ZFINX),
      .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS)
  ) core_i (
      .clk_i               (clk_i),
      .rst_ni              (core_rst_ni),
      .pulp_clock_en_i     (pulp_clock_en_i),
      .scan_cg_en_i        (scan_cg_en_i),
      .boot_addr_i         (boot_addr_i),
      .mtvec_addr_i        (mtvec_addr_i),
      .dm_halt_addr_i      (dm_halt_addr_i),
      .hart_id_i           (hart_id_i),
      .dm_exception_addr_i (dm_exception_addr_i),
      .instr_req_o         (core_instr_req),
      .instr_gnt_i         (core_instr_gnt),
      .instr_rvalid_i      (core_instr_rvalid),
      .instr_addr_o        (core_instr_addr),
      .instr_rdata_i       (core_instr_rdata),
      .data_req_o          (data_req),
      .data_gnt_i          (data_gnt),
      .data_rvalid_i       (data_rvalid),
      .data_we_o           (data_we),
      .data_be_o           (data_be),
      .data_addr_o         (data_addr),
      .data_wdata_o        (data_wdata),
      .data_rdata_i        (data_rdata),
      .irq_i               (core_irq),
      .irq_ack_o           (irq_ack_o),
      .irq_id_o            (irq_id_o),
      .debug_req_i         (debug_req_i),
      .debug_havereset_o   (debug_havereset_o),
      .debug_running_o     (debug_running_o),
      .debug_halted_o      (debug_halted_o),
      .fetch_enable_i      (fetch_enable_i),
      .core_sleep_o        (core_sleep_o)
  );

  cv32e40p_obi_to_axi_lite data_axi_bridge_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .obi_req_i       (data_req),
      .obi_we_i        (data_we),
      .obi_be_i        (data_be),
      .obi_addr_i      (data_addr),
      .obi_wdata_i     (data_wdata),
      .obi_gnt_o       (data_gnt),
      .obi_rvalid_o    (data_rvalid),
      .obi_rdata_o     (data_rdata),
      .m_axi_awaddr_o  (bridge_axi_awaddr),
      .m_axi_awprot_o  (bridge_axi_awprot),
      .m_axi_awvalid_o (bridge_axi_awvalid),
      .m_axi_awready_i (bridge_axi_awready),
      .m_axi_wdata_o   (bridge_axi_wdata),
      .m_axi_wstrb_o   (bridge_axi_wstrb),
      .m_axi_wvalid_o  (bridge_axi_wvalid),
      .m_axi_wready_i  (bridge_axi_wready),
      .m_axi_bresp_i   (bridge_axi_bresp),
      .m_axi_bvalid_i  (bridge_axi_bvalid),
      .m_axi_bready_o  (bridge_axi_bready),
      .m_axi_araddr_o  (bridge_axi_araddr),
      .m_axi_arprot_o  (bridge_axi_arprot),
      .m_axi_arvalid_o (bridge_axi_arvalid),
      .m_axi_arready_i (bridge_axi_arready),
      .m_axi_rdata_i   (bridge_axi_rdata),
      .m_axi_rresp_i   (bridge_axi_rresp),
      .m_axi_rvalid_i  (bridge_axi_rvalid),
      .m_axi_rready_o  (bridge_axi_rready)
  );

  assign fabric_axi_awaddr  = boot_active ? boot_axi_awaddr  : bridge_axi_awaddr;
  assign fabric_axi_awprot  = boot_active ? boot_axi_awprot  : bridge_axi_awprot;
  assign fabric_axi_awvalid = boot_active ? boot_axi_awvalid : bridge_axi_awvalid;
  assign fabric_axi_wdata   = boot_active ? boot_axi_wdata   : bridge_axi_wdata;
  assign fabric_axi_wstrb   = boot_active ? boot_axi_wstrb   : bridge_axi_wstrb;
  assign fabric_axi_wvalid  = boot_active ? boot_axi_wvalid  : bridge_axi_wvalid;
  assign fabric_axi_bready  = boot_active ? boot_axi_bready  : bridge_axi_bready;
  assign fabric_axi_araddr  = boot_active ? boot_axi_araddr  : bridge_axi_araddr;
  assign fabric_axi_arprot  = boot_active ? boot_axi_arprot  : bridge_axi_arprot;
  assign fabric_axi_arvalid = boot_active ? boot_axi_arvalid : bridge_axi_arvalid;
  assign fabric_axi_rready  = boot_active ? boot_axi_rready  : bridge_axi_rready;

  assign bridge_axi_awready = boot_active ? 1'b0 : fabric_axi_awready;
  assign bridge_axi_wready  = boot_active ? 1'b0 : fabric_axi_wready;
  assign bridge_axi_bresp   = boot_active ? 2'b00 : fabric_axi_bresp;
  assign bridge_axi_bvalid  = boot_active ? 1'b0 : fabric_axi_bvalid;
  assign bridge_axi_arready = boot_active ? 1'b0 : fabric_axi_arready;
  assign bridge_axi_rdata   = boot_active ? 32'h0 : fabric_axi_rdata;
  assign bridge_axi_rresp   = boot_active ? 2'b00 : fabric_axi_rresp;
  assign bridge_axi_rvalid  = boot_active ? 1'b0 : fabric_axi_rvalid;

  assign boot_axi_awready = boot_active ? fabric_axi_awready : 1'b0;
  assign boot_axi_wready  = boot_active ? fabric_axi_wready  : 1'b0;
  assign boot_axi_bresp   = boot_active ? fabric_axi_bresp   : 2'b00;
  assign boot_axi_bvalid  = boot_active ? fabric_axi_bvalid  : 1'b0;
  assign boot_axi_arready = boot_active ? fabric_axi_arready : 1'b0;
  assign boot_axi_rdata   = boot_active ? fabric_axi_rdata   : 32'h0;
  assign boot_axi_rresp   = boot_active ? fabric_axi_rresp   : 2'b00;
  assign boot_axi_rvalid  = boot_active ? fabric_axi_rvalid  : 1'b0;

  // Local IMEM alias exists primarily for ROM/QSPI boot code to populate IMEM before
  // handing execution over to instruction fetches from the same memory.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_IMEM_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_IMEM_IMPL_BYTES)
  ) axi_imem_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (fabric_axi_awaddr),
      .s_axi_awprot_i      (fabric_axi_awprot),
      .s_axi_awvalid_i     (fabric_axi_awvalid),
      .s_axi_awready_o     (fabric_axi_awready),
      .s_axi_wdata_i       (fabric_axi_wdata),
      .s_axi_wstrb_i       (fabric_axi_wstrb),
      .s_axi_wvalid_i      (fabric_axi_wvalid),
      .s_axi_wready_o      (fabric_axi_wready),
      .s_axi_bresp_o       (fabric_axi_bresp),
      .s_axi_bvalid_o      (fabric_axi_bvalid),
      .s_axi_bready_i      (fabric_axi_bready),
      .s_axi_araddr_i      (fabric_axi_araddr),
      .s_axi_arprot_i      (fabric_axi_arprot),
      .s_axi_arvalid_i     (fabric_axi_arvalid),
      .s_axi_arready_o     (fabric_axi_arready),
      .s_axi_rdata_o       (fabric_axi_rdata),
      .s_axi_rresp_o       (fabric_axi_rresp),
      .s_axi_rvalid_o      (fabric_axi_rvalid),
      .s_axi_rready_i      (fabric_axi_rready),
      .local0_axi_awaddr_o (imem_axi_awaddr),
      .local0_axi_awprot_o (imem_axi_awprot),
      .local0_axi_awvalid_o(imem_axi_awvalid),
      .local0_axi_awready_i(imem_axi_awready),
      .local0_axi_wdata_o  (imem_axi_wdata),
      .local0_axi_wstrb_o  (imem_axi_wstrb),
      .local0_axi_wvalid_o (imem_axi_wvalid),
      .local0_axi_wready_i (imem_axi_wready),
      .local0_axi_bresp_i  (imem_axi_bresp),
      .local0_axi_bvalid_i (imem_axi_bvalid),
      .local0_axi_bready_o (imem_axi_bready),
      .local0_axi_araddr_o (imem_axi_araddr),
      .local0_axi_arprot_o (imem_axi_arprot),
      .local0_axi_arvalid_o(imem_axi_arvalid),
      .local0_axi_arready_i(imem_axi_arready),
      .local0_axi_rdata_i  (imem_axi_rdata),
      .local0_axi_rresp_i  (imem_axi_rresp),
      .local0_axi_rvalid_i (imem_axi_rvalid),
      .local0_axi_rready_o (imem_axi_rready),
      .ext_axi_awaddr_o    (pre_dmem_axi_awaddr),
      .ext_axi_awprot_o    (pre_dmem_axi_awprot),
      .ext_axi_awvalid_o   (pre_dmem_axi_awvalid),
      .ext_axi_awready_i   (pre_dmem_axi_awready),
      .ext_axi_wdata_o     (pre_dmem_axi_wdata),
      .ext_axi_wstrb_o     (pre_dmem_axi_wstrb),
      .ext_axi_wvalid_o    (pre_dmem_axi_wvalid),
      .ext_axi_wready_i    (pre_dmem_axi_wready),
      .ext_axi_bresp_i     (pre_dmem_axi_bresp),
      .ext_axi_bvalid_i    (pre_dmem_axi_bvalid),
      .ext_axi_bready_o    (pre_dmem_axi_bready),
      .ext_axi_araddr_o    (pre_dmem_axi_araddr),
      .ext_axi_arprot_o    (pre_dmem_axi_arprot),
      .ext_axi_arvalid_o   (pre_dmem_axi_arvalid),
      .ext_axi_arready_i   (pre_dmem_axi_arready),
      .ext_axi_rdata_i     (pre_dmem_axi_rdata),
      .ext_axi_rresp_i     (pre_dmem_axi_rresp),
      .ext_axi_rvalid_i    (pre_dmem_axi_rvalid),
      .ext_axi_rready_o    (pre_dmem_axi_rready)
  );

  soc_axi_lite_imem imem_axi_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (imem_axi_awaddr),
      .s_axi_awprot_i (imem_axi_awprot),
      .s_axi_awvalid_i(imem_axi_awvalid),
      .s_axi_awready_o(imem_axi_awready),
      .s_axi_wdata_i  (imem_axi_wdata),
      .s_axi_wstrb_i  (imem_axi_wstrb),
      .s_axi_wvalid_i (imem_axi_wvalid),
      .s_axi_wready_o (imem_axi_wready),
      .s_axi_bresp_o  (imem_axi_bresp),
      .s_axi_bvalid_o (imem_axi_bvalid),
      .s_axi_bready_i (imem_axi_bready),
      .s_axi_araddr_i (imem_axi_araddr),
      .s_axi_arprot_i (imem_axi_arprot),
      .s_axi_arvalid_i(imem_axi_arvalid),
      .s_axi_arready_o(imem_axi_arready),
      .s_axi_rdata_o  (imem_axi_rdata),
      .s_axi_rresp_o  (imem_axi_rresp),
      .s_axi_rvalid_o (imem_axi_rvalid),
      .s_axi_rready_i (imem_axi_rready),
      .imem_req_o     (imem_data_req),
      .imem_we_o      (imem_data_we),
      .imem_be_o      (imem_data_be),
      .imem_addr_o    (imem_data_addr),
      .imem_wdata_o   (imem_data_wdata),
      .imem_gnt_i     (imem_data_gnt),
      .imem_rvalid_i  (imem_data_rvalid),
      .imem_rdata_i   (imem_data_rdata)
  );

  // Local DMEM lives ahead of on-chip MMIO so regular data accesses do not leave the SoC.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_DMEM_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_DMEM_IMPL_BYTES)
  ) axi_dmem_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (pre_dmem_axi_awaddr),
      .s_axi_awprot_i      (pre_dmem_axi_awprot),
      .s_axi_awvalid_i     (pre_dmem_axi_awvalid),
      .s_axi_awready_o     (pre_dmem_axi_awready),
      .s_axi_wdata_i       (pre_dmem_axi_wdata),
      .s_axi_wstrb_i       (pre_dmem_axi_wstrb),
      .s_axi_wvalid_i      (pre_dmem_axi_wvalid),
      .s_axi_wready_o      (pre_dmem_axi_wready),
      .s_axi_bresp_o       (pre_dmem_axi_bresp),
      .s_axi_bvalid_o      (pre_dmem_axi_bvalid),
      .s_axi_bready_i      (pre_dmem_axi_bready),
      .s_axi_araddr_i      (pre_dmem_axi_araddr),
      .s_axi_arprot_i      (pre_dmem_axi_arprot),
      .s_axi_arvalid_i     (pre_dmem_axi_arvalid),
      .s_axi_arready_o     (pre_dmem_axi_arready),
      .s_axi_rdata_o       (pre_dmem_axi_rdata),
      .s_axi_rresp_o       (pre_dmem_axi_rresp),
      .s_axi_rvalid_o      (pre_dmem_axi_rvalid),
      .s_axi_rready_i      (pre_dmem_axi_rready),
      .local0_axi_awaddr_o (dmem_axi_awaddr),
      .local0_axi_awprot_o (dmem_axi_awprot),
      .local0_axi_awvalid_o(dmem_axi_awvalid),
      .local0_axi_awready_i(dmem_axi_awready),
      .local0_axi_wdata_o  (dmem_axi_wdata),
      .local0_axi_wstrb_o  (dmem_axi_wstrb),
      .local0_axi_wvalid_o (dmem_axi_wvalid),
      .local0_axi_wready_i (dmem_axi_wready),
      .local0_axi_bresp_i  (dmem_axi_bresp),
      .local0_axi_bvalid_i (dmem_axi_bvalid),
      .local0_axi_bready_o (dmem_axi_bready),
      .local0_axi_araddr_o (dmem_axi_araddr),
      .local0_axi_arprot_o (dmem_axi_arprot),
      .local0_axi_arvalid_o(dmem_axi_arvalid),
      .local0_axi_arready_i(dmem_axi_arready),
      .local0_axi_rdata_i  (dmem_axi_rdata),
      .local0_axi_rresp_i  (dmem_axi_rresp),
      .local0_axi_rvalid_i (dmem_axi_rvalid),
      .local0_axi_rready_o (dmem_axi_rready),
      .ext_axi_awaddr_o    (sys_axi_awaddr),
      .ext_axi_awprot_o    (sys_axi_awprot),
      .ext_axi_awvalid_o   (sys_axi_awvalid),
      .ext_axi_awready_i   (sys_axi_awready),
      .ext_axi_wdata_o     (sys_axi_wdata),
      .ext_axi_wstrb_o     (sys_axi_wstrb),
      .ext_axi_wvalid_o    (sys_axi_wvalid),
      .ext_axi_wready_i    (sys_axi_wready),
      .ext_axi_bresp_i     (sys_axi_bresp),
      .ext_axi_bvalid_i    (sys_axi_bvalid),
      .ext_axi_bready_o    (sys_axi_bready),
      .ext_axi_araddr_o    (sys_axi_araddr),
      .ext_axi_arprot_o    (sys_axi_arprot),
      .ext_axi_arvalid_o   (sys_axi_arvalid),
      .ext_axi_arready_i   (sys_axi_arready),
      .ext_axi_rdata_i     (sys_axi_rdata),
      .ext_axi_rresp_i     (sys_axi_rresp),
      .ext_axi_rvalid_i    (sys_axi_rvalid),
      .ext_axi_rready_o    (sys_axi_rready)
  );

  soc_dmem dmem_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (dmem_axi_awaddr),
      .s_axi_awprot_i (dmem_axi_awprot),
      .s_axi_awvalid_i(dmem_axi_awvalid),
      .s_axi_awready_o(dmem_axi_awready),
      .s_axi_wdata_i  (dmem_axi_wdata),
      .s_axi_wstrb_i  (dmem_axi_wstrb),
      .s_axi_wvalid_i (dmem_axi_wvalid),
      .s_axi_wready_o (dmem_axi_wready),
      .s_axi_bresp_o  (dmem_axi_bresp),
      .s_axi_bvalid_o (dmem_axi_bvalid),
      .s_axi_bready_i (dmem_axi_bready),
      .s_axi_araddr_i (dmem_axi_araddr),
      .s_axi_arprot_i (dmem_axi_arprot),
      .s_axi_arvalid_i(dmem_axi_arvalid),
      .s_axi_arready_o(dmem_axi_arready),
      .s_axi_rdata_o  (dmem_axi_rdata),
      .s_axi_rresp_o  (dmem_axi_rresp),
      .s_axi_rvalid_o (dmem_axi_rvalid),
      .s_axi_rready_i (dmem_axi_rready)
  );

  // Keep all MMIO accesses on-chip and forward non-MMIO traffic to the external AXI fabric.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_MMIO_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(MMIO_WINDOW_BYTES)
  ) axi_mmio_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (sys_axi_awaddr),
      .s_axi_awprot_i      (sys_axi_awprot),
      .s_axi_awvalid_i     (sys_axi_awvalid),
      .s_axi_awready_o     (sys_axi_awready),
      .s_axi_wdata_i       (sys_axi_wdata),
      .s_axi_wstrb_i       (sys_axi_wstrb),
      .s_axi_wvalid_i      (sys_axi_wvalid),
      .s_axi_wready_o      (sys_axi_wready),
      .s_axi_bresp_o       (sys_axi_bresp),
      .s_axi_bvalid_o      (sys_axi_bvalid),
      .s_axi_bready_i      (sys_axi_bready),
      .s_axi_araddr_i      (sys_axi_araddr),
      .s_axi_arprot_i      (sys_axi_arprot),
      .s_axi_arvalid_i     (sys_axi_arvalid),
      .s_axi_arready_o     (sys_axi_arready),
      .s_axi_rdata_o       (sys_axi_rdata),
      .s_axi_rresp_o       (sys_axi_rresp),
      .s_axi_rvalid_o      (sys_axi_rvalid),
      .s_axi_rready_i      (sys_axi_rready),
      .local0_axi_awaddr_o (mmio_axi_awaddr),
      .local0_axi_awprot_o (mmio_axi_awprot),
      .local0_axi_awvalid_o(mmio_axi_awvalid),
      .local0_axi_awready_i(mmio_axi_awready),
      .local0_axi_wdata_o  (mmio_axi_wdata),
      .local0_axi_wstrb_o  (mmio_axi_wstrb),
      .local0_axi_wvalid_o (mmio_axi_wvalid),
      .local0_axi_wready_i (mmio_axi_wready),
      .local0_axi_bresp_i  (mmio_axi_bresp),
      .local0_axi_bvalid_i (mmio_axi_bvalid),
      .local0_axi_bready_o (mmio_axi_bready),
      .local0_axi_araddr_o (mmio_axi_araddr),
      .local0_axi_arprot_o (mmio_axi_arprot),
      .local0_axi_arvalid_o(mmio_axi_arvalid),
      .local0_axi_arready_i(mmio_axi_arready),
      .local0_axi_rdata_i  (mmio_axi_rdata),
      .local0_axi_rresp_i  (mmio_axi_rresp),
      .local0_axi_rvalid_i (mmio_axi_rvalid),
      .local0_axi_rready_o (mmio_axi_rready),
      .ext_axi_awaddr_o    (ext_axi_awaddr),
      .ext_axi_awprot_o    (ext_axi_awprot),
      .ext_axi_awvalid_o   (ext_axi_awvalid),
      .ext_axi_awready_i   (ext_axi_awready),
      .ext_axi_wdata_o     (ext_axi_wdata),
      .ext_axi_wstrb_o     (ext_axi_wstrb),
      .ext_axi_wvalid_o    (ext_axi_wvalid),
      .ext_axi_wready_i    (ext_axi_wready),
      .ext_axi_bresp_i     (ext_axi_bresp),
      .ext_axi_bvalid_i    (ext_axi_bvalid),
      .ext_axi_bready_o    (ext_axi_bready),
      .ext_axi_araddr_o    (ext_axi_araddr),
      .ext_axi_arprot_o    (ext_axi_arprot),
      .ext_axi_arvalid_o   (ext_axi_arvalid),
      .ext_axi_arready_i   (ext_axi_arready),
      .ext_axi_rdata_i     (ext_axi_rdata),
      .ext_axi_rresp_i     (ext_axi_rresp),
      .ext_axi_rvalid_i    (ext_axi_rvalid),
      .ext_axi_rready_o    (ext_axi_rready)
  );

  // AI_MEM is a local 30 KB accelerator buffer behind a 32 KB decode window.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_AI_MEM_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_AI_MEM_WINDOW_BYTES)
  ) axi_ai_mem_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (ext_axi_awaddr),
      .s_axi_awprot_i      (ext_axi_awprot),
      .s_axi_awvalid_i     (ext_axi_awvalid),
      .s_axi_awready_o     (ext_axi_awready),
      .s_axi_wdata_i       (ext_axi_wdata),
      .s_axi_wstrb_i       (ext_axi_wstrb),
      .s_axi_wvalid_i      (ext_axi_wvalid),
      .s_axi_wready_o      (ext_axi_wready),
      .s_axi_bresp_o       (ext_axi_bresp),
      .s_axi_bvalid_o      (ext_axi_bvalid),
      .s_axi_bready_i      (ext_axi_bready),
      .s_axi_araddr_i      (ext_axi_araddr),
      .s_axi_arprot_i      (ext_axi_arprot),
      .s_axi_arvalid_i     (ext_axi_arvalid),
      .s_axi_arready_o     (ext_axi_arready),
      .s_axi_rdata_o       (ext_axi_rdata),
      .s_axi_rresp_o       (ext_axi_rresp),
      .s_axi_rvalid_o      (ext_axi_rvalid),
      .s_axi_rready_i      (ext_axi_rready),
      .local0_axi_awaddr_o (ai_mem_axi_awaddr),
      .local0_axi_awprot_o (ai_mem_axi_awprot),
      .local0_axi_awvalid_o(ai_mem_axi_awvalid),
      .local0_axi_awready_i(ai_mem_axi_awready),
      .local0_axi_wdata_o  (ai_mem_axi_wdata),
      .local0_axi_wstrb_o  (ai_mem_axi_wstrb),
      .local0_axi_wvalid_o (ai_mem_axi_wvalid),
      .local0_axi_wready_i (ai_mem_axi_wready),
      .local0_axi_bresp_i  (ai_mem_axi_bresp),
      .local0_axi_bvalid_i (ai_mem_axi_bvalid),
      .local0_axi_bready_o (ai_mem_axi_bready),
      .local0_axi_araddr_o (ai_mem_axi_araddr),
      .local0_axi_arprot_o (ai_mem_axi_arprot),
      .local0_axi_arvalid_o(ai_mem_axi_arvalid),
      .local0_axi_arready_i(ai_mem_axi_arready),
      .local0_axi_rdata_i  (ai_mem_axi_rdata),
      .local0_axi_rresp_i  (ai_mem_axi_rresp),
      .local0_axi_rvalid_i (ai_mem_axi_rvalid),
      .local0_axi_rready_o (ai_mem_axi_rready),
      .ext_axi_awaddr_o    (pre_qspi_axi_awaddr),
      .ext_axi_awprot_o    (pre_qspi_axi_awprot),
      .ext_axi_awvalid_o   (pre_qspi_axi_awvalid),
      .ext_axi_awready_i   (pre_qspi_axi_awready),
      .ext_axi_wdata_o     (pre_qspi_axi_wdata),
      .ext_axi_wstrb_o     (pre_qspi_axi_wstrb),
      .ext_axi_wvalid_o    (pre_qspi_axi_wvalid),
      .ext_axi_wready_i    (pre_qspi_axi_wready),
      .ext_axi_bresp_i     (pre_qspi_axi_bresp),
      .ext_axi_bvalid_i    (pre_qspi_axi_bvalid),
      .ext_axi_bready_o    (pre_qspi_axi_bready),
      .ext_axi_araddr_o    (pre_qspi_axi_araddr),
      .ext_axi_arprot_o    (pre_qspi_axi_arprot),
      .ext_axi_arvalid_o   (pre_qspi_axi_arvalid),
      .ext_axi_arready_i   (pre_qspi_axi_arready),
      .ext_axi_rdata_i     (pre_qspi_axi_rdata),
      .ext_axi_rresp_i     (pre_qspi_axi_rresp),
      .ext_axi_rvalid_i    (pre_qspi_axi_rvalid),
      .ext_axi_rready_o    (pre_qspi_axi_rready)
  );

  assign ai_mem_int_req = ai_uart_mem_req || ai_accel_mem_req;
  assign ai_mem_int_we = ai_uart_mem_req ? ai_uart_mem_we : ai_accel_mem_we;
  assign ai_mem_int_be = ai_uart_mem_req ? ai_uart_mem_be : ai_accel_mem_be;
  assign ai_mem_int_addr = ai_uart_mem_req ? ai_uart_mem_addr : ai_accel_mem_addr;
  assign ai_mem_int_wdata = ai_uart_mem_req ? ai_uart_mem_wdata : ai_accel_mem_wdata;
  assign ai_uart_mem_gnt = ai_uart_mem_req ? ai_mem_int_gnt : 1'b0;
  assign ai_accel_mem_gnt = (!ai_uart_mem_req && ai_accel_mem_req) ? ai_mem_int_gnt : 1'b0;
  assign ai_accel_mem_rvalid = ai_mem_rsp_accel_q && ai_mem_int_rvalid;
  assign ai_accel_mem_rdata = ai_mem_int_rdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ai_mem_rsp_accel_q <= 1'b0;
    end else begin
      if (ai_mem_int_gnt) begin
        ai_mem_rsp_accel_q <= !ai_uart_mem_req && ai_accel_mem_req && !ai_accel_mem_we;
      end else if (ai_mem_int_rvalid) begin
        ai_mem_rsp_accel_q <= 1'b0;
      end
    end
  end

  soc_ai_mem ai_mem_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (ai_mem_axi_awaddr),
      .s_axi_awprot_i (ai_mem_axi_awprot),
      .s_axi_awvalid_i(ai_mem_axi_awvalid),
      .s_axi_awready_o(ai_mem_axi_awready),
      .s_axi_wdata_i  (ai_mem_axi_wdata),
      .s_axi_wstrb_i  (ai_mem_axi_wstrb),
      .s_axi_wvalid_i (ai_mem_axi_wvalid),
      .s_axi_wready_o (ai_mem_axi_wready),
      .s_axi_bresp_o  (ai_mem_axi_bresp),
      .s_axi_bvalid_o (ai_mem_axi_bvalid),
      .s_axi_bready_i (ai_mem_axi_bready),
      .s_axi_araddr_i (ai_mem_axi_araddr),
      .s_axi_arprot_i (ai_mem_axi_arprot),
      .s_axi_arvalid_i(ai_mem_axi_arvalid),
      .s_axi_arready_o(ai_mem_axi_arready),
      .s_axi_rdata_o  (ai_mem_axi_rdata),
      .s_axi_rresp_o  (ai_mem_axi_rresp),
      .s_axi_rvalid_o (ai_mem_axi_rvalid),
      .s_axi_rready_i (ai_mem_axi_rready),
      .ai_req_i       (ai_mem_int_req),
      .ai_we_i        (ai_mem_int_we),
      .ai_be_i        (ai_mem_int_be),
      .ai_addr_i      (ai_mem_int_addr),
      .ai_wdata_i     (ai_mem_int_wdata),
      .ai_gnt_o       (ai_mem_int_gnt),
      .ai_rvalid_o    (ai_mem_int_rvalid),
      .ai_rdata_o     (ai_mem_int_rdata)
  );

  soc_ai_uart_loader ai_uart_loader_i (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .start_i      (ai_uart_start),
      .baud_div_i   (ai_uart_baud_div),
      .input_base_i (ai_input_base),
      .input_len_i  (ai_input_len),
      .uart_rx_i    (uart1_rx_i),
      .active_o     (ai_uart_active),
      .done_o       (ai_uart_done),
      .error_o      (ai_uart_error),
      .byte_count_o (ai_uart_byte_count),
      .mem_req_o    (ai_uart_mem_req),
      .mem_we_o     (ai_uart_mem_we),
      .mem_be_o     (ai_uart_mem_be),
      .mem_addr_o   (ai_uart_mem_addr),
      .mem_wdata_o  (ai_uart_mem_wdata),
      .mem_gnt_i    (ai_uart_mem_gnt)
  );

  soc_ai_tinyconv_accel ai_accel_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .start_i             (ai_accel_start),
      .input_base_i        (ai_input_base),
      .input_len_i         (ai_input_len),
      .output_base_i       (ai_output_base),
      .busy_o              (ai_accel_busy),
      .done_o              (ai_accel_done),
      .result_class_o      (ai_result_class),
      .result0_o           (ai_result0),
      .result1_o           (ai_result1),
      .result2_o           (ai_result2),
      .result3_o           (ai_result3),
      .cycle_count_o       (ai_cycle_count),
      .mem_req_o           (ai_accel_mem_req),
      .mem_we_o            (ai_accel_mem_we),
      .mem_be_o            (ai_accel_mem_be),
      .mem_addr_o          (ai_accel_mem_addr),
      .mem_wdata_o         (ai_accel_mem_wdata),
      .mem_gnt_i           (ai_accel_mem_gnt),
      .mem_rvalid_i        (ai_accel_mem_rvalid),
      .mem_rdata_i         (ai_accel_mem_rdata)
  );

  // Keep the XIP flash window local so boot-copy and future execute-in-place accesses
  // do not depend on the external AXI test memory.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_QSPI_XIP_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_QSPI_XIP_IMPL_BYTES)
  ) axi_qspi_xip_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (pre_qspi_axi_awaddr),
      .s_axi_awprot_i      (pre_qspi_axi_awprot),
      .s_axi_awvalid_i     (pre_qspi_axi_awvalid),
      .s_axi_awready_o     (pre_qspi_axi_awready),
      .s_axi_wdata_i       (pre_qspi_axi_wdata),
      .s_axi_wstrb_i       (pre_qspi_axi_wstrb),
      .s_axi_wvalid_i      (pre_qspi_axi_wvalid),
      .s_axi_wready_o      (pre_qspi_axi_wready),
      .s_axi_bresp_o       (pre_qspi_axi_bresp),
      .s_axi_bvalid_o      (pre_qspi_axi_bvalid),
      .s_axi_bready_i      (pre_qspi_axi_bready),
      .s_axi_araddr_i      (pre_qspi_axi_araddr),
      .s_axi_arprot_i      (pre_qspi_axi_arprot),
      .s_axi_arvalid_i     (pre_qspi_axi_arvalid),
      .s_axi_arready_o     (pre_qspi_axi_arready),
      .s_axi_rdata_o       (pre_qspi_axi_rdata),
      .s_axi_rresp_o       (pre_qspi_axi_rresp),
      .s_axi_rvalid_o      (pre_qspi_axi_rvalid),
      .s_axi_rready_i      (pre_qspi_axi_rready),
      .local0_axi_awaddr_o (qspi_xip_axi_awaddr),
      .local0_axi_awprot_o (qspi_xip_axi_awprot),
      .local0_axi_awvalid_o(qspi_xip_axi_awvalid),
      .local0_axi_awready_i(qspi_xip_axi_awready),
      .local0_axi_wdata_o  (qspi_xip_axi_wdata),
      .local0_axi_wstrb_o  (qspi_xip_axi_wstrb),
      .local0_axi_wvalid_o (qspi_xip_axi_wvalid),
      .local0_axi_wready_i (qspi_xip_axi_wready),
      .local0_axi_bresp_i  (qspi_xip_axi_bresp),
      .local0_axi_bvalid_i (qspi_xip_axi_bvalid),
      .local0_axi_bready_o (qspi_xip_axi_bready),
      .local0_axi_araddr_o (qspi_xip_axi_araddr),
      .local0_axi_arprot_o (qspi_xip_axi_arprot),
      .local0_axi_arvalid_o(qspi_xip_axi_arvalid),
      .local0_axi_arready_i(qspi_xip_axi_arready),
      .local0_axi_rdata_i  (qspi_xip_axi_rdata),
      .local0_axi_rresp_i  (qspi_xip_axi_rresp),
      .local0_axi_rvalid_i (qspi_xip_axi_rvalid),
      .local0_axi_rready_o (qspi_xip_axi_rready),
      .ext_axi_awaddr_o    (m_axi_awaddr_o),
      .ext_axi_awprot_o    (m_axi_awprot_o),
      .ext_axi_awvalid_o   (m_axi_awvalid_o),
      .ext_axi_awready_i   (m_axi_awready_i),
      .ext_axi_wdata_o     (m_axi_wdata_o),
      .ext_axi_wstrb_o     (m_axi_wstrb_o),
      .ext_axi_wvalid_o    (m_axi_wvalid_o),
      .ext_axi_wready_i    (m_axi_wready_i),
      .ext_axi_bresp_i     (m_axi_bresp_i),
      .ext_axi_bvalid_i    (m_axi_bvalid_i),
      .ext_axi_bready_o    (m_axi_bready_o),
      .ext_axi_araddr_o    (m_axi_araddr_o),
      .ext_axi_arprot_o    (m_axi_arprot_o),
      .ext_axi_arvalid_o   (m_axi_arvalid_o),
      .ext_axi_arready_i   (m_axi_arready_i),
      .ext_axi_rdata_i     (m_axi_rdata_i),
      .ext_axi_rresp_i     (m_axi_rresp_i),
      .ext_axi_rvalid_i    (m_axi_rvalid_i),
      .ext_axi_rready_o    (m_axi_rready_o)
  );

  soc_axi_lite_qspi_xip #(
      .XIP_BASE_ADDR      (SOC_QSPI_XIP_BASE_ADDR),
      .LGFLASHSZ          (24),
      .OPT_STARTUP        (1'b0),
      .SIM_XIP_ENABLE     (QSPI_SIM_XIP_ENABLE),
      .SIM_XIP_INIT_FILE  (QSPI_SIM_XIP_INIT_FILE),
      .SIM_XIP_DEPTH_WORDS(QSPI_SIM_XIP_DEPTH_WORDS)
  ) qspi_xip_i (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .s_axi_awaddr_i   (qspi_xip_axi_awaddr),
      .s_axi_awprot_i   (qspi_xip_axi_awprot),
      .s_axi_awvalid_i  (qspi_xip_axi_awvalid),
      .s_axi_awready_o  (qspi_xip_axi_awready),
      .s_axi_wdata_i    (qspi_xip_axi_wdata),
      .s_axi_wstrb_i    (qspi_xip_axi_wstrb),
      .s_axi_wvalid_i   (qspi_xip_axi_wvalid),
      .s_axi_wready_o   (qspi_xip_axi_wready),
      .s_axi_bresp_o    (qspi_xip_axi_bresp),
      .s_axi_bvalid_o   (qspi_xip_axi_bvalid),
      .s_axi_bready_i   (qspi_xip_axi_bready),
      .s_axi_araddr_i   (qspi_xip_axi_araddr),
      .s_axi_arprot_i   (qspi_xip_axi_arprot),
      .s_axi_arvalid_i  (qspi_xip_axi_arvalid),
      .s_axi_arready_o  (qspi_xip_axi_arready),
      .s_axi_rdata_o    (qspi_xip_axi_rdata),
      .s_axi_rresp_o    (qspi_xip_axi_rresp),
      .s_axi_rvalid_o   (qspi_xip_axi_rvalid),
      .s_axi_rready_i   (qspi_xip_axi_rready),
      .cfg_cmd_valid_i  (qspi_cfg_cmd_valid),
      .cfg_cmd_data_i   (qspi_cfg_cmd_data),
      .cfg_cmd_ready_o  (qspi_cfg_cmd_ready),
      .cfg_rsp_valid_o  (qspi_cfg_rsp_valid),
      .cfg_rsp_data_o   (qspi_cfg_rsp_data),
      .flash_busy_o     (qspi_flash_busy),
      .flash_init_done_o(qspi_flash_init_done),
      .qspi_cs_n_o      (qspi_cs_n_o),
      .qspi_sck_o       (qspi_sck_o),
      .qspi_mod_o       (qspi_mod_o),
      .qspi_dat_o       (qspi_dat_o),
      .qspi_dat_i       (qspi_dat_i)
  );

  soc_qspi_init_seq #(
      .ENABLE(QSPI_INIT_ENABLE)
  ) qspi_init_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .cfg_cmd_valid_o(qspi_init_cmd_valid),
      .cfg_cmd_data_o (qspi_init_cmd_data),
      .cfg_cmd_ready_i(qspi_init_cmd_ready),
      .cfg_rsp_valid_i(qspi_init_rsp_valid),
      .cfg_rsp_data_i (qspi_init_rsp_data),
      .init_active_o  (qspi_init_active),
      .init_done_o    (qspi_init_done),
      .init_error_o   (qspi_init_error),
      .last_rsp_data_o(qspi_init_last_rsp),
      .last_cmd_data_o(qspi_init_last_cmd),
      .step_index_o   (qspi_init_step),
      .error_code_o   (qspi_init_error_code)
  );

  soc_qspi_cfg_mux qspi_cfg_mux_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .init_cmd_valid_i(qspi_init_cmd_valid),
      .init_cmd_data_i (qspi_init_cmd_data),
      .init_cmd_ready_o(qspi_init_cmd_ready),
      .init_rsp_valid_o(qspi_init_rsp_valid),
      .init_rsp_data_o (qspi_init_rsp_data),
      .sw_cmd_valid_i  (qspi_sw_cmd_valid),
      .sw_cmd_data_i   (qspi_sw_cmd_data),
      .sw_cmd_ready_o  (qspi_sw_cmd_ready),
      .sw_rsp_valid_o  (qspi_sw_rsp_valid),
      .sw_rsp_data_o   (qspi_sw_rsp_data),
      .cfg_cmd_valid_o (qspi_cfg_cmd_valid),
      .cfg_cmd_data_o  (qspi_cfg_cmd_data),
      .cfg_cmd_ready_i (qspi_cfg_cmd_ready),
      .cfg_rsp_valid_i (qspi_cfg_rsp_valid),
      .cfg_rsp_data_i  (qspi_cfg_rsp_data)
  );

  // Within the on-chip MMIO space, keep UART0/UART1 native and route the rest through the APB island.
  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_UART0_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_UART0_IMPL_BYTES)
  ) axi_uart0_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (mmio_axi_awaddr),
      .s_axi_awprot_i      (mmio_axi_awprot),
      .s_axi_awvalid_i     (mmio_axi_awvalid),
      .s_axi_awready_o     (mmio_axi_awready),
      .s_axi_wdata_i       (mmio_axi_wdata),
      .s_axi_wstrb_i       (mmio_axi_wstrb),
      .s_axi_wvalid_i      (mmio_axi_wvalid),
      .s_axi_wready_o      (mmio_axi_wready),
      .s_axi_bresp_o       (mmio_axi_bresp),
      .s_axi_bvalid_o      (mmio_axi_bvalid),
      .s_axi_bready_i      (mmio_axi_bready),
      .s_axi_araddr_i      (mmio_axi_araddr),
      .s_axi_arprot_i      (mmio_axi_arprot),
      .s_axi_arvalid_i     (mmio_axi_arvalid),
      .s_axi_arready_o     (mmio_axi_arready),
      .s_axi_rdata_o       (mmio_axi_rdata),
      .s_axi_rresp_o       (mmio_axi_rresp),
      .s_axi_rvalid_o      (mmio_axi_rvalid),
      .s_axi_rready_i      (mmio_axi_rready),
      .local0_axi_awaddr_o (uart0_axi_awaddr),
      .local0_axi_awprot_o (uart0_axi_awprot),
      .local0_axi_awvalid_o(uart0_axi_awvalid),
      .local0_axi_awready_i(uart0_axi_awready),
      .local0_axi_wdata_o  (uart0_axi_wdata),
      .local0_axi_wstrb_o  (uart0_axi_wstrb),
      .local0_axi_wvalid_o (uart0_axi_wvalid),
      .local0_axi_wready_i (uart0_axi_wready),
      .local0_axi_bresp_i  (uart0_axi_bresp),
      .local0_axi_bvalid_i (uart0_axi_bvalid),
      .local0_axi_bready_o (uart0_axi_bready),
      .local0_axi_araddr_o (uart0_axi_araddr),
      .local0_axi_arprot_o (uart0_axi_arprot),
      .local0_axi_arvalid_o(uart0_axi_arvalid),
      .local0_axi_arready_i(uart0_axi_arready),
      .local0_axi_rdata_i  (uart0_axi_rdata),
      .local0_axi_rresp_i  (uart0_axi_rresp),
      .local0_axi_rvalid_i (uart0_axi_rvalid),
      .local0_axi_rready_o (uart0_axi_rready),
      .ext_axi_awaddr_o    (uart1_mux_axi_awaddr),
      .ext_axi_awprot_o    (uart1_mux_axi_awprot),
      .ext_axi_awvalid_o   (uart1_mux_axi_awvalid),
      .ext_axi_awready_i   (uart1_mux_axi_awready),
      .ext_axi_wdata_o     (uart1_mux_axi_wdata),
      .ext_axi_wstrb_o     (uart1_mux_axi_wstrb),
      .ext_axi_wvalid_o    (uart1_mux_axi_wvalid),
      .ext_axi_wready_i    (uart1_mux_axi_wready),
      .ext_axi_bresp_i     (uart1_mux_axi_bresp),
      .ext_axi_bvalid_i    (uart1_mux_axi_bvalid),
      .ext_axi_bready_o    (uart1_mux_axi_bready),
      .ext_axi_araddr_o    (uart1_mux_axi_araddr),
      .ext_axi_arprot_o    (uart1_mux_axi_arprot),
      .ext_axi_arvalid_o   (uart1_mux_axi_arvalid),
      .ext_axi_arready_i   (uart1_mux_axi_arready),
      .ext_axi_rdata_i     (uart1_mux_axi_rdata),
      .ext_axi_rresp_i     (uart1_mux_axi_rresp),
      .ext_axi_rvalid_i    (uart1_mux_axi_rvalid),
      .ext_axi_rready_o    (uart1_mux_axi_rready)
  );

  soc_axi_lite_uart uart0_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (uart0_axi_awaddr),
      .s_axi_awprot_i (uart0_axi_awprot),
      .s_axi_awvalid_i(uart0_axi_awvalid),
      .s_axi_awready_o(uart0_axi_awready),
      .s_axi_wdata_i  (uart0_axi_wdata),
      .s_axi_wstrb_i  (uart0_axi_wstrb),
      .s_axi_wvalid_i (uart0_axi_wvalid),
      .s_axi_wready_o (uart0_axi_wready),
      .s_axi_bresp_o  (uart0_axi_bresp),
      .s_axi_bvalid_o (uart0_axi_bvalid),
      .s_axi_bready_i (uart0_axi_bready),
      .s_axi_araddr_i (uart0_axi_araddr),
      .s_axi_arprot_i (uart0_axi_arprot),
      .s_axi_arvalid_i(uart0_axi_arvalid),
      .s_axi_arready_o(uart0_axi_arready),
      .s_axi_rdata_o  (uart0_axi_rdata),
      .s_axi_rresp_o  (uart0_axi_rresp),
      .s_axi_rvalid_o (uart0_axi_rvalid),
      .s_axi_rready_i (uart0_axi_rready),
      .uart_rx_i      (uart0_rx_i),
      .uart_tx_o      (uart0_tx_o)
  );

  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_UART1_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_UART1_IMPL_BYTES)
  ) axi_uart1_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (uart1_mux_axi_awaddr),
      .s_axi_awprot_i      (uart1_mux_axi_awprot),
      .s_axi_awvalid_i     (uart1_mux_axi_awvalid),
      .s_axi_awready_o     (uart1_mux_axi_awready),
      .s_axi_wdata_i       (uart1_mux_axi_wdata),
      .s_axi_wstrb_i       (uart1_mux_axi_wstrb),
      .s_axi_wvalid_i      (uart1_mux_axi_wvalid),
      .s_axi_wready_o      (uart1_mux_axi_wready),
      .s_axi_bresp_o       (uart1_mux_axi_bresp),
      .s_axi_bvalid_o      (uart1_mux_axi_bvalid),
      .s_axi_bready_i      (uart1_mux_axi_bready),
      .s_axi_araddr_i      (uart1_mux_axi_araddr),
      .s_axi_arprot_i      (uart1_mux_axi_arprot),
      .s_axi_arvalid_i     (uart1_mux_axi_arvalid),
      .s_axi_arready_o     (uart1_mux_axi_arready),
      .s_axi_rdata_o       (uart1_mux_axi_rdata),
      .s_axi_rresp_o       (uart1_mux_axi_rresp),
      .s_axi_rvalid_o      (uart1_mux_axi_rvalid),
      .s_axi_rready_i      (uart1_mux_axi_rready),
      .local0_axi_awaddr_o (uart1_axi_awaddr),
      .local0_axi_awprot_o (uart1_axi_awprot),
      .local0_axi_awvalid_o(uart1_axi_awvalid),
      .local0_axi_awready_i(uart1_axi_awready),
      .local0_axi_wdata_o  (uart1_axi_wdata),
      .local0_axi_wstrb_o  (uart1_axi_wstrb),
      .local0_axi_wvalid_o (uart1_axi_wvalid),
      .local0_axi_wready_i (uart1_axi_wready),
      .local0_axi_bresp_i  (uart1_axi_bresp),
      .local0_axi_bvalid_i (uart1_axi_bvalid),
      .local0_axi_bready_o (uart1_axi_bready),
      .local0_axi_araddr_o (uart1_axi_araddr),
      .local0_axi_arprot_o (uart1_axi_arprot),
      .local0_axi_arvalid_o(uart1_axi_arvalid),
      .local0_axi_arready_i(uart1_axi_arready),
      .local0_axi_rdata_i  (uart1_axi_rdata),
      .local0_axi_rresp_i  (uart1_axi_rresp),
      .local0_axi_rvalid_i (uart1_axi_rvalid),
      .local0_axi_rready_o (uart1_axi_rready),
      .ext_axi_awaddr_o    (ai_csr_mux_axi_awaddr),
      .ext_axi_awprot_o    (ai_csr_mux_axi_awprot),
      .ext_axi_awvalid_o   (ai_csr_mux_axi_awvalid),
      .ext_axi_awready_i   (ai_csr_mux_axi_awready),
      .ext_axi_wdata_o     (ai_csr_mux_axi_wdata),
      .ext_axi_wstrb_o     (ai_csr_mux_axi_wstrb),
      .ext_axi_wvalid_o    (ai_csr_mux_axi_wvalid),
      .ext_axi_wready_i    (ai_csr_mux_axi_wready),
      .ext_axi_bresp_i     (ai_csr_mux_axi_bresp),
      .ext_axi_bvalid_i    (ai_csr_mux_axi_bvalid),
      .ext_axi_bready_o    (ai_csr_mux_axi_bready),
      .ext_axi_araddr_o    (ai_csr_mux_axi_araddr),
      .ext_axi_arprot_o    (ai_csr_mux_axi_arprot),
      .ext_axi_arvalid_o   (ai_csr_mux_axi_arvalid),
      .ext_axi_arready_i   (ai_csr_mux_axi_arready),
      .ext_axi_rdata_i     (ai_csr_mux_axi_rdata),
      .ext_axi_rresp_i     (ai_csr_mux_axi_rresp),
      .ext_axi_rvalid_i    (ai_csr_mux_axi_rvalid),
      .ext_axi_rready_o    (ai_csr_mux_axi_rready)
  );

  soc_axi_lite_uart uart1_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (uart1_axi_awaddr),
      .s_axi_awprot_i (uart1_axi_awprot),
      .s_axi_awvalid_i(uart1_axi_awvalid),
      .s_axi_awready_o(uart1_axi_awready),
      .s_axi_wdata_i  (uart1_axi_wdata),
      .s_axi_wstrb_i  (uart1_axi_wstrb),
      .s_axi_wvalid_i (uart1_axi_wvalid),
      .s_axi_wready_o (uart1_axi_wready),
      .s_axi_bresp_o  (uart1_axi_bresp),
      .s_axi_bvalid_o (uart1_axi_bvalid),
      .s_axi_bready_i (uart1_axi_bready),
      .s_axi_araddr_i (uart1_axi_araddr),
      .s_axi_arprot_i (uart1_axi_arprot),
      .s_axi_arvalid_i(uart1_axi_arvalid),
      .s_axi_arready_o(uart1_axi_arready),
      .s_axi_rdata_o  (uart1_axi_rdata),
      .s_axi_rresp_o  (uart1_axi_rresp),
      .s_axi_rvalid_o (uart1_axi_rvalid),
      .s_axi_rready_i (uart1_axi_rready),
      .uart_rx_i      (uart1_rx_i),
      .uart_tx_o      (uart1_tx_o)
  );

  soc_axi_lite_1x2 #(
      .LOCAL0_BASE_ADDR (SOC_AI_CSR_BASE_ADDR),
      .LOCAL0_SIZE_BYTES(SOC_AI_CSR_IMPL_BYTES)
  ) axi_ai_csr_mux_i (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .s_axi_awaddr_i      (ai_csr_mux_axi_awaddr),
      .s_axi_awprot_i      (ai_csr_mux_axi_awprot),
      .s_axi_awvalid_i     (ai_csr_mux_axi_awvalid),
      .s_axi_awready_o     (ai_csr_mux_axi_awready),
      .s_axi_wdata_i       (ai_csr_mux_axi_wdata),
      .s_axi_wstrb_i       (ai_csr_mux_axi_wstrb),
      .s_axi_wvalid_i      (ai_csr_mux_axi_wvalid),
      .s_axi_wready_o      (ai_csr_mux_axi_wready),
      .s_axi_bresp_o       (ai_csr_mux_axi_bresp),
      .s_axi_bvalid_o      (ai_csr_mux_axi_bvalid),
      .s_axi_bready_i      (ai_csr_mux_axi_bready),
      .s_axi_araddr_i      (ai_csr_mux_axi_araddr),
      .s_axi_arprot_i      (ai_csr_mux_axi_arprot),
      .s_axi_arvalid_i     (ai_csr_mux_axi_arvalid),
      .s_axi_arready_o     (ai_csr_mux_axi_arready),
      .s_axi_rdata_o       (ai_csr_mux_axi_rdata),
      .s_axi_rresp_o       (ai_csr_mux_axi_rresp),
      .s_axi_rvalid_o      (ai_csr_mux_axi_rvalid),
      .s_axi_rready_i      (ai_csr_mux_axi_rready),
      .local0_axi_awaddr_o (ai_csr_axi_awaddr),
      .local0_axi_awprot_o (ai_csr_axi_awprot),
      .local0_axi_awvalid_o(ai_csr_axi_awvalid),
      .local0_axi_awready_i(ai_csr_axi_awready),
      .local0_axi_wdata_o  (ai_csr_axi_wdata),
      .local0_axi_wstrb_o  (ai_csr_axi_wstrb),
      .local0_axi_wvalid_o (ai_csr_axi_wvalid),
      .local0_axi_wready_i (ai_csr_axi_wready),
      .local0_axi_bresp_i  (ai_csr_axi_bresp),
      .local0_axi_bvalid_i (ai_csr_axi_bvalid),
      .local0_axi_bready_o (ai_csr_axi_bready),
      .local0_axi_araddr_o (ai_csr_axi_araddr),
      .local0_axi_arprot_o (ai_csr_axi_arprot),
      .local0_axi_arvalid_o(ai_csr_axi_arvalid),
      .local0_axi_arready_i(ai_csr_axi_arready),
      .local0_axi_rdata_i  (ai_csr_axi_rdata),
      .local0_axi_rresp_i  (ai_csr_axi_rresp),
      .local0_axi_rvalid_i (ai_csr_axi_rvalid),
      .local0_axi_rready_o (ai_csr_axi_rready),
      .ext_axi_awaddr_o    (apb_axi_awaddr),
      .ext_axi_awprot_o    (apb_axi_awprot),
      .ext_axi_awvalid_o   (apb_axi_awvalid),
      .ext_axi_awready_i   (apb_axi_awready),
      .ext_axi_wdata_o     (apb_axi_wdata),
      .ext_axi_wstrb_o     (apb_axi_wstrb),
      .ext_axi_wvalid_o    (apb_axi_wvalid),
      .ext_axi_wready_i    (apb_axi_wready),
      .ext_axi_bresp_i     (apb_axi_bresp),
      .ext_axi_bvalid_i    (apb_axi_bvalid),
      .ext_axi_bready_o    (apb_axi_bready),
      .ext_axi_araddr_o    (apb_axi_araddr),
      .ext_axi_arprot_o    (apb_axi_arprot),
      .ext_axi_arvalid_o   (apb_axi_arvalid),
      .ext_axi_arready_i   (apb_axi_arready),
      .ext_axi_rdata_i     (apb_axi_rdata),
      .ext_axi_rresp_i     (apb_axi_rresp),
      .ext_axi_rvalid_i    (apb_axi_rvalid),
      .ext_axi_rready_o    (apb_axi_rready)
  );

  soc_ai_csr ai_csr_i (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .s_axi_awaddr_i        (ai_csr_axi_awaddr),
      .s_axi_awprot_i        (ai_csr_axi_awprot),
      .s_axi_awvalid_i       (ai_csr_axi_awvalid),
      .s_axi_awready_o       (ai_csr_axi_awready),
      .s_axi_wdata_i         (ai_csr_axi_wdata),
      .s_axi_wstrb_i         (ai_csr_axi_wstrb),
      .s_axi_wvalid_i        (ai_csr_axi_wvalid),
      .s_axi_wready_o        (ai_csr_axi_wready),
      .s_axi_bresp_o         (ai_csr_axi_bresp),
      .s_axi_bvalid_o        (ai_csr_axi_bvalid),
      .s_axi_bready_i        (ai_csr_axi_bready),
      .s_axi_araddr_i        (ai_csr_axi_araddr),
      .s_axi_arprot_i        (ai_csr_axi_arprot),
      .s_axi_arvalid_i       (ai_csr_axi_arvalid),
      .s_axi_arready_o       (ai_csr_axi_arready),
      .s_axi_rdata_o         (ai_csr_axi_rdata),
      .s_axi_rresp_o         (ai_csr_axi_rresp),
      .s_axi_rvalid_o        (ai_csr_axi_rvalid),
      .s_axi_rready_i        (ai_csr_axi_rready),
      .accel_start_o         (ai_accel_start),
      .uart_start_o          (ai_uart_start),
      .input_base_o          (ai_input_base),
      .input_len_o           (ai_input_len),
      .output_base_o         (ai_output_base),
      .uart_baud_div_o       (ai_uart_baud_div),
      .accel_busy_i          (ai_accel_busy),
      .accel_done_i          (ai_accel_done),
      .accel_result_class_i  (ai_result_class),
      .accel_result0_i       (ai_result0),
      .accel_result1_i       (ai_result1),
      .accel_result2_i       (ai_result2),
      .accel_result3_i       (ai_result3),
      .accel_cycle_count_i   (ai_cycle_count),
      .uart_active_i         (ai_uart_active),
      .uart_done_i           (ai_uart_done),
      .uart_error_i          (ai_uart_error),
      .uart_byte_count_i     (ai_uart_byte_count),
      .irq_o                 (ai_irq)
  );

  soc_axi_lite_apb_island #(
      .NO_APB_SLOTS(NO_APB_SLOTS)
  ) apb_island_i (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .s_axi_awaddr_i (apb_axi_awaddr),
      .s_axi_awprot_i (apb_axi_awprot),
      .s_axi_awvalid_i(apb_axi_awvalid),
      .s_axi_awready_o(apb_axi_awready),
      .s_axi_wdata_i  (apb_axi_wdata),
      .s_axi_wstrb_i  (apb_axi_wstrb),
      .s_axi_wvalid_i (apb_axi_wvalid),
      .s_axi_wready_o (apb_axi_wready),
      .s_axi_bresp_o  (apb_axi_bresp),
      .s_axi_bvalid_o (apb_axi_bvalid),
      .s_axi_bready_i (apb_axi_bready),
      .s_axi_araddr_i (apb_axi_araddr),
      .s_axi_arprot_i (apb_axi_arprot),
      .s_axi_arvalid_i(apb_axi_arvalid),
      .s_axi_arready_o(apb_axi_arready),
      .s_axi_rdata_o  (apb_axi_rdata),
      .s_axi_rresp_o  (apb_axi_rresp),
      .s_axi_rvalid_o (apb_axi_rvalid),
      .s_axi_rready_i (apb_axi_rready),
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

  soc_apb_qspi_cfg qspi_cfg_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .paddr_i         (apb_paddr[11:0]),
      .pwdata_i        (apb_pwdata),
      .pwrite_i        (apb_pwrite),
      .psel_i          (apb_psel[SOC_MMIO_QSPI_CFG]),
      .penable_i       (apb_penable),
      .prdata_o        (qspi_cfg_prdata),
      .pready_o        (qspi_cfg_pready),
      .pslverr_o       (qspi_cfg_pslverr),
      .boot_active_i   (boot_active),
      .boot_done_i     (boot_done),
      .boot_enable_i   (BOOT_COPY_XIP_ENABLE),
      .boot_copy_words_i(BOOT_COPY_WORDS),
      .xip_base_addr_i (soc_map_pkg::SOC_QSPI_XIP_BASE_ADDR),
      .imem_base_addr_i(soc_map_pkg::SOC_IMEM_BASE_ADDR),
      .flash_busy_i    (qspi_flash_busy),
      .flash_init_done_i(qspi_flash_init_done),
      .init_active_i   (qspi_init_active),
      .init_done_i     (qspi_init_done),
      .init_error_i    (qspi_init_error),
      .init_step_i     (qspi_init_step),
      .init_error_code_i(qspi_init_error_code),
      .init_last_rsp_i (qspi_init_last_rsp),
      .cfg_cmd_valid_o (qspi_sw_cmd_valid),
      .cfg_cmd_data_o  (qspi_sw_cmd_data),
      .cfg_cmd_ready_i (qspi_sw_cmd_ready),
      .cfg_rsp_valid_i (qspi_sw_rsp_valid),
      .cfg_rsp_data_i  (qspi_sw_rsp_data)
  );

  soc_apb_gpio gpio_i (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .paddr_i       (apb_paddr[11:0]),
      .pwdata_i      (apb_pwdata),
      .pwrite_i      (apb_pwrite),
      .psel_i        (apb_psel[SOC_MMIO_GPIO]),
      .penable_i     (apb_penable),
      .prdata_o      (gpio_prdata),
      .pready_o      (gpio_pready),
      .pslverr_o     (gpio_pslverr),
      .gpio_in_i     (gpio_in_i),
      .gpio_in_sync_o(gpio_in_sync),
      .gpio_out_o    (gpio_out_o),
      .gpio_dir_o    (gpio_dir_o),
      .gpio_irq_o    (gpio_irq_o)
  );

  soc_apb_timer timer_i (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .paddr_i          (apb_paddr[11:0]),
      .pwdata_i         (apb_pwdata),
      .pwrite_i         (apb_pwrite),
      .psel_i           (apb_psel[SOC_MMIO_TIMER]),
      .penable_i        (apb_penable),
      .prdata_o         (timer_prdata),
      .pready_o         (timer_pready),
      .pslverr_o        (timer_pslverr),
      .timer_ref_clk_i  (timer_ref_clk_i),
      .timer_stoptimer_i(timer_stoptimer_i),
      .timer_event_lo_i (timer_event_lo_i),
      .timer_event_hi_i (timer_event_hi_i),
      .timer_irq_lo_o   (timer_irq_lo_o),
      .timer_irq_hi_o   (timer_irq_hi_o),
      .timer_busy_o     (timer_busy_o)
  );

  soc_apb_i2c_master i2c_i (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .paddr_i      (apb_paddr[11:0]),
      .pwdata_i     (apb_pwdata),
      .pwrite_i     (apb_pwrite),
      .psel_i       (apb_psel[SOC_MMIO_I2C]),
      .penable_i    (apb_penable),
      .prdata_o     (i2c_prdata),
      .pready_o     (i2c_pready),
      .pslverr_o    (i2c_pslverr),
      .i2c_sda_i    (i2c_sda_i),
      .i2c_scl_o    (i2c_scl_o),
      .i2c_scl_oe_o (i2c_scl_oe_o),
      .i2c_sda_o    (i2c_sda_o),
      .i2c_sda_oe_o (i2c_sda_oe_o)
  );

  always_comb begin
    for (apb_idx = 0; apb_idx < NO_APB_SLOTS; apb_idx = apb_idx + 1) begin
      apb_prdata[apb_idx]  = '0;
      apb_pready[apb_idx]  = 1'b1;
      apb_pslverr[apb_idx] = 1'b1;
    end

    apb_prdata[SOC_MMIO_QSPI_CFG]  = qspi_cfg_prdata;
    apb_pready[SOC_MMIO_QSPI_CFG]  = qspi_cfg_pready;
    apb_pslverr[SOC_MMIO_QSPI_CFG] = qspi_cfg_pslverr;
    apb_prdata[SOC_MMIO_GPIO]  = gpio_prdata;
    apb_pready[SOC_MMIO_GPIO]  = gpio_pready;
    apb_pslverr[SOC_MMIO_GPIO] = gpio_pslverr;
    apb_prdata[SOC_MMIO_TIMER]  = timer_prdata;
    apb_pready[SOC_MMIO_TIMER]  = timer_pready;
    apb_pslverr[SOC_MMIO_TIMER] = timer_pslverr;
    apb_prdata[SOC_MMIO_I2C]  = i2c_prdata;
    apb_pready[SOC_MMIO_I2C]  = i2c_pready;
    apb_pslverr[SOC_MMIO_I2C] = i2c_pslverr;
  end

endmodule
