`timescale 1ns/1ps

module tb_soc_map_pkg;

  import soc_map_pkg::*;

  integer i;
  integer j;
  soc_region_t region_i;
  soc_region_t region_j;

  initial begin
    for (i = 0; i < SOC_REGION_COUNT; i = i + 1) begin
      region_i = soc_region(i);

      if (!soc_is_pow2(region_i.window_bytes)) begin
        $display("tb_soc_map_pkg: non power-of-two window at region %0d", i);
        $fatal(1);
      end

      if (!soc_region_aligned(region_i)) begin
        $display("tb_soc_map_pkg: misaligned base at region %0d", i);
        $fatal(1);
      end

      if (region_i.implemented_bytes > region_i.window_bytes) begin
        $display("tb_soc_map_pkg: implemented size exceeds window at region %0d", i);
        $fatal(1);
      end
    end

    for (i = 0; i < SOC_REGION_COUNT; i = i + 1) begin
      region_i = soc_region(i);
      for (j = i + 1; j < SOC_REGION_COUNT; j = j + 1) begin
        region_j = soc_region(j);
        if (soc_region_overlap(region_i, region_j)) begin
          $display("tb_soc_map_pkg: overlap between regions %0d and %0d", i, j);
          $fatal(1);
        end
      end
    end

    $display("tb_soc_map_pkg: PASS");
    $finish;
  end

endmodule
