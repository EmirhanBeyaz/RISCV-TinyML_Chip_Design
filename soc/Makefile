SIM ?= iverilog
SIMFLAGS ?= -g2012
RUN ?= vvp
BUILD_DIR ?= build
AI_PYTHON ?= python3
AI_MODEL_SMOKE_DIR ?= $(BUILD_DIR)/ai_model_tool_smoke
AI_MODEL_PKG ?= $(AI_MODEL_SMOKE_DIR)/soc_ai_model_pkg.sv
AI_MODEL_GOLDEN_PKG ?= $(AI_MODEL_SMOKE_DIR)/soc_ai_model_smoke_golden_pkg.sv
AI_MODEL_FULL_GOLDEN_PKG ?= $(AI_MODEL_SMOKE_DIR)/soc_ai_model_golden_pkg.sv
AI_MODEL_INPUT_MEMH ?= $(AI_MODEL_SMOKE_DIR)/smoke_input_vector.memh
TFLM_MICRO_SPEECH_DIR ?= $(BUILD_DIR)/tflm_micro_speech
TFLM_MICRO_SPEECH_MODEL ?= $(TFLM_MICRO_SPEECH_DIR)/models/micro_speech_quantized.tflite
TFLM_MICRO_SPEECH_OUT ?= $(BUILD_DIR)/ai_model_tflm_micro_speech
TFLM_MICRO_SPEECH_PKG ?= $(TFLM_MICRO_SPEECH_OUT)/soc_ai_model_pkg.sv
TFLM_MICRO_SPEECH_GOLDEN_PKG ?= $(TFLM_MICRO_SPEECH_OUT)/soc_ai_model_smoke_golden_pkg.sv
TFLM_MICRO_SPEECH_INPUT_MEMH ?= $(TFLM_MICRO_SPEECH_OUT)/smoke_input_vector.memh
TFLM_MICRO_SPEECH_YES_WAV ?= $(TFLM_MICRO_SPEECH_DIR)/testdata/yes_1000ms.wav
AI_FEATURE_PAYLOAD_DIR ?= $(BUILD_DIR)/ai_feature_payload
AI_FEATURE_PAYLOAD_NPY ?= $(AI_FEATURE_PAYLOAD_DIR)/demo_silence_1960_int8.npy
AI_FEATURE_PAYLOAD_BIN ?= $(AI_FEATURE_PAYLOAD_DIR)/demo_silence_1960_int8.bin
AI_UART_PACKET_DIR ?= $(BUILD_DIR)/ai_uart_packet
AI_WAV_FEATURE_DIR ?= $(BUILD_DIR)/ai_wav_feature
AI_WAV_FEATURE_NPY ?= $(AI_WAV_FEATURE_DIR)/yes_1000ms_1960_int8.npy
VERILATOR ?= verilator
VERILATOR_FLAGS ?= --binary --timing -Wno-fatal -Wno-TIMESCALEMOD -Wno-BLKANDNBLK -Wno-UNOPTFLAT -Wno-COMBDLY -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-BLKSEQ

.DEFAULT_GOAL := all

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

SOC_MEM_RTL := soc_mem_sp.sv soc_imem.sv soc_axi_lite_imem.sv soc_dmem.sv soc_rom.sv
SOC_VENDOR_RTL := \
	third_party/uart/rtl/uart/uart_tx.v \
	third_party/uart/rtl/uart/uart_rx.v \
	third_party/peripherals/rtl/apb_gpio/rtl/apb_gpio.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/apb_timer_unit.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit_counter.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit_counter_presc.sv
SOC_QSPI_ZIPCPU_RTL := \
	soc_qspi_xip.sv \
	soc_axi_lite_qspi_xip.sv \
	third_party/qspi_xip/rtl/qflexpress.v
