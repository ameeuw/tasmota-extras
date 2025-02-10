/*
 * SPDX-FileCopyrightText: 2023 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include "ulp_lp_core_print.h"
#include "ulp_lp_core_utils.h"

uint32_t iteration = 0;
volatile uint32_t print_variable = 1337;
volatile float float_variable = 1.23456789;
volatile int int_variable = -123456789;
volatile unsigned int uint_variable = 123456789;
volatile bool bool_variable = true;
volatile char string_variable[] = "Hello, World! This could probably be longer - depending on the amount of ram we are planning to eat up here.";

int main(void)
{
    uint32_t print_variable_local = print_variable;
    // print_variable_local++;
    float float_variable_local = float_variable;
    // float_variable_local++;
    int int_variable_local = int_variable;
    // int_variable_local++;
    unsigned int uint_variable_local = uint_variable;
    // uint_variable_local++;
    bool bool_variable_local = bool_variable;
    // bool_variable_local = !bool_variable_local;
    char string_variable_local = string_variable[0];

    iteration++;

    return 0;
}
