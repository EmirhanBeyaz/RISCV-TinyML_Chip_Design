// benchmark_main.c
// AnkaRISC / CV32E40P Bare-Metal Benchmark
// FPU yok: tum matematik fixed-point / integer yapilmistir.

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

// ============================================================
// SoC memory map
// ============================================================

#define SOC_CLK_HZ          50000000u

#define GPIO_BASE           0x10001000u
#define UART0_BASE          0x10004000u
#define AI_CSR_BASE         0x10006000u
#define AI_MEM_BASE         0x20000000u

// ============================================================
// UART register map
// ============================================================

#define UART_CTRL_OFFSET     0x00u
#define UART_STATUS_OFFSET   0x04u
#define UART_RXDATA_OFFSET   0x08u
#define UART_TXDATA_OFFSET   0x0Cu

#define UART_CTRL(base)      REG32((base) + UART_CTRL_OFFSET)
#define UART_STATUS(base)    REG32((base) + UART_STATUS_OFFSET)
#define UART_TXDATA(base)    REG32((base) + UART_TXDATA_OFFSET)

#define UART_STATUS_TX_FULL  (1u << 0)

// 50 MHz / 115200 ~= 434
#define UART_BAUD_DIV_115200 434u

// ============================================================
// GPIO register map - apb_gpiov2
// ============================================================

#define GPIO_SETGPIO_OFFSET  0x000u
#define GPIO_CLRGPIO_OFFSET  0x004u
#define GPIO_TOGGPIO_OFFSET  0x008u
#define GPIO_PIN0_OFFSET     0x010u
#define GPIO_OUT0_OFFSET     0x020u
#define GPIO_SETDIR_OFFSET   0x038u

#define GPIO_SETGPIO         REG32(GPIO_BASE + GPIO_SETGPIO_OFFSET)
#define GPIO_CLRGPIO         REG32(GPIO_BASE + GPIO_CLRGPIO_OFFSET)
#define GPIO_TOGGPIO         REG32(GPIO_BASE + GPIO_TOGGPIO_OFFSET)
#define GPIO_PIN0            REG32(GPIO_BASE + GPIO_PIN0_OFFSET)
#define GPIO_OUT0            REG32(GPIO_BASE + GPIO_OUT0_OFFSET)
#define GPIO_SETDIR          REG32(GPIO_BASE + GPIO_SETDIR_OFFSET)

// SETDIR icin:
// PWDATA[25:24] = 2'b01 normal output mode
// PWDATA[4:0]   = pin index
#define GPIO_DIR_OUTPUT(pin) (0x01000000u | ((uint32_t)(pin) & 0x1Fu))

// ============================================================
// Benchmark helpers
// ============================================================

static volatile uint32_t bench_sink = 0;

static inline uint32_t read_mcycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mcycle" : "=r"(value));
    return value;
}

static void uart_init(void)
{
    // CTRL = {baud_div[15:0], 14'b0, rx_enable, tx_enable}
    UART_CTRL(UART0_BASE) = (UART_BAUD_DIV_115200 << 16) | (1u << 1) | (1u << 0);
}