SOC_COMMON_RTL := \
	soc_map_pkg.sv soc_irq_router.sv cv32e40p_obi_to_axi_lite.sv soc_axi_lite_1x2.sv \
	$(SOC_QSPI_ZIPCPU_RTL) \
	soc_qspi_init_seq.sv soc_qspi_cfg_mux.sv \
	soc_ai_mem.sv soc_ai_uart_loader.sv soc_ai_csr.sv soc_ai_tinyconv_accel.sv \
	soc_axi_lite_uart.sv soc_axi_lite_apb_island.sv soc_apb_qspi_cfg.sv soc_apb_gpio.sv \
	soc_boot_copy_xip.sv soc_apb_i2c_master.sv \
	soc_apb_timer.sv $(SOC_MEM_RTL)
SOC_TOP_RTL := $(SOC_COMMON_RTL) $(SOC_VENDOR_RTL) cv32e40p_axi_soc.sv
SOC_INC_FLAGS := -Ithird_party/uart/rtl -Ithird_party/peripherals/rtl/includes

.PHONY: bridge-smoke
bridge-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_cv32e40p_obi_to_axi_lite \
	-o $(BUILD_DIR)/tb_cv32e40p_obi_to_axi_lite.vvp \
	cv32e40p_obi_to_axi_lite.sv tb_cv32e40p_obi_to_axi_lite.sv
	$(RUN) $(BUILD_DIR)/tb_cv32e40p_obi_to_axi_lite.vvp

.PHONY: map-check
map-check: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_map_pkg \
	-o $(BUILD_DIR)/tb_soc_map_pkg.vvp \
	soc_map_pkg.sv tb_soc_map_pkg.sv
	$(RUN) $(BUILD_DIR)/tb_soc_map_pkg.vvp

.PHONY: imem-smoke
imem-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_imem \
	-o $(BUILD_DIR)/tb_soc_imem.vvp \
	soc_map_pkg.sv soc_mem_sp.sv soc_imem.sv tb_soc_imem.sv
	$(RUN) $(BUILD_DIR)/tb_soc_imem.vvp

.PHONY: imem-axi-smoke
imem-axi-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_axi_lite_imem \
	-o $(BUILD_DIR)/tb_soc_axi_lite_imem.vvp \
	soc_map_pkg.sv soc_mem_sp.sv soc_imem.sv soc_axi_lite_imem.sv tb_soc_axi_lite_imem.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_imem.vvp

.PHONY: boot-copy-smoke
boot-copy-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_boot_copy \
	-Mdir $(BUILD_DIR)/soc_boot_copy \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_boot_copy.sv
	./$(BUILD_DIR)/soc_boot_copy/Vtb_cv32e40p_axi_soc_boot_copy

.PHONY: dmem-smoke
dmem-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_dmem \
	-o $(BUILD_DIR)/tb_soc_dmem.vvp \
	soc_map_pkg.sv soc_mem_sp.sv soc_dmem.sv tb_soc_dmem.sv
	$(RUN) $(BUILD_DIR)/tb_soc_dmem.vvp

.PHONY: rom-smoke
rom-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_rom \
	-o $(BUILD_DIR)/tb_soc_rom.vvp \
	soc_map_pkg.sv soc_mem_sp.sv soc_rom.sv tb_soc_rom.sv
	$(RUN) $(BUILD_DIR)/tb_soc_rom.vvp

.PHONY: irq-router-smoke
irq-router-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_irq_router \
	-o $(BUILD_DIR)/tb_soc_irq_router.vvp \
	soc_map_pkg.sv soc_irq_router.sv tb_soc_irq_router.sv
	$(RUN) $(BUILD_DIR)/tb_soc_irq_router.vvp

.PHONY: wrapper-smoke
wrapper-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_stub \
	-Mdir $(BUILD_DIR)/soc_stub \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) tb_cv32e40p_axi_soc_stub.sv
	./$(BUILD_DIR)/soc_stub/Vtb_cv32e40p_axi_soc_stub

.PHONY: soc-e2e
soc-e2e: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_e2e \
	-Mdir $(BUILD_DIR)/soc_e2e \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_e2e.sv
	./$(BUILD_DIR)/soc_e2e/Vtb_cv32e40p_axi_soc_e2e

