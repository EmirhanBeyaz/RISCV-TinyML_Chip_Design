// Reference pseudocode for the CD-ROM SoC AI demo firmware.
// This file is not wired into a firmware build yet.

#include <stdint.h>
#include <stddef.h>

#define AI_CSR_BASE      0x10006000u
#define AI_MEM_BASE      0x20000000u
#define AI_INPUT_LEN     1960u
#define AI_OUTPUT_BASE   (AI_MEM_BASE + 0x7000u)

#define AI_REG_CTRL         0x04u
#define AI_REG_STATUS       0x08u
#define AI_REG_INPUT_BASE   0x0cu
#define AI_REG_INPUT_LEN    0x10u
#define AI_REG_OUTPUT_BASE  0x14u
#define AI_REG_RESULT_CLASS 0x18u
#define AI_REG_SCORE0       0x1cu
#define AI_REG_SCORE1       0x20u
#define AI_REG_SCORE2       0x24u
#define AI_REG_SCORE3       0x28u
#define AI_REG_CYCLE_COUNT  0x2cu
#define AI_REG_UART_BAUD    0x34u
#define AI_REG_UART_COUNT   0x38u

#define AI_CTRL_ACCEL_START  (1u << 0)
#define AI_CTRL_IRQ_ENABLE   (1u << 1)
#define AI_CTRL_UART_START   (1u << 2)
#define AI_CTRL_CLEAR        (1u << 3)

#define AI_STATUS_DONE       (1u << 1)
#define AI_STATUS_IRQ        (1u << 2)
#define AI_STATUS_UART_DONE  (1u << 4)
#define AI_STATUS_UART_ERR   (1u << 5)

static volatile uint32_t *const ai_csr = (volatile uint32_t *)AI_CSR_BASE;
static volatile uint8_t  *const ai_mem = (volatile uint8_t *)AI_MEM_BASE;

static inline void ai_write(uint32_t offset, uint32_t value) {
  ai_csr[offset / 4u] = value;
}

static inline uint32_t ai_read(uint32_t offset) {
  return ai_csr[offset / 4u];
}

void ai_configure_buffers(void) {
  ai_write(AI_REG_INPUT_BASE, AI_MEM_BASE);
  ai_write(AI_REG_INPUT_LEN, AI_INPUT_LEN);
  ai_write(AI_REG_OUTPUT_BASE, AI_OUTPUT_BASE);
}

int ai_load_raw_payload_from_uart_loader(uint32_t baud_div) {
  ai_configure_buffers();
  ai_write(AI_REG_UART_BAUD, baud_div);
  ai_write(AI_REG_CTRL, AI_CTRL_CLEAR);
  ai_write(AI_REG_CTRL, AI_CTRL_UART_START);

  for (;;) {
    uint32_t status = ai_read(AI_REG_STATUS);
    if ((status & AI_STATUS_UART_ERR) != 0u) {
      return -1;
    }
    if ((status & AI_STATUS_UART_DONE) != 0u) {
      break;
    }
  }

  return (ai_read(AI_REG_UART_COUNT) == AI_INPUT_LEN) ? 0 : -2;
}

void ai_copy_payload_to_mem(const uint8_t *payload, size_t len) {
  if (len > AI_INPUT_LEN) {
    len = AI_INPUT_LEN;
  }

  for (size_t i = 0; i < len; ++i) {
    ai_mem[i] = payload[i];
  }
}

void ai_start_inference(void) {
  ai_configure_buffers();
  ai_write(AI_REG_CTRL, AI_CTRL_CLEAR);
  ai_write(AI_REG_CTRL, AI_CTRL_IRQ_ENABLE | AI_CTRL_ACCEL_START);
}

void ai_wait_done_polling(void) {
  while ((ai_read(AI_REG_STATUS) & (AI_STATUS_DONE | AI_STATUS_IRQ)) == 0u) {
  }
}

uint32_t ai_result_class(void) {
  return ai_read(AI_REG_RESULT_CLASS) & 0x3u;
}

void ai_read_scores(int32_t scores[4], uint32_t *cycles) {
  scores[0] = (int32_t)ai_read(AI_REG_SCORE0);
  scores[1] = (int32_t)ai_read(AI_REG_SCORE1);
  scores[2] = (int32_t)ai_read(AI_REG_SCORE2);
  scores[3] = (int32_t)ai_read(AI_REG_SCORE3);
  *cycles = ai_read(AI_REG_CYCLE_COUNT);
}
