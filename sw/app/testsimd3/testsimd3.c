#include <stdio.h>
#include <stdlib.h>

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


   printf("result = %x", result); 
  
   //wait end of uart frame
   volatile int c, d;  
   for (c = 1; c <= 32767; c++)
    for (d = 1; d <= 32767; d++)
     {}
          
  return(0);
}



