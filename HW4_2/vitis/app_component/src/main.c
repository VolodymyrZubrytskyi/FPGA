#include "xparameters.h"
#include "xgpio.h"
#include "xtmrctr.h"
#include "xinterrupt_wrap.h"
#include "xil_printf.h"

// #define SIM_FAST

#define LED_BASEADDR    XPAR_AXI_GPIO_0_BASEADDR
#define SW_BASEADDR     XPAR_AXI_GPIO_1_BASEADDR
#define BTN_BASEADDR    XPAR_AXI_GPIO_2_BASEADDR
#define TMR_BASEADDR    XPAR_AXI_TIMER_0_BASEADDR

#define GPIO_CH         1u
#define TMR_CH          0u
#define TMR_FREQ_HZ     XPAR_AXI_TIMER_0_CLOCK_FREQUENCY

#define LED_N           4u
#define LED_MASK        0xFu

#define BTN_FASTER      0x1u
#define BTN_RUN         0x2u
#define BTN_HOME        0x4u
#define BTN_SLOWER      0x8u

#ifdef SIM_FAST
static const u32 step_us[] = { 40u, 30u, 20u, 15u, 10u };
#else
static const u32 step_us[] = { 500000u, 250000u, 120000u, 60000u, 30000u };
#endif
#define SPEED_N  (sizeof(step_us) / sizeof(step_us[0]))

static XGpio   Led, Sw, Btn;
static XTmrCtr Tmr;

static volatile u32 tick;
static u32 pos;
static u32 speed = 2u;
static int running = 1;

static void TimerIsr(void *CallBackRef, u8 TmrCtrNumber)
{
    (void)CallBackRef;
    (void)TmrCtrNumber;
    tick = 1u;
}

static u32 us_to_reload(u32 us)
{
    return (u32)(0u - (TMR_FREQ_HZ / 1000000u) * us);
}

static void set_period(u32 us)
{
    XTmrCtr_Stop(&Tmr, TMR_CH);
    XTmrCtr_SetResetValue(&Tmr, TMR_CH, us_to_reload(us));
    XTmrCtr_Start(&Tmr, TMR_CH);
}

int main(void)
{
    XGpio_Config   *gcfg;
    XTmrCtr_Config *tcfg;
    u32 btn_now, btn_prev = 0u, pressed, dir;

    gcfg = XGpio_LookupConfig(LED_BASEADDR);
    XGpio_CfgInitialize(&Led, gcfg, gcfg->BaseAddress);
    gcfg = XGpio_LookupConfig(SW_BASEADDR);
    XGpio_CfgInitialize(&Sw,  gcfg, gcfg->BaseAddress);
    gcfg = XGpio_LookupConfig(BTN_BASEADDR);
    XGpio_CfgInitialize(&Btn, gcfg, gcfg->BaseAddress);

    XGpio_SetDataDirection(&Led, GPIO_CH, 0x0000u);
    XGpio_SetDataDirection(&Sw,  GPIO_CH, 0xFFFFu);
    XGpio_SetDataDirection(&Btn, GPIO_CH, 0xFu);

    tcfg = XTmrCtr_LookupConfig(TMR_BASEADDR);
    XTmrCtr_CfgInitialize(&Tmr, tcfg, tcfg->BaseAddress);
    XTmrCtr_SetHandler(&Tmr, TimerIsr, &Tmr);
    XTmrCtr_SetOptions(&Tmr, TMR_CH,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);

    XSetupInterruptSystem(&Tmr, (void *)XTmrCtr_InterruptHandler,
                          tcfg->IntrId, tcfg->IntrParent, 0);

#ifndef SIM_FAST
    xil_printf("LED runner: timer %d Hz, step %d us\r\n",
               (int)TMR_FREQ_HZ, (int)step_us[speed]);
#endif

    set_period(step_us[speed]);
    XGpio_DiscreteWrite(&Led, GPIO_CH, (1u << pos) & LED_MASK);

    while (1) {
        if (tick) {
            tick = 0u;

            btn_now  = XGpio_DiscreteRead(&Btn, GPIO_CH) & 0xFu;
            pressed  = btn_now & ~btn_prev;
            btn_prev = btn_now;

            if (pressed & BTN_RUN) {
                running = !running;
            }
            if ((pressed & BTN_FASTER) && (speed + 1u < SPEED_N)) {
                speed++;
                set_period(step_us[speed]);
            }
            if ((pressed & BTN_SLOWER) && (speed > 0u)) {
                speed--;
                set_period(step_us[speed]);
            }
            if (pressed & BTN_HOME) {
                pos = 0u;
            }

            if (running) {
                dir = XGpio_DiscreteRead(&Sw, GPIO_CH) & 0x1u;
                pos = dir ? (pos + LED_N - 1u) % LED_N
                          : (pos + 1u) % LED_N;
            }

            XGpio_DiscreteWrite(&Led, GPIO_CH, (1u << pos) & LED_MASK);
        }
    }
    return 0;
}