.PHONY: apb-island-smoke
apb-island-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_axi_lite_apb_timer \
	-o $(BUILD_DIR)/tb_soc_axi_lite_apb_timer.vvp \
	soc_map_pkg.sv soc_axi_lite_apb_island.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/apb_timer_unit.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit_counter.sv \
	third_party/peripherals/rtl/apb_timer_unit/rtl/timer_unit_counter_presc.sv \
	tb_soc_axi_lite_apb_timer.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_apb_timer.vvp

.PHONY: qspi-cfg-smoke
qspi-cfg-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_axi_lite_apb_qspi_cfg \
	-o $(BUILD_DIR)/tb_soc_axi_lite_apb_qspi_cfg.vvp \
	soc_map_pkg.sv soc_axi_lite_apb_island.sv soc_apb_qspi_cfg.sv \
	tb_soc_axi_lite_apb_qspi_cfg.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_apb_qspi_cfg.vvp

.PHONY: qspi-init-smoke
qspi-init-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_qspi_init_seq \
	-o $(BUILD_DIR)/tb_soc_qspi_init_seq.vvp \
	soc_qspi_init_seq.sv tb_soc_qspi_init_seq.sv
	$(RUN) $(BUILD_DIR)/tb_soc_qspi_init_seq.vvp

.PHONY: qspi-xip-smoke
qspi-xip-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_soc_axi_lite_qspi_xip \
	-Mdir $(BUILD_DIR)/qspi_xip \
	$(SOC_QSPI_ZIPCPU_RTL) tb_soc_axi_lite_qspi_xip.sv
	./$(BUILD_DIR)/qspi_xip/Vtb_soc_axi_lite_qspi_xip

.PHONY: apb-gpio-smoke
apb-gpio-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -I third_party/peripherals/rtl/includes -s tb_soc_axi_lite_apb_gpio \
	-o $(BUILD_DIR)/tb_soc_axi_lite_apb_gpio.vvp \
	soc_map_pkg.sv soc_axi_lite_apb_island.sv \
	third_party/peripherals/rtl/apb_gpio/rtl/apb_gpio.sv \
	tb_soc_axi_lite_apb_gpio.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_apb_gpio.vvp

.PHONY: i2c-smoke
i2c-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_axi_lite_apb_i2c_master \
	-o $(BUILD_DIR)/tb_soc_axi_lite_apb_i2c_master.vvp \
	soc_map_pkg.sv soc_axi_lite_apb_island.sv soc_apb_i2c_master.sv \
	tb_soc_axi_lite_apb_i2c_master.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_apb_i2c_master.vvp

.PHONY: uart-smoke
uart-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -I third_party/uart/rtl -s tb_soc_axi_lite_uart \
	-o $(BUILD_DIR)/tb_soc_axi_lite_uart.vvp \
	soc_map_pkg.sv soc_axi_lite_uart.sv \
	third_party/uart/rtl/uart/uart_tx.v \
	third_party/uart/rtl/uart/uart_rx.v \
	tb_soc_axi_lite_uart.sv
	$(RUN) $(BUILD_DIR)/tb_soc_axi_lite_uart.vvp

.PHONY: ai-mem-smoke
ai-mem-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_ai_mem \
	-o $(BUILD_DIR)/tb_soc_ai_mem.vvp \
	soc_map_pkg.sv soc_mem_sp.sv soc_ai_mem.sv tb_soc_ai_mem.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_mem.vvp

.PHONY: ai-csr-smoke
ai-csr-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_ai_csr \
	-o $(BUILD_DIR)/tb_soc_ai_csr.vvp \
	soc_map_pkg.sv soc_ai_csr.sv tb_soc_ai_csr.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_csr.vvp

.PHONY: ai-uart-loader-smoke
ai-uart-loader-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -I third_party/uart/rtl -s tb_soc_ai_uart_loader \
	-o $(BUILD_DIR)/tb_soc_ai_uart_loader.vvp \
	soc_map_pkg.sv third_party/uart/rtl/uart/uart_rx.v soc_ai_uart_loader.sv tb_soc_ai_uart_loader.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_uart_loader.vvp

