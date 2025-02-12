/*
 * SPDX-FileCopyrightText: 2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "ulp_lp_core_print.h"
#include "ulp_lp_core_utils.h"
#include "ulp_lp_core_uart.h"
#include "sml.h"

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

    uint8_t config_index = 0;
    uint8_t data[256] = {0};
    int length = 0;

    iteration++;
    (void)print_variable;
    (void)obis_configs[0].unit;
    (void)obis_values[0];
    /* Read data from the LP_UART */
    while (1)
    {
        length = lp_core_uart_read_bytes(LP_UART_PORT_NUM, data, (sizeof(data) - 1), 10);
        if (length > 0)
        {
            for (uint16_t i = 0; i < length; i++)
            {
                sml_state = smlState(data[i]);
                if (sml_state == SML_START)
                {
                }
                if (sml_state == SML_LISTEND)
                {
                    for (config_index = 0; obis_configs[config_index].unit != 0 &&
                                           !(smlOBISCheck(obis_configs[config_index].OBIS));
                         config_index++)
                        ;
                    if (obis_configs[config_index].unit != 0)
                    {
                        smlOBISUnit(&obis_values[config_index], obis_configs[config_index].unit);
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
        }
    }

    return 0;
}
