package soc_map_pkg;

  typedef struct packed {
    logic [31:0] base_addr;
    logic [31:0] window_bytes;
    logic [31:0] implemented_bytes;
  } soc_region_t;

  localparam logic [31:0] SOC_ROM_BASE_ADDR     = 32'h0000_0000;
  localparam logic [31:0] SOC_ROM_WINDOW_BYTES  = 32'h0000_1000;
  localparam logic [31:0] SOC_ROM_IMPL_BYTES    = 32'h0000_1000;

  localparam logic [31:0] SOC_IMEM_BASE_ADDR    = 32'h0001_0000;
  localparam logic [31:0] SOC_IMEM_WINDOW_BYTES = 32'h0000_2000;
  localparam logic [31:0] SOC_IMEM_IMPL_BYTES   = 32'h0000_2000;

  localparam logic [31:0] SOC_DMEM_BASE_ADDR    = 32'h0002_0000;
  localparam logic [31:0] SOC_DMEM_WINDOW_BYTES = 32'h0000_2000;
  localparam logic [31:0] SOC_DMEM_IMPL_BYTES   = 32'h0000_2000;

  localparam logic [31:0] SOC_MMIO_BASE_ADDR    = 32'h1000_0000;
  localparam logic [31:0] SOC_MMIO_SLOT_BYTES   = 32'h0000_1000;
  localparam int unsigned SOC_MMIO_SLOT_COUNT   = 16;

  typedef enum int unsigned {
    SOC_MMIO_QSPI_CFG   = 0,
    SOC_MMIO_GPIO       = 1,
    SOC_MMIO_TIMER      = 2,
    SOC_MMIO_I2C        = 3,
    SOC_MMIO_UART0      = 4,
    SOC_MMIO_UART1      = 5,
    SOC_MMIO_AI_CSR     = 6,
    SOC_MMIO_RESERVED7  = 7,
    SOC_MMIO_RESERVED8  = 8,
    SOC_MMIO_RESERVED9  = 9
  } soc_mmio_slot_e;

  function automatic logic [31:0] soc_mmio_base(input int unsigned slot);
    return SOC_MMIO_BASE_ADDR + (slot * SOC_MMIO_SLOT_BYTES);
  endfunction

  localparam logic [31:0] SOC_QSPI_CFG_BASE_ADDR = soc_mmio_base(SOC_MMIO_QSPI_CFG);
  localparam logic [31:0] SOC_GPIO_BASE_ADDR     = soc_mmio_base(SOC_MMIO_GPIO);
  localparam logic [31:0] SOC_TIMER_BASE_ADDR    = soc_mmio_base(SOC_MMIO_TIMER);
  localparam logic [31:0] SOC_I2C_BASE_ADDR      = soc_mmio_base(SOC_MMIO_I2C);
  localparam logic [31:0] SOC_UART0_BASE_ADDR    = soc_mmio_base(SOC_MMIO_UART0);
  localparam logic [31:0] SOC_UART1_BASE_ADDR    = soc_mmio_base(SOC_MMIO_UART1);
  localparam logic [31:0] SOC_AI_CSR_BASE_ADDR   = soc_mmio_base(SOC_MMIO_AI_CSR);

  localparam logic [31:0] SOC_QSPI_CFG_WINDOW_BYTES = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_GPIO_WINDOW_BYTES     = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_TIMER_WINDOW_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_I2C_WINDOW_BYTES      = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_UART0_WINDOW_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_UART1_WINDOW_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_AI_CSR_WINDOW_BYTES   = SOC_MMIO_SLOT_BYTES;

  localparam logic [31:0] SOC_QSPI_CFG_IMPL_BYTES = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_GPIO_IMPL_BYTES     = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_TIMER_IMPL_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_I2C_IMPL_BYTES      = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_UART0_IMPL_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_UART1_IMPL_BYTES    = SOC_MMIO_SLOT_BYTES;
  localparam logic [31:0] SOC_AI_CSR_IMPL_BYTES   = SOC_MMIO_SLOT_BYTES;

  localparam logic [31:0] SOC_AI_MEM_BASE_ADDR     = 32'h2000_0000;
  localparam logic [31:0] SOC_AI_MEM_WINDOW_BYTES  = 32'h0000_8000;
  localparam logic [31:0] SOC_AI_MEM_IMPL_BYTES    = 32'h0000_7800;

  localparam logic [31:0] SOC_QSPI_XIP_BASE_ADDR   = 32'h3000_0000;
  localparam logic [31:0] SOC_QSPI_XIP_WINDOW_BYTES = 32'h0100_0000;
  localparam logic [31:0] SOC_QSPI_XIP_IMPL_BYTES   = 32'h0100_0000;

  // Simulation-only external scratch window used by SoC smoke tests.
  localparam logic [31:0] SOC_EXT_TEST_BASE_ADDR   = 32'h4000_0000;
  localparam logic [31:0] SOC_EXT_TEST_STATUS_ADDR = SOC_EXT_TEST_BASE_ADDR + 32'h0000_0004;

  localparam int unsigned SOC_IRQ_MSI_BIT           = 3;
  localparam int unsigned SOC_IRQ_MTI_BIT           = 7;
  localparam int unsigned SOC_IRQ_MEI_BIT           = 11;
  localparam int unsigned SOC_IRQ_FAST_TIMER_HI_BIT = 16;
  localparam int unsigned SOC_IRQ_FAST_UART0_BIT    = 17;
  localparam int unsigned SOC_IRQ_FAST_UART1_BIT    = 18;
  localparam int unsigned SOC_IRQ_FAST_AI_BIT       = 19;

  localparam int unsigned SOC_REGION_COUNT = 12;

  function automatic soc_region_t soc_region(input int unsigned idx);
    unique case (idx)
      0: begin
        soc_region.base_addr = SOC_ROM_BASE_ADDR;
        soc_region.window_bytes = SOC_ROM_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_ROM_IMPL_BYTES;
      end
      1: begin
        soc_region.base_addr = SOC_IMEM_BASE_ADDR;
        soc_region.window_bytes = SOC_IMEM_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_IMEM_IMPL_BYTES;
      end
      2: begin
        soc_region.base_addr = SOC_DMEM_BASE_ADDR;
        soc_region.window_bytes = SOC_DMEM_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_DMEM_IMPL_BYTES;
      end
      3: begin
        soc_region.base_addr = SOC_QSPI_CFG_BASE_ADDR;
        soc_region.window_bytes = SOC_QSPI_CFG_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_QSPI_CFG_IMPL_BYTES;
      end
      4: begin
        soc_region.base_addr = SOC_GPIO_BASE_ADDR;
        soc_region.window_bytes = SOC_GPIO_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_GPIO_IMPL_BYTES;
      end
      5: begin
        soc_region.base_addr = SOC_TIMER_BASE_ADDR;
        soc_region.window_bytes = SOC_TIMER_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_TIMER_IMPL_BYTES;
      end
      6: begin
        soc_region.base_addr = SOC_I2C_BASE_ADDR;
        soc_region.window_bytes = SOC_I2C_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_I2C_IMPL_BYTES;
      end
      7: begin
        soc_region.base_addr = SOC_UART0_BASE_ADDR;
        soc_region.window_bytes = SOC_UART0_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_UART0_IMPL_BYTES;
      end
      8: begin
        soc_region.base_addr = SOC_UART1_BASE_ADDR;
        soc_region.window_bytes = SOC_UART1_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_UART1_IMPL_BYTES;
      end
      9: begin
        soc_region.base_addr = SOC_AI_CSR_BASE_ADDR;
        soc_region.window_bytes = SOC_AI_CSR_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_AI_CSR_IMPL_BYTES;
      end
      10: begin
        soc_region.base_addr = SOC_AI_MEM_BASE_ADDR;
        soc_region.window_bytes = SOC_AI_MEM_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_AI_MEM_IMPL_BYTES;
      end
      11: begin
        soc_region.base_addr = SOC_QSPI_XIP_BASE_ADDR;
        soc_region.window_bytes = SOC_QSPI_XIP_WINDOW_BYTES;
        soc_region.implemented_bytes = SOC_QSPI_XIP_IMPL_BYTES;
      end
      default: begin
        soc_region.base_addr = 32'h0;
        soc_region.window_bytes = 32'h0;
        soc_region.implemented_bytes = 32'h0;
      end
    endcase
  endfunction

  function automatic bit soc_is_pow2(input logic [31:0] value);
    return (value != 32'h0) && ((value & (value - 1'b1)) == 32'h0);
  endfunction

  function automatic bit soc_region_aligned(input soc_region_t region);
    return (region.window_bytes != 32'h0) &&
           ((region.base_addr & (region.window_bytes - 1'b1)) == 32'h0);
  endfunction

  function automatic logic [32:0] soc_region_end(input soc_region_t region);
    return {1'b0, region.base_addr} + {1'b0, region.window_bytes} - 33'd1;
  endfunction

  function automatic bit soc_region_overlap(
      input soc_region_t lhs,
      input soc_region_t rhs
  );
    logic [32:0] lhs_end;
    logic [32:0] rhs_end;
    begin
      lhs_end = soc_region_end(lhs);
      rhs_end = soc_region_end(rhs);
      return !((lhs_end < {1'b0, rhs.base_addr}) || (rhs_end < {1'b0, lhs.base_addr}));
    end
  endfunction

  function automatic bit soc_addr_in_region(
      input logic [31:0] addr,
      input soc_region_t region
  );
    return ({1'b0, addr} >= {1'b0, region.base_addr}) &&
           ({1'b0, addr} <= soc_region_end(region));
  endfunction

endpackage