.PHONY: ai-accel-smoke
ai-accel-smoke: $(BUILD_DIR)
	$(SIM) $(SIMFLAGS) -s tb_soc_ai_tinyconv_accel \
	-o $(BUILD_DIR)/tb_soc_ai_tinyconv_accel.vvp \
	soc_map_pkg.sv soc_ai_tinyconv_accel.sv tb_soc_ai_tinyconv_accel.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_tinyconv_accel.vvp

.PHONY: ai-accel-model-smoke
ai-accel-model-smoke: ai-model-tool-smoke
	$(SIM) $(SIMFLAGS) -DSOC_AI_USE_MODEL_PKG -s tb_soc_ai_tinyconv_accel_model \
	-o $(BUILD_DIR)/tb_soc_ai_tinyconv_accel_model.vvp \
	soc_map_pkg.sv $(AI_MODEL_PKG) $(AI_MODEL_GOLDEN_PKG) \
	soc_ai_tinyconv_accel.sv tb_soc_ai_tinyconv_accel_model.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_tinyconv_accel_model.vvp +input_memh=$(AI_MODEL_INPUT_MEMH)

.PHONY: ai-island-e2e-smoke
ai-island-e2e-smoke: ai-model-tool-smoke
	$(SIM) $(SIMFLAGS) -DSOC_AI_USE_MODEL_PKG -s tb_soc_ai_island_e2e \
	-o $(BUILD_DIR)/tb_soc_ai_island_e2e.vvp \
	soc_map_pkg.sv $(AI_MODEL_PKG) $(AI_MODEL_GOLDEN_PKG) \
	soc_mem_sp.sv soc_ai_mem.sv soc_ai_csr.sv soc_ai_tinyconv_accel.sv \
	tb_soc_ai_island_e2e.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_island_e2e.vvp

.PHONY: ai-uart-to-accel-e2e-smoke
ai-uart-to-accel-e2e-smoke: ai-model-tool-smoke
	$(SIM) $(SIMFLAGS) -DSOC_AI_USE_MODEL_PKG -DSOC_AI_E2E_USE_UART \
	-I third_party/uart/rtl -s tb_soc_ai_island_e2e \
	-o $(BUILD_DIR)/tb_soc_ai_uart_to_accel_e2e.vvp \
	soc_map_pkg.sv $(AI_MODEL_PKG) $(AI_MODEL_GOLDEN_PKG) \
	soc_mem_sp.sv soc_ai_mem.sv soc_ai_csr.sv \
	third_party/uart/rtl/uart/uart_rx.v soc_ai_uart_loader.sv \
	soc_ai_tinyconv_accel.sv tb_soc_ai_island_e2e.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_uart_to_accel_e2e.vvp

.PHONY: ai-smoke
ai-smoke: ai-mem-smoke ai-csr-smoke ai-uart-loader-smoke ai-accel-smoke \
	ai-model-tool-smoke ai-accel-model-smoke ai-island-e2e-smoke \
	ai-uart-to-accel-e2e-smoke

.PHONY: ai-model-tool-smoke
ai-model-tool-smoke: $(BUILD_DIR)
	$(AI_PYTHON) tools/ai/export_tinyconv_assets.py \
		--self-test \
		--out-dir $(AI_MODEL_SMOKE_DIR) \
		--sv-out $(AI_MODEL_PKG) \
		--golden-sv-out $(AI_MODEL_FULL_GOLDEN_PKG)

.PHONY: ai-model-tflite-smoke
ai-model-tflite-smoke: $(BUILD_DIR)
	$(AI_PYTHON) tools/ai/make_synthetic_tinyconv_tflite.py \
		--out-dir $(BUILD_DIR)/ai_model_tflite_smoke
	$(AI_PYTHON) tools/ai/export_tinyconv_assets.py \
		--model-tflite $(BUILD_DIR)/ai_model_tflite_smoke/synthetic_tinyconv_int8.tflite \
		--input-npy $(BUILD_DIR)/ai_model_tflite_smoke/input_1960_int8.npy \
		--out-dir $(BUILD_DIR)/ai_model_tflite_smoke/extracted \
		--sv-out $(BUILD_DIR)/ai_model_tflite_smoke/extracted/soc_ai_model_pkg.sv

