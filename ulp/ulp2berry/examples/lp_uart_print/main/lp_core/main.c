/*
 * SPDX-FileCopyrightText: 2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include "ulp_lp_core_print.h"
#include "ulp_lp_core_utils.h"
#include "ulp_lp_core_uart.h"
#include "lib_src.h"
#include "ehz_bin.h"
#include "sml.h"

uint32_t iteration = 0;
uint32_t print_variable = 1337;
int sum;

double T1Wh = -2, SumWh = -2;

typedef struct
{
    const unsigned char OBIS[6];
    void (*Handler)();
} OBISHandler;

void PowerT1() { smlOBISWh(T1Wh); }

void PowerSum() { smlOBISWh(SumWh); }

OBISHandler OBISHandlers[] = {
    {{0x01, 0x00, 0x01, 0x08, 0x01, 0xff}, &PowerT1},  /*   1-  0:  1.  8.1*255 (T1) */
    {{0x01, 0x00, 0x01, 0x08, 0x00, 0xff}, &PowerSum}, /*   1-  0:  1.  8.0*255 (T1 + T2) */
    {{0, 0}}};

int main(void)
{
    sum = lib_test_func_sum(5, 6);

    unsigned int i = 0, iHandler = 0;
    unsigned char c;
    sml_states_t s;
    setState(SML_START, 4);

    for (i = 0; i < ehz_bin_len; ++i)
    {
        c = ehz_bin[i];
        s = smlState(c);
        // lp_core_printf("c: %d\n", c);
        if (s == SML_START)
        {
            lp_core_printf("SML_START\n");
            /* reset local vars */
            T1Wh = -3;
            SumWh = -3;
        }
        if (s == SML_LISTEND)
        {
            lp_core_printf("SML_LISTEND\n");
            /* check handlers on last received list */
            for (iHandler = 0; OBISHandlers[iHandler].Handler != 0 &&
                               !(smlOBISCheck(OBISHandlers[iHandler].OBIS));
                 iHandler++)
                ;
            if (OBISHandlers[iHandler].Handler != 0)
            {
                OBISHandlers[iHandler].Handler();
            }
        }
        if (s == SML_UNEXPECTED)
        {
            lp_core_printf(">>> Unexpected byte! <<<\n");
        }
        if (s == SML_FINAL)
        {
            lp_core_printf("SML_FINAL\n");
            //     lp_core_printf("Power T1    (1-0:1.8.1)..: ");
            //     lp_core_printf("%f", T1Wh);
            //     lp_core_printf("\n");

            //     lp_core_printf("Power T1+T2 (1-0:1.8.0)..: ");
            //     lp_core_printf("%f", SumWh);
            //     lp_core_printf("\n\n\n\n");
        }
    }

    const char separator[] = "**************************";

    lp_core_printf("Hello from the LP core!!\r\n");
    lp_core_printf("This program has run %d times\r\n", ++iteration);
    lp_core_printf("print_variable: %d\r\n", print_variable);
    lp_core_printf("%s", separator);
    lp_core_printf("\n");
    lp_core_uart_tx_flush(LP_UART_NUM_0);

    return 0;
}
