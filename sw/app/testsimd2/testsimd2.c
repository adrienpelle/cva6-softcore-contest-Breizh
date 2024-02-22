#include <stdint.h>
#include "uart.h"

int main(void)
{

    // Inline assembly for the add8 operation
    int result;

    asm volatile (
        // Initialize two 8-bit vectors
        "li a1, 0b01010101;"    // Binary representation of 8-bit vector [85, 85, 85, 85]
        "li a2, 0b10101010;"    // Binary representation of 8-bit vector [170, 170, 170, 170]

        // Perform add8 operation
        "add8 %[result], a1, a2;"

        // Exit the program
        "li a7, 10;"            // System call number for program exit
        "ecall;"
    : [result] "=r" (result)  // Output operand, "=r" means any register
    :                         // No input operands
    : "a1", "a2", "a3"        // Clobbered registers
    );
    
    char message[12];
    snprintf(message, sizeof(message), "%d", result);

     UART_init(&g_uart_0,
             UART_115200_BAUD,
             UART_DATA_8_BITS | UART_NO_PARITY | UART_ONE_STOP_BIT);
                   
     UART_polled_tx_string(&g_uart_0, message);

     while(UART_tx_complete(&g_uart_0)==0);

    return 0;
}