.PHONY: ai-feature-payload-demo
ai-feature-payload-demo: $(BUILD_DIR)
	$(AI_PYTHON) tools/ai/prepare_feature_payload.py \
		--demo silence \
		--out-dir $(AI_FEATURE_PAYLOAD_DIR) \
		--name demo_silence

.PHONY: ai-uart-packet-demo
ai-uart-packet-demo: ai-feature-payload-demo
	$(AI_PYTHON) tools/ai/pack_uart_payload.py \
		--input $(AI_FEATURE_PAYLOAD_BIN) \
		--out-dir $(AI_UART_PACKET_DIR) \
		--name demo_silence

.PHONY: ai-audio-assets-fetch
ai-audio-assets-fetch: $(BUILD_DIR)
	$(AI_PYTHON) tools/ai/fetch_tflm_micro_speech.py \
		--out-dir $(TFLM_MICRO_SPEECH_DIR) \
		--include-preprocessor \
		--include-testdata

.PHONY: ai-wav-feature-demo
ai-wav-feature-demo: ai-audio-assets-fetch
	$(AI_PYTHON) tools/ai/wav_to_feature_payload.py \
		--wav $(TFLM_MICRO_SPEECH_YES_WAV) \
		--out-dir $(AI_WAV_FEATURE_DIR) \
		--name yes_1000ms

.PHONY: ai-model-tflm-fetch
ai-model-tflm-fetch: $(BUILD_DIR)
	$(AI_PYTHON) tools/ai/fetch_tflm_micro_speech.py \
		--out-dir $(TFLM_MICRO_SPEECH_DIR)

.PHONY: ai-model-tflm-export
ai-model-tflm-export: ai-model-tflm-fetch
	$(AI_PYTHON) tools/ai/export_tinyconv_assets.py \
		--model-tflite $(TFLM_MICRO_SPEECH_MODEL) \
		--out-dir $(TFLM_MICRO_SPEECH_OUT) \
		--sv-out $(TFLM_MICRO_SPEECH_PKG)

.PHONY: ai-model-tflm-demo-golden
ai-model-tflm-demo-golden: ai-model-tflm-fetch ai-feature-payload-demo
	$(AI_PYTHON) tools/ai/export_tinyconv_assets.py \
		--model-tflite $(TFLM_MICRO_SPEECH_MODEL) \
		--input-npy $(AI_FEATURE_PAYLOAD_NPY) \
		--out-dir $(BUILD_DIR)/ai_model_tflm_demo_golden \
		--sv-out $(BUILD_DIR)/ai_model_tflm_demo_golden/soc_ai_model_pkg.sv

.PHONY: ai-model-tflm-wav-demo-golden
ai-model-tflm-wav-demo-golden: ai-model-tflm-fetch ai-wav-feature-demo
	$(AI_PYTHON) tools/ai/export_tinyconv_assets.py \
		--model-tflite $(TFLM_MICRO_SPEECH_MODEL) \
		--input-npy $(AI_WAV_FEATURE_NPY) \
		--out-dir $(BUILD_DIR)/ai_model_tflm_wav_demo_golden \
		--sv-out $(BUILD_DIR)/ai_model_tflm_wav_demo_golden/soc_ai_model_pkg.sv

.PHONY: ai-accel-tflm-full-smoke
ai-accel-tflm-full-smoke: ai-model-tflm-demo-golden
	$(VERILATOR) $(VERILATOR_FLAGS) -DSOC_AI_USE_MODEL_PKG \
		--top-module tb_soc_ai_tinyconv_accel_full_model \
		-Mdir $(BUILD_DIR)/ai_accel_tflm_full \
		soc_map_pkg.sv \
		$(BUILD_DIR)/ai_model_tflm_demo_golden/soc_ai_model_pkg.sv \
		$(BUILD_DIR)/ai_model_tflm_demo_golden/soc_ai_model_golden_pkg.sv \
		soc_ai_tinyconv_accel.sv tb_soc_ai_tinyconv_accel_full_model.sv
	./$(BUILD_DIR)/ai_accel_tflm_full/Vtb_soc_ai_tinyconv_accel_full_model \
		+input_memh=$(BUILD_DIR)/ai_model_tflm_demo_golden/input_vector.memh

