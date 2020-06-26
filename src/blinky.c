#include <FreeRTOS.h>
#include <task.h>
#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/gpio.h>
#include <libopencm3/cm3/nvic.h>

extern void vPortSVCHandler( void ) __attribute__ (( naked ));
extern void xPortPendSVHandler( void ) __attribute__ (( naked ));
extern void xPortSysTickHandler( void );
extern void vApplicationStackOverflowHook(xTaskHandle *pxTask,signed portCHAR *pcTaskName);

void vApplicationStackOverflowHook(xTaskHandle *pxTask, signed portCHAR *pcTaskName) {
	(void)pxTask;
	(void)pcTaskName;
	for(;;);
}

void sv_call_handler(void) {
	vPortSVCHandler();
}

void pend_sv_handler(void) {
	xPortPendSVHandler();
}

void sys_tick_handler(void) {
	xPortSysTickHandler();
}

static void led1(void *args) {
    (void)args;

    for (;;) {
        gpio_toggle(GPIOA, GPIO6);
        for (int i = 0; i < 1000000; i++) __asm__("nop");
    }
}

static void led2(void *args) {
    (void)args;

    for (;;) {
        gpio_toggle(GPIOA, GPIO7);
        for (int i = 0; i < 3333333; i++) __asm__("nop");
    }
}

int main(void) {
    rcc_periph_clock_enable(RCC_GPIOA);

    gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO6);
    gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO7);

    xTaskCreate(led1, "LED1", 100, NULL, configMAX_PRIORITIES - 1, NULL);
    xTaskCreate(led2, "LED2", 100, NULL, configMAX_PRIORITIES - 1, NULL);
    vTaskStartScheduler();

    return 0;
}
