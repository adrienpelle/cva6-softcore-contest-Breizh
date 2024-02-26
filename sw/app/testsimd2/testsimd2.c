#include <stdint.h>
#include "uart.h"

int main(void)
{

    // Inline assembly for the add8 operation
    int32_t elements[2] = {0xaa0200ff, 0xaa0300ff};

    // Load 32-bit elements from the array
    int32_t element1 = elements[0];
    int32_t element2 = elements[1];

    // Perform add8 operation on the loaded 32-bit elements
    int32_t result;

    asm volatile (
        // Perform add8 operation
        "add8 %[result], %[element1], %[element2];"
        // Exit the program
        "li a7, 10;"            // System call number for program exit
        "ecall;"
    : [result] "=r" (result)  // Output operand, "=r" means any register
    : [element1] "r" (element1), [element2] "r" (element2)  // Input operands
    : "a1", "a2", "a3"        // Clobbered registers
    );
    
    int8_t octet1 = (result >> 24) & 0xFF;
    int8_t octet2 = (result >> 16) & 0xFF;
    int8_t octet3 = (result >> 8) & 0xFF;
    int8_t octet4 = result & 0xFF;
    
    char buffer[55];
    //snprintf(buffer, 55, "Y[7:0] = %u,Y[15:8] = %u, Y[23:16] = %u, Y[31:24] = %u", octet1, octet2, octet3, octet4);
    snprintf(buffer, 55, "Y = %d", result);

     UART_init(&g_uart_0,
             UART_115200_BAUD,
             UART_DATA_8_BITS | UART_NO_PARITY | UART_ONE_STOP_BIT);
                   
     UART_polled_tx_string(&g_uart_0, buffer);

     while(UART_tx_complete(&g_uart_0)==0);

    return 0;
}