.PHONY: ai-accel-tflm-smoke
ai-accel-tflm-smoke: ai-model-tflm-export
	$(SIM) $(SIMFLAGS) -DSOC_AI_USE_MODEL_PKG -s tb_soc_ai_tinyconv_accel_model \
		-o $(BUILD_DIR)/tb_soc_ai_tinyconv_accel_tflm_model.vvp \
		soc_map_pkg.sv $(TFLM_MICRO_SPEECH_PKG) $(TFLM_MICRO_SPEECH_GOLDEN_PKG) \
		soc_ai_tinyconv_accel.sv tb_soc_ai_tinyconv_accel_model.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_tinyconv_accel_tflm_model.vvp +input_memh=$(TFLM_MICRO_SPEECH_INPUT_MEMH)

.PHONY: ai-tflm-smoke
ai-tflm-smoke: ai-model-tflm-export ai-accel-tflm-smoke ai-island-tflm-smoke

.PHONY: ai-island-tflm-smoke
ai-island-tflm-smoke: ai-model-tflm-export
	$(SIM) $(SIMFLAGS) -DSOC_AI_USE_MODEL_PKG -s tb_soc_ai_island_e2e \
		-o $(BUILD_DIR)/tb_soc_ai_island_tflm_e2e.vvp \
		soc_map_pkg.sv $(TFLM_MICRO_SPEECH_PKG) $(TFLM_MICRO_SPEECH_GOLDEN_PKG) \
		soc_mem_sp.sv soc_ai_mem.sv soc_ai_csr.sv soc_ai_tinyconv_accel.sv \
		tb_soc_ai_island_e2e.sv
	$(RUN) $(BUILD_DIR)/tb_soc_ai_island_tflm_e2e.vvp

.PHONY: soc-gpio-smoke
soc-gpio-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_gpio \
	-Mdir $(BUILD_DIR)/soc_gpio \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_gpio.sv
	./$(BUILD_DIR)/soc_gpio/Vtb_cv32e40p_axi_soc_gpio

.PHONY: soc-qspi-cfg-smoke
soc-qspi-cfg-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_qspi_cfg \
	-Mdir $(BUILD_DIR)/soc_qspi_cfg \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_qspi_cfg.sv
	./$(BUILD_DIR)/soc_qspi_cfg/Vtb_cv32e40p_axi_soc_qspi_cfg

.PHONY: soc-timer-smoke
soc-timer-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_timer \
	-Mdir $(BUILD_DIR)/soc_timer \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_timer.sv
	./$(BUILD_DIR)/soc_timer/Vtb_cv32e40p_axi_soc_timer

.PHONY: soc-uart0-smoke
soc-uart0-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_uart0 \
	-Mdir $(BUILD_DIR)/soc_uart0 \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_uart0.sv
	./$(BUILD_DIR)/soc_uart0/Vtb_cv32e40p_axi_soc_uart0

.PHONY: soc-uart1-smoke
soc-uart1-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_uart1 \
	-Mdir $(BUILD_DIR)/soc_uart1 \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_uart1.sv
	./$(BUILD_DIR)/soc_uart1/Vtb_cv32e40p_axi_soc_uart1

.PHONY: soc-i2c-smoke
soc-i2c-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_i2c \
	-Mdir $(BUILD_DIR)/soc_i2c \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_i2c.sv
	./$(BUILD_DIR)/soc_i2c/Vtb_cv32e40p_axi_soc_i2c

.PHONY: soc-imem-local-smoke
soc-imem-local-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_imem_local \
	-Mdir $(BUILD_DIR)/soc_imem_local \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) tb_cv32e40p_axi_soc_imem_local.sv
	./$(BUILD_DIR)/soc_imem_local/Vtb_cv32e40p_axi_soc_imem_local

