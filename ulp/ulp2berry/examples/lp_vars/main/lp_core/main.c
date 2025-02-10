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
volatile char string_var[] = "Hello, World! This could probably be longer. Depending on the amount of RAM we are planning to eat up here.";

int main(void)
{
    iteration++;
    (void)float_var;
    (void)int_var;
    (void)uint_var;
    (void)bool_var;
    (void)string_var;
    return 0;
}
