#include "xparameters.h"
#include "xil_io.h"
#include "xgpio.h"
#include "xaxidma.h"
#include "xil_printf.h"

// #define SIM_BUILD

#ifdef SIM_BUILD
  #define LOG(...)   do { } while (0)
#else
  #define LOG(...)   xil_printf(__VA_ARGS__)
#endif

#define BTN_BASEADDR    XPAR_AXI_GPIO_0_BASEADDR
#define CTRL_BASEADDR   XPAR_AXI_GPIO_1_BASEADDR
#define DMA_BASEADDR    XPAR_AXI_DMA_0_BASEADDR
#define RAM_BASEADDR    XPAR_AXI4_FULL_RAM_0_BASEADDR

#define CH_START        1u
#define CH_BUSY         2u

#define FRAME_WORDS 16000u
#define FRAME_BYTES     (FRAME_WORDS * 4u)

static XGpio   gpio_btn;
static XGpio   gpio_ctrl;
static XAxiDma dma;

static u32 expected_word(u32 k)
{
    u8 b0 = (u8)(4u * k + 0u);
    u8 b1 = (u8)(4u * k + 1u);
    u8 b2 = (u8)(4u * k + 2u);
    u8 b3 = (u8)(4u * k + 3u);
    return ((u32)b3 << 24) | ((u32)b2 << 16) | ((u32)b1 << 8) | (u32)b0;
}

int main(void)
{
    XGpio_Config   *gcfg;
    XAxiDma_Config *dcfg;
    u32 btn_now, btn_prev = 0u;
    u32 i, errors = 0u;

    gcfg = XGpio_LookupConfig(BTN_BASEADDR);
    XGpio_CfgInitialize(&gpio_btn, gcfg, gcfg->BaseAddress);
    XGpio_SetDataDirection(&gpio_btn, 1u, 0xFu);

    gcfg = XGpio_LookupConfig(CTRL_BASEADDR);
    XGpio_CfgInitialize(&gpio_ctrl, gcfg, gcfg->BaseAddress);
    XGpio_SetDataDirection(&gpio_ctrl, CH_START, 0x0u);
    XGpio_SetDataDirection(&gpio_ctrl, CH_BUSY,  0x1u);
    XGpio_DiscreteWrite(&gpio_ctrl, CH_START, 0u);

    dcfg = XAxiDma_LookupConfig(DMA_BASEADDR);
    if (dcfg == NULL) {
        LOG("DMA config not found\r\n");
        while (1) { }
    }
    XAxiDma_CfgInitialize(&dma, dcfg);
    XAxiDma_IntrDisable(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    for (i = 0u; i < FRAME_WORDS; i++) {
        Xil_Out32(RAM_BASEADDR + i * 4u, 0xDEADBEEFu);
    }

    LOG("ready, waiting for button\r\n");

    while (1) {
        btn_now = XGpio_DiscreteRead(&gpio_btn, 1u) & 0xFu;
        if ((btn_now & ~btn_prev) != 0u) {
            btn_prev = btn_now;
            break;
        }
        btn_prev = btn_now;
    }

    LOG("button pressed, arming DMA\r\n");

    if (XAxiDma_SimpleTransfer(&dma, (UINTPTR)RAM_BASEADDR,
                               FRAME_BYTES, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        LOG("DMA transfer start failed\r\n");
        while (1) { }
    }

    XGpio_DiscreteWrite(&gpio_ctrl, CH_START, 1u);

    while (XGpio_DiscreteRead(&gpio_ctrl, CH_BUSY) == 0u) { }

    XGpio_DiscreteWrite(&gpio_ctrl, CH_START, 0u);

    while (XAxiDma_Busy(&dma, XAXIDMA_DEVICE_TO_DMA)) { }

    LOG("frame received\r\n");

    for (i = 0u; i < FRAME_WORDS; i++) {
        u32 got = Xil_In32(RAM_BASEADDR + i * 4u);
        if (got != expected_word(i)) {
            errors++;
            if (errors <= 4u) {
                LOG("mismatch at %d: got %08x, expected %08x\r\n",
                    (int)i, (unsigned)got, (unsigned)expected_word(i));
            }
        }
    }

    if (errors == 0u) {
        LOG("OK: %d words match\r\n", (int)FRAME_WORDS);
    } else {
        LOG("FAIL: %d errors\r\n", (int)errors);
    }

    while (1) { }
    return 0;
}