.PHONY: soc-rom-local-smoke
soc-rom-local-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_rom_local \
	-Mdir $(BUILD_DIR)/soc_rom_local \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) tb_cv32e40p_axi_soc_rom_local.sv
	./$(BUILD_DIR)/soc_rom_local/Vtb_cv32e40p_axi_soc_rom_local

.PHONY: soc-dmem-local-smoke
soc-dmem-local-smoke: $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_dmem_local \
	-Mdir $(BUILD_DIR)/soc_dmem_local \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_dmem_local.sv
	./$(BUILD_DIR)/soc_dmem_local/Vtb_cv32e40p_axi_soc_dmem_local

.PHONY: all
all: map-check imem-smoke imem-axi-smoke dmem-smoke rom-smoke irq-router-smoke bridge-smoke wrapper-smoke soc-e2e apb-island-smoke qspi-cfg-smoke qspi-init-smoke qspi-xip-smoke apb-gpio-smoke i2c-smoke uart-smoke ai-mem-smoke ai-csr-smoke ai-uart-loader-smoke ai-accel-smoke soc-qspi-cfg-smoke soc-gpio-smoke soc-timer-smoke soc-uart0-smoke soc-uart1-smoke soc-i2c-smoke soc-rom-local-smoke soc-imem-local-smoke soc-dmem-local-smoke boot-copy-smoke

.PHONY: full
full: all real-core-smoke rom-boot-smoke rom-handoff-smoke rom-image-smoke

.PHONY: FORCE
FORCE:

$(BUILD_DIR)/cv32e40p_manifest_local.flist: ../cv32e40p/cv32e40p_manifest.flist FORCE | $(BUILD_DIR)
	perl -pe "s|\\$$\\{DESIGN_RTL_DIR\\}|../cv32e40p/rtl|g" $< > $@

.PHONY: real-core-smoke
real-core-smoke: $(BUILD_DIR)/cv32e40p_manifest_local.flist
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_real \
	-Mdir $(BUILD_DIR)/real_core \
	-f $(BUILD_DIR)/cv32e40p_manifest_local.flist \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_real.sv
	./$(BUILD_DIR)/real_core/Vtb_cv32e40p_axi_soc_real

.PHONY: rom-boot-smoke
rom-boot-smoke: $(BUILD_DIR)/cv32e40p_manifest_local.flist
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_rom_boot \
	-Mdir $(BUILD_DIR)/rom_boot \
	-f $(BUILD_DIR)/cv32e40p_manifest_local.flist \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_rom_boot.sv
	./$(BUILD_DIR)/rom_boot/Vtb_cv32e40p_axi_soc_rom_boot

.PHONY: rom-handoff-smoke
rom-handoff-smoke: $(BUILD_DIR)/cv32e40p_manifest_local.flist
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_rom_handoff \
	-Mdir $(BUILD_DIR)/rom_handoff \
	-f $(BUILD_DIR)/cv32e40p_manifest_local.flist \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_rom_handoff.sv
	./$(BUILD_DIR)/rom_handoff/Vtb_cv32e40p_axi_soc_rom_handoff

.PHONY: rom-image-smoke
rom-image-smoke: $(BUILD_DIR)/cv32e40p_manifest_local.flist
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_cv32e40p_axi_soc_rom_image \
	-Mdir $(BUILD_DIR)/rom_image \
	-f $(BUILD_DIR)/cv32e40p_manifest_local.flist \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) axi_lite_ram.sv tb_cv32e40p_axi_soc_rom_image.sv
	./$(BUILD_DIR)/rom_image/Vtb_cv32e40p_axi_soc_rom_image

.PHONY: benchmark-smoke
benchmark-smoke: $(BUILD_DIR)/cv32e40p_manifest_local.flist
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_soc_benchmark_icarus \
	-Mdir $(BUILD_DIR)/benchmark_smoke \
	-f $(BUILD_DIR)/cv32e40p_manifest_local.flist \
	$(SOC_INC_FLAGS) \
	$(SOC_TOP_RTL) fpga_top.sv axi_lite_ram.sv tb_soc_benchmark_icarus.sv
	cd .. && ./soc/$(BUILD_DIR)/benchmark_smoke/Vtb_soc_benchmark_icarus

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
