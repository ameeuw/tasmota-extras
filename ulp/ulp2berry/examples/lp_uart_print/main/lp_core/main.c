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
uint32_t print_variable = 1337;

uint32_t sml_unexpected_count = 0;

const unsigned char obisT1wh[6] = {0x01, 0x00, 0x01, 0x08, 0x01, 0xff};
long long int sml_t1wh;
int sml_t1wh_scaler;

const unsigned char obisSumwh[6] = {0x01, 0x00, 0x01, 0x08, 0x00, 0xff};
long long int sml_sumwh;
int sml_sumwh_scaler;

typedef struct
{
    const unsigned char OBIS[6];
    void (*Handler)();
} OBISHandler;

void PowerT1()
{
    signed char scaler;
    long long int value = smlOBISByUnit(&scaler, SML_WATT_HOUR);
    if (value != -1)
    {
        // sml_t1wh_tmp = smlPow(value, scaler);
        sml_t1wh = value;
        sml_t1wh_scaler = scaler;
    }
}

void PowerSum()
{
    signed char scaler;
    long long int value = smlOBISByUnit(&scaler, SML_WATT_HOUR);
    if (value != -1)
    {
        // sml_t1wh_tmp = smlPow(value, scaler);
        sml_sumwh = value;
        sml_sumwh_scaler = scaler;
    }
}

OBISHandler OBISHandlers[] = {
    {{0x01, 0x00, 0x01, 0x08, 0x01, 0xff}, PowerT1},  /*   1-  0:  1.  8.1*255 (T1) */
    {{0x01, 0x00, 0x01, 0x08, 0x00, 0xff}, PowerSum}, /*   1-  0:  1.  8.0*255 (T1 + T2) */
    {{0, 0}}};

#define LP_UART_PORT_NUM LP_UART_NUM_0

int main(void)
{
    sml_states_t sml_state;

    uint8_t sml_byte;
    uint8_t iHandler = 0;

    iteration++;
    print_variable++;

    /* Read data from the LP_UART */
    // while (lp_core_uart_read_bytes(LP_UART_PORT_NUM, &sml_byte, 1, 10) == 1)
    for (uint16_t i = 0; i < ehz_bin_len; i++)
    {
        sml_byte = ehz_bin[i];
        sml_state = smlState(sml_byte);
        if (sml_state == SML_START)
        {
            /* reset local vars */
            sml_t1wh = -3;
            sml_sumwh = -3;
        }
        if (sml_state == SML_LISTEND)
        {
            for (iHandler = 0; OBISHandlers[iHandler].Handler != 0 &&
                               !(smlOBISCheck(OBISHandlers[iHandler].OBIS));
                 iHandler++)
                ;
            if (OBISHandlers[iHandler].Handler != 0)
            {
                OBISHandlers[iHandler].Handler();
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
