/*
 * SPDX-FileCopyrightText: 2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "ulp_lp_core_print.h"
#include "ulp_lp_core_utils.h"
#include "ulp_lp_core_uart.h"
#include "sml.h"
#include "ehz_bin.h"

sml_states_t sml_state;
uint32_t iteration = 0;
uint32_t print_variable = 1337;
// long long int value = -1337;
unsigned char sml_byte = 0xa7;
const unsigned char obis[6] = {0x01, 0x00, 0x01, 0x08, 0x01, 0xff};
double sml_t1wh = -2;

#define LP_UART_PORT_NUM LP_UART_NUM_0

int main(void)
{

    // uint8_t sml_byte = 0x1b;
    // setState(SML_START, 4);

    iteration++;
    print_variable++;

    // while (sml_byte != 0xa7 && sml_byte != 0xff)
    /* Read data from the LP_UART */
    // while (lp_core_uart_read_bytes(LP_UART_PORT_NUM, &sml_byte, 1, 10) == 1)
    for (uint16_t i = 0; i < ehz_bin_len; i++)
    {
        sml_byte = ehz_bin[i];
        sml_state = smlState(sml_byte);
        // lp_core_printf("sml_byte: %d\n", sml_byte);
        if (sml_state == SML_START)
        {
            // lp_core_printf("SML_START\n");
            /* reset local vars */
            sml_t1wh = -3;
        }
        if (sml_state == SML_LISTEND)
        {
            // lp_core_printf("SML_LISTEND\n");

            const bool isMatch = smlOBISCheck(obis);
            // lp_core_printf("OBIS check\n");
            if (isMatch)
            {
                // lp_core_printf("Match - Processing value\n");
                signed char scaler;
                long long int value = smlOBISByUnit(&scaler, SML_WATT_HOUR);
                if (value != -1)
                {
                    // lp_core_printf("Value: %lld\n", value);
                    sml_t1wh = smlPow(value, scaler);
                }
            }
        }
        if (sml_state == SML_UNEXPECTED)
        {
            // lp_core_printf(">>> Unexpected byte! %d <<<\n", sml_byte);
        }
        if (sml_state == SML_FINAL)
        {
            // lp_core_printf("SML_FINAL\n");
            // lp_core_printf("Power T1    (1-0:1.8.1)..: ");
            // lp_core_printf("%f", sml_t1wh);
            // lp_core_printf("\n");
        }
        sml_byte = -1;
    }

    return 0;
}
