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

uint32_t iteration = 0;
volatile uint32_t print_variable = 1337;

uint32_t sml_unexpected_count = 0;

typedef struct
{
    unsigned char OBIS[6];
    uint8_t unit;
    int8_t scaler;
} MeterConfig;

MeterConfig obis_configs[10] = {
    {{0x01, 0x00, 0x01, 0x08, 0x01, 0xff}, SML_WATT_HOUR, 1},
    {{0x01, 0x00, 0x01, 0x08, 0x00, 0xff}, SML_WATT_HOUR, 1},
};

float obis_values[10];

#define LP_UART_PORT_NUM LP_UART_NUM_0

int main(void)
{
    sml_states_t sml_state;

    uint8_t sml_byte;
    uint8_t iHandler = 0;

    iteration++;
    (void)print_variable;
    (void)obis_configs[0].unit;
    (void)obis_values[0];
    /* Read data from the LP_UART */
    // while (lp_core_uart_read_bytes(LP_UART_PORT_NUM, &sml_byte, 1, 10) == 1)
    for (uint16_t i = 0; i < ehz_bin_len; i++)
    {
        sml_byte = ehz_bin[i];
        sml_state = smlState(sml_byte);
        if (sml_state == SML_START)
        {
        }
        if (sml_state == SML_LISTEND)
        {
            for (iHandler = 0; obis_configs[iHandler].unit != 0 &&
                               !(smlOBISCheck(obis_configs[iHandler].OBIS));
                 iHandler++)
                ;
            if (obis_configs[iHandler].unit != 0)
            {
                smlOBISUnit(&obis_values[iHandler], obis_configs[iHandler].unit);
            }
        }
        if (sml_state == SML_UNEXPECTED)
        {
            sml_unexpected_count++;
        }
        if (sml_state == SML_FINAL)
        {
            sml_unexpected_count = 0;
        }
    }

    return 0;
}