static void uart_putc(char c)
{
    while (UART_STATUS(UART0_BASE) & UART_STATUS_TX_FULL) {
        // TX doluysa bekle
    }

    UART_TXDATA(UART0_BASE) = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

static void uart_put_dec_u32(uint32_t value)
{
    char buf[11];
    int i = 0;

    if (value == 0u) {
        uart_putc('0');
        return;
    }

    while (value > 0u && i < 10) {
        buf[i++] = (char)('0' + (value % 10u));
        value /= 10u;
    }

    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

static void uart_put_dec_i32(int32_t value)
{
    if (value < 0) {
        uart_putc('-');
        value = -value;
    }

    uart_put_dec_u32((uint32_t)value);
}

static void uart_put_hex_digit(uint8_t v)
{
    v &= 0xFu;

    if (v < 10u) {
        uart_putc((char)('0' + v));
    } else {
        uart_putc((char)('A' + (v - 10u)));
    }
}

static void uart_put_hex32(uint32_t value)
{
    uart_puts("0x");

    for (int i = 7; i >= 0; i--) {
        uart_put_hex_digit((uint8_t)(value >> (i * 4)));
    }
}

static void gpio_init_leds(void)
{
    for (uint32_t i = 0; i < 8u; i++) {
        GPIO_SETDIR = GPIO_DIR_OUTPUT(i);
    }

    GPIO_OUT0 = 0x00000000u;
}

static void gpio_write_leds(uint8_t value)
{
    GPIO_OUT0 = (uint32_t)value;
}

// ============================================================
// Q15 fixed-point math
// ============================================================
//
// Q15 format:
// 1.0 ~= 32767
// 0.5 = 16384
// 0.25 = 8192
//
// FPU kullanmadan ondalikli yaklasik hesap yapmak icin kullaniliyor.

#define Q15_ONE   32768
#define Q15_HALF  16384

static inline int32_t q15_mul(int32_t a, int32_t b)
{
    // Q15 x Q15 -> Q15
    // FPU yok; sadece integer carpma kullaniliyor.
    return (int32_t)((a * b) >> 15);
}

static void uart_put_q15(int32_t value)
{
    int32_t whole;
    int32_t frac;

    if (value < 0) {
        uart_putc('-');
        value = -value;
    }

    whole = value / Q15_ONE;
    frac  = value % Q15_ONE;

    // 4 basamakli ondalik gosterim
    frac = (frac * 10000) / Q15_ONE;

    uart_put_dec_i32(whole);
    uart_putc('.');

    if (frac < 1000) uart_putc('0');
    if (frac < 100)  uart_putc('0');
    if (frac < 10)   uart_putc('0');

    uart_put_dec_i32(frac);
}

// sin(x) ~= x - x^3/3! + x^5/5! - x^7/7! + x^9/9!
// x radyan cinsinden Q15 formatinda.
// Bu test FPU kullanmaz.
static int32_t sin_taylor_q15(int32_t x, uint32_t terms)
{
    int32_t x2;
    int32_t term;
    int32_t result;

    x2 = q15_mul(x, x);
    term = x;
    result = term;

    if (terms >= 2u) {
        term = q15_mul(term, x2);
        result -= term / 6;
    }

    if (terms >= 3u) {
        term = q15_mul(term, x2);
        result += term / 120;
    }

    if (terms >= 4u) {
        term = q15_mul(term, x2);
        result -= term / 5040;
    }

    if (terms >= 5u) {
        term = q15_mul(term, x2);
        result += term / 362880;
    }

    return result;
}

// ============================================================
// Benchmark 1: Taylor sin(x)
// ============================================================

static void benchmark_taylor(void)
{
    uint32_t start;
    uint32_t end;
    uint32_t cycles;
    int32_t result = 0;

    // x = 0.5 rad ~= Q15_HALF
    int32_t x = Q15_HALF;

    uart_puts("\n[TAYLOR Q15 SIN]\n");
    uart_puts("x = 0.5 rad\n");

    for (uint32_t terms = 2u; terms <= 5u; terms++) {
        start = read_mcycle();

        for (uint32_t i = 0; i < 1000u; i++) {
            result += sin_taylor_q15(x, terms);
        }

        end = read_mcycle();
        cycles = end - start;

        bench_sink ^= (uint32_t)result;

        uart_puts("terms=");
        uart_put_dec_u32(terms);
        uart_puts(" result_acc=");
        uart_put_dec_i32(result);
        uart_puts(" approx_single=");
        uart_put_q15(sin_taylor_q15(x, terms));
        uart_puts(" cycles=");
        uart_put_dec_u32(cycles);
        uart_puts("\n");
    }
}

// ============================================================
// Benchmark 2: Newton interpolation
// ============================================================

static const int32_t newton_x[4] = {0, 1, 2, 3};
static const int32_t newton_y[4] = {1, 4, 13, 34}; // y = x^3 + 2x + 1

static void newton_build_coeffs(int32_t coeffs[4])
{
    for (uint32_t i = 0; i < 4u; i++) {
        coeffs[i] = newton_y[i];
    }

    for (uint32_t level = 1; level < 4u; level++) {
        for (int32_t i = 3; i >= (int32_t)level; i--) {
            int32_t numer = coeffs[i] - coeffs[i - 1];
            int32_t denom = newton_x[i] - newton_x[i - (int32_t)level];
            coeffs[i] = numer / denom;
        }
    }
}

static int32_t newton_eval_i32(const int32_t coeffs[4], int32_t x)
{
    int32_t acc = coeffs[3];

    for (int32_t i = 2; i >= 0; i--) {
        acc = coeffs[i] + ((x - newton_x[i]) * acc);
    }

    return acc;
}

static void benchmark_newton_interpolation(void)
{
    int32_t coeffs[4];
    int32_t checksum = 0;
    uint32_t start;
    uint32_t end;
    uint32_t cycles;

    uart_puts("\n[NEWTON INTERPOLATION]\n");
    uart_puts("model: y = x^3 + 2x + 1\n");

    newton_build_coeffs(coeffs);

    start = read_mcycle();

    for (uint32_t iter = 0; iter < 1000u; iter++) {
        for (int32_t x = 0; x <= 7; x++) {
            checksum += newton_eval_i32(coeffs, x);
        }
    }

    end = read_mcycle();
    cycles = end - start;

    bench_sink ^= (uint32_t)checksum;
    bench_sink ^= (uint32_t)coeffs[3];

    uart_puts("coeffs=");
    uart_put_dec_i32(coeffs[0]);
    uart_putc(',');
    uart_put_dec_i32(coeffs[1]);
    uart_putc(',');
    uart_put_dec_i32(coeffs[2]);
    uart_putc(',');
    uart_put_dec_i32(coeffs[3]);
    uart_puts(" checksum=");
    uart_put_dec_i32(checksum);
    uart_puts(" cycles=");
    uart_put_dec_u32(cycles);
    uart_puts("\n");
}

// ============================================================
// Benchmark 3: iterative numerical methods in a fixed cycle window
// ============================================================

#define ITER_WINDOW_CYCLES 100000u
#define ITER_ROUNDS        3u
#define ITER_PER_SEC_SCALE (SOC_CLK_HZ / ITER_WINDOW_CYCLES)
#define Q15_TWO            (2 * Q15_ONE)

typedef int32_t (*iter_step_fn_t)(void);

static const int32_t sqrt_targets_q15[4] = {
    Q15_ONE / 4,
    Q15_ONE / 2,
    (3 * Q15_ONE) / 4,
    Q15_ONE
};

static int32_t sqrt_guess_q15[4] = {
    Q15_ONE,
    Q15_ONE,
    Q15_ONE,
    Q15_ONE
};

static uint32_t sqrt_target_idx = 0;

static int32_t iter_newton_sqrt_step(void)
{
    uint32_t idx = sqrt_target_idx;
    int32_t n = sqrt_targets_q15[idx];
    int32_t y = sqrt_guess_q15[idx];
    int32_t n_over_y;

    if (y <= 0) {
        y = Q15_ONE;
    }

    n_over_y = (int32_t)((n << 15) / y);
    y = (y + n_over_y) >> 1;

    sqrt_guess_q15[idx] = y;
    sqrt_target_idx = (idx + 1u) & 3u;

    return y;
}

static const int32_t bisection_targets_q15[4] = {
    Q15_ONE / 8,
    Q15_ONE / 4,
    Q15_ONE / 2,
    (3 * Q15_ONE) / 4
};

static int32_t bisection_lo_q15 = 0;
static int32_t bisection_hi_q15 = Q15_ONE;
static uint32_t bisection_target_idx = 0;

static int32_t iter_bisection_sqrt_step(void)
{
    int32_t mid = (bisection_lo_q15 + bisection_hi_q15) >> 1;
    int32_t mid2 = q15_mul(mid, mid);
    int32_t target = bisection_targets_q15[bisection_target_idx];

    if (mid2 > target) {
        bisection_hi_q15 = mid;
    } else {
        bisection_lo_q15 = mid;
    }

    if ((bisection_hi_q15 - bisection_lo_q15) <= 1) {
        bisection_target_idx = (bisection_target_idx + 1u) & 3u;
        bisection_lo_q15 = 0;
        bisection_hi_q15 = Q15_ONE;
    }

    return mid;
}

static const int32_t reciprocal_targets_q15[4] = {
    Q15_ONE,
    Q15_ONE + (Q15_ONE / 4),
    Q15_ONE + Q15_HALF,
    Q15_TWO
};

static int32_t reciprocal_guess_q15[4] = {
    Q15_HALF,
    Q15_HALF,
    Q15_HALF,
    Q15_HALF
};

static uint32_t reciprocal_target_idx = 0;

static int32_t iter_newton_reciprocal_step(void)
{
    uint32_t idx = reciprocal_target_idx;
    int32_t a = reciprocal_targets_q15[idx];
    int32_t y = reciprocal_guess_q15[idx];
    int32_t ay = q15_mul(a, y);

    y = q15_mul(y, Q15_TWO - ay);
    reciprocal_guess_q15[idx] = y;
    reciprocal_target_idx = (idx + 1u) & 3u;

    return y;
}

static int32_t jacobi_x_q15 = 0;
static int32_t jacobi_y_q15 = 0;

static int32_t iter_jacobi_2x2_step(void)
{
    int32_t next_x = (Q15_ONE - jacobi_y_q15) / 4;
    int32_t next_y = (Q15_ONE - jacobi_x_q15) / 3;

    jacobi_x_q15 = next_x;
    jacobi_y_q15 = next_y;

    return next_x ^ (next_y << 1);
}

static const int32_t cordic_atan_q15[12] = {
    25736, 15193, 8027, 4075, 2045, 1024, 512, 256, 128, 64, 32, 16
};

static int32_t cordic_angle_q15 = 0;

static int32_t iter_cordic_sincos_step(void)
{
    int32_t x = 19898; // Q15 CORDIC gain compensation ~= 0.60725
    int32_t y = 0;
    int32_t z = cordic_angle_q15;

    for (uint32_t i = 0; i < 12u; i++) {
        int32_t x_shift = x >> i;
        int32_t y_shift = y >> i;

        if (z >= 0) {
            x -= y_shift;
            y += x_shift;
            z -= cordic_atan_q15[i];
        } else {
            x += y_shift;
            y -= x_shift;
            z += cordic_atan_q15[i];
        }
    }

    cordic_angle_q15 += 1024;
    if (cordic_angle_q15 > Q15_ONE) {
        cordic_angle_q15 -= Q15_TWO;
    }

    return x ^ (y << 1) ^ z;
}

static const int16_t fir_coeffs[16] = {
    512, 1024, 1536, 2048, 2560, 3072, 3584, 4096,
    4096, 3584, 3072, 2560, 2048, 1536, 1024, 512
};

static int16_t fir_delay[16];
static uint32_t fir_pos = 0;
static int16_t fir_sample = 1;

static int32_t iter_fir16_step(void)
{
    int32_t acc = 0;

    fir_delay[fir_pos] = fir_sample;
    fir_sample = (int16_t)((fir_sample * 73 + 19) & 0x7FFF);

    for (uint32_t i = 0; i < 16u; i++) {
        uint32_t idx = (fir_pos - i) & 15u;
        acc += (int32_t)fir_delay[idx] * (int32_t)fir_coeffs[i];
    }

    fir_pos = (fir_pos + 1u) & 15u;

    return acc >> 12;
}

static const int16_t matvec8_matrix[8][8] = {
    {3, -1, 2, 0, 1, -2, 4, 1},
    {1, 2, -1, 3, 0, 1, -3, 2},
    {2, 1, 3, -2, 4, 0, 1, -1},
    {-1, 3, 1, 2, -2, 4, 0, 1},
    {4, 0, -2, 1, 3, -1, 2, 1},
    {2, -3, 4, 1, -1, 2, 3, 0},
    {0, 1, 2, -1, 4, 3, -2, 1},
    {1, 4, 0, 2, -3, 1, 2, -1}
};

static int16_t matvec8_vec[8] = {7, -3, 5, 11, -9, 13, 2, -6};

static int32_t iter_matvec8_step(void)
{
    int32_t checksum = 0;
    int16_t next_vec[8];

    for (uint32_t row = 0; row < 8u; row++) {
        int32_t acc = 0;

        for (uint32_t col = 0; col < 8u; col++) {
            acc += (int32_t)matvec8_matrix[row][col] * (int32_t)matvec8_vec[col];
        }

        next_vec[row] = (int16_t)(acc & 0x7FFF);
        checksum ^= acc;
    }

    for (uint32_t i = 0; i < 8u; i++) {
        matvec8_vec[i] = next_vec[i];
    }

    return checksum;
}

static uint32_t crc_state = 0xFFFFFFFFu;
static uint32_t crc_data = 0x12345678u;

static int32_t iter_crc32_64b_step(void)
{
    uint32_t crc = crc_state;

    for (uint32_t i = 0; i < 64u; i++) {
        uint8_t byte = (uint8_t)(crc_data >> ((i & 3u) * 8u));
        crc ^= byte;

        for (uint32_t bit = 0; bit < 8u; bit++) {
            uint32_t mask = 0u - (crc & 1u);
            crc = (crc >> 1) ^ (0xEDB88320u & mask);
        }

        crc_data = (crc_data * 1664525u) + 1013904223u;
    }

    crc_state = crc;
    return (int32_t)crc;
}

static uint32_t sort_seed = 0xACE1u;

static int32_t iter_sort32_step(void)
{
    int32_t values[32];
    int32_t checksum = 0;

    for (uint32_t i = 0; i < 32u; i++) {
        sort_seed = (sort_seed * 1103515245u) + 12345u;
        values[i] = (int32_t)((sort_seed >> 16) & 0x7FFFu);
    }

    for (uint32_t i = 1; i < 32u; i++) {
        int32_t key = values[i];
        int32_t j = (int32_t)i - 1;

        while ((j >= 0) && (values[j] > key)) {
            values[j + 1] = values[j];
            j--;
        }

        values[j + 1] = key;
    }

    for (uint32_t i = 0; i < 32u; i++) {
        checksum ^= values[i] + (int32_t)i;
    }

    return checksum;
}

static uint8_t pointer_table[128];
static uint32_t pointer_init_done = 0;
static uint32_t pointer_idx = 0;

static int32_t iter_pointer_chase64_step(void)
{
    if (pointer_init_done == 0u) {
        for (uint32_t i = 0; i < 128u; i++) {
            pointer_table[i] = (uint8_t)((i * 37u + 11u) & 127u);
        }

        pointer_init_done = 1u;
    }

    for (uint32_t i = 0; i < 64u; i++) {
        pointer_idx = pointer_table[pointer_idx & 127u];
    }

    return (int32_t)pointer_idx;
}

static uint32_t iter_run_window(iter_step_fn_t step_fn, int32_t *last_acc)
{
    uint32_t count = 0;
    uint32_t start = read_mcycle();
    int32_t acc = *last_acc;

    do {
        acc ^= step_fn();
        count++;
    } while ((read_mcycle() - start) < ITER_WINDOW_CYCLES);

    *last_acc = acc;
    bench_sink ^= (uint32_t)acc;
    bench_sink ^= count;

    return count;
}

static void iter_print_window_line(const char *name, iter_step_fn_t step_fn)
{
    uint32_t counts[ITER_ROUNDS];
    uint32_t min_count = 0xFFFFFFFFu;
    uint32_t max_count = 0u;
    uint32_t sum_count = 0u;
    int32_t acc = 0;

    for (uint32_t round = 0; round < ITER_ROUNDS; round++) {
        counts[round] = iter_run_window(step_fn, &acc);

        if (counts[round] < min_count) {
            min_count = counts[round];
        }

        if (counts[round] > max_count) {
            max_count = counts[round];
        }

        sum_count += counts[round];
    }

    uart_puts(name);
    uart_puts(" windows=");

    for (uint32_t round = 0; round < ITER_ROUNDS; round++) {
        if (round != 0u) {
            uart_putc('/');
        }

        uart_put_dec_u32(counts[round]);
    }

    uart_puts(" avg_iter=");
    uart_put_dec_u32(sum_count / ITER_ROUNDS);
    uart_puts(" iter_per_sec=");
    uart_put_dec_u32((sum_count * ITER_PER_SEC_SCALE) / ITER_ROUNDS);
    uart_puts(" min=");
    uart_put_dec_u32(min_count);
    uart_puts(" max=");
    uart_put_dec_u32(max_count);
    uart_puts(" stable=");

    if ((max_count - min_count) <= 1u) {
        uart_puts("yes");
    } else {
        uart_puts("no");
    }

    uart_puts(" acc=");
    uart_put_dec_i32(acc);
    uart_puts("\n");
}

static void benchmark_iterative_methods(void)
{
    uart_puts("\n[ITERATIVE NUMERIC WINDOW]\n");
    uart_puts("window_cycles=");
    uart_put_dec_u32(ITER_WINDOW_CYCLES);
    uart_puts(" rounds=");
    uart_put_dec_u32(ITER_ROUNDS);
    uart_puts(" scale_to_1s=x");
    uart_put_dec_u32(ITER_PER_SEC_SCALE);
    uart_puts("\n");

    iter_print_window_line("newton_sqrt", iter_newton_sqrt_step);
    iter_print_window_line("bisection_sqrt", iter_bisection_sqrt_step);
    iter_print_window_line("newton_reciprocal", iter_newton_reciprocal_step);
    iter_print_window_line("jacobi_2x2", iter_jacobi_2x2_step);
    iter_print_window_line("cordic_sincos", iter_cordic_sincos_step);
    iter_print_window_line("fir16_filter", iter_fir16_step);
    iter_print_window_line("matvec8x8", iter_matvec8_step);
    iter_print_window_line("crc32_64B", iter_crc32_64b_step);
    iter_print_window_line("sort32", iter_sort32_step);
    pointer_init_done = 0u;
    (void)iter_pointer_chase64_step();
    iter_print_window_line("pointer_chase64", iter_pointer_chase64_step);
}

// ============================================================
// Benchmark 4: 4x4 integer matrix multiply
// ============================================================

static int32_t mat_a[4][4] = {
    {1, 2, 3, 4},
    {5, 6, 7, 8},
    {9, 10, 11, 12},
    {13, 14, 15, 16}
};

static int32_t mat_b[4][4] = {
    {16, 15, 14, 13},
    {12, 11, 10, 9},
    {8, 7, 6, 5},
    {4, 3, 2, 1}
};

static int32_t mat_c[4][4];

static void matmul_4x4(void)
{
    for (uint32_t i = 0; i < 4u; i++) {
        for (uint32_t j = 0; j < 4u; j++) {
            int32_t acc = 0;

            for (uint32_t k = 0; k < 4u; k++) {
                acc += mat_a[i][k] * mat_b[k][j];
            }

            mat_c[i][j] = acc;
        }
    }
}

static void benchmark_matmul(void)
{
    uint32_t start;
    uint32_t end;
    uint32_t cycles;
    int32_t checksum = 0;

    uart_puts("\n[MATRIX 4x4 INT]\n");

    start = read_mcycle();

    for (uint32_t r = 0; r < 1000u; r++) {
        matmul_4x4();
    }

    end = read_mcycle();
    cycles = end - start;

    for (uint32_t i = 0; i < 4u; i++) {
        for (uint32_t j = 0; j < 4u; j++) {
            checksum += mat_c[i][j];
        }
    }

    bench_sink ^= (uint32_t)checksum;

    uart_puts("checksum=");
    uart_put_dec_i32(checksum);
    uart_puts(" cycles=");
    uart_put_dec_u32(cycles);
    uart_puts("\n");
}

// ============================================================
// Benchmark 5: memory copy
// ============================================================

#define MEM_BENCH_SIZE 512u

static uint8_t mem_src[MEM_BENCH_SIZE];
static uint8_t mem_dst[MEM_BENCH_SIZE];

static void mem_init(void)
{
    for (uint32_t i = 0; i < MEM_BENCH_SIZE; i++) {
        mem_src[i] = (uint8_t)(i & 0xFFu);
        mem_dst[i] = 0u;
    }
}

static void mem_copy_test(void)
{
    for (uint32_t i = 0; i < MEM_BENCH_SIZE; i++) {
        mem_dst[i] = mem_src[i];
    }
}

static uint32_t mem_checksum(void)
{
    uint32_t sum = 0;

    for (uint32_t i = 0; i < MEM_BENCH_SIZE; i++) {
        sum += mem_dst[i];
    }

    return sum;
}

static void benchmark_memcopy(void)
{
    uint32_t start;
    uint32_t end;
    uint32_t cycles;
    uint32_t checksum;

    uart_puts("\n[MEMCOPY 512B]\n");

    mem_init();

    start = read_mcycle();

    for (uint32_t r = 0; r < 100u; r++) {
        mem_copy_test();
    }

    end = read_mcycle();
    cycles = end - start;

    checksum = mem_checksum();
    bench_sink ^= checksum;

    uart_puts("checksum=");
    uart_put_dec_u32(checksum);
    uart_puts(" cycles=");
    uart_put_dec_u32(cycles);
    uart_puts("\n");
}

// ============================================================
// main
// ============================================================

int main(void)
{
    uart_init();
    gpio_init_leds();

    gpio_write_leds(0x01);

    uart_puts("\n");
    uart_puts("====================================\n");
    uart_puts(" CD-Rom Architecture Benchmark\n");
    uart_puts(" No FPU - Fixed Point / Integer\n");
    uart_puts("====================================\n");

    uart_puts("UART OK\n");

    gpio_write_leds(0x11);
    benchmark_taylor();

    gpio_write_leds(0x22);
    benchmark_newton_interpolation();

    gpio_write_leds(0x33);
    benchmark_iterative_methods();

    gpio_write_leds(0x44);
    benchmark_matmul();

    gpio_write_leds(0x88);
    benchmark_memcopy();

    gpio_write_leds(0xAA);

    uart_puts("\nBenchmark finished.\n");
    uart_puts("bench_sink=");
    uart_put_hex32(bench_sink);
    uart_puts("\n");

    while (1) {
        // Benchmark bitti.
    }

    return 0;
}
