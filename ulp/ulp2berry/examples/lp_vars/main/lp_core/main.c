/*
 * SPDX-FileCopyrightText: 2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include "ulp_lp_core_utils.h"

uint32_t iteration = 0;
volatile float float_var = 1.23456789;
volatile int32_t int_var = -123456789;
volatile uint32_t uint_var = 123456789;
volatile bool bool_var = true;
volatile char string_var[] = "Hello, World! This could probably be longer. \nDepending on the amount of ram we are planning to eat up here.";

int main(void)
{
    iteration++;

    float float_var_local = float_var;
    int int_var_local = int_var;
    unsigned int uint_var_local = uint_var;
    bool bool_var_local = bool_var;
    char string_var_local = string_var[0];
    return 0;
}
