#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "rvp_intrinsic.h"


/* // write port
    waddr_i_tb = 4'b0001;      // R1      
    wdata_i_tb = 32'h01020304;

    #100;                      // clk H->L
    // write port
    waddr_i_tb = 4'b0010;      // R2      
    wdata_i_tb = 32'h05060708;

    #100;                      // clk H->L
    // write port
    waddr_i_tb = 4'b0011;      // R3      
    wdata_i_tb = 32'h00000009; // Expect -> 32'h 0000004F = 1x5 + 2x6 + 3x7 + 4x8 + 9 
    */

int main(void)
{
/*   //ADD8 test : CREATE_RVP_INTRINSIC (uintXLEN_t, add8, uintXLEN_t, uintXLEN_t)
  uintXLEN_t add8_i_elements[2] = {0xaa0200ff, 0xaa0300ff};
  uintXLEN_t add8_i_result = __rv_add8(add8_i_elements[0], add8_i_elements[1]);
  int add8_result = (int)add8_i_result; 
  printf("ADD8 Result = %d\n", add8_result);  */

  //SMAQA test : CREATE_RVP_INTRINSIC (intXLEN_t, smaqa, intXLEN_t, uintXLEN_t, uintXLEN_t)
  uintXLEN_t a = 0x01020304;
  uintXLEN_t b = 0x05060708;
  intXLEN_t accu = 0x00000009;
  intXLEN_t result;
  asm volatile (
        // Perform add8 operation
        "smaqa  %[result], %[a], %[b];"
        // Exit the program
        "li a7, 10;"            // System call number for program exit
        "ecall;"
    : [result] "=r" (result)  // Output operand, "=r" means any register
    : [a] "r" (a), [b] "r" (b)// Input operands
    );
  //intXLEN_t smaqa_i_result = __rv_smaqa(accu,smaqa_i_elements[0], smaqa_i_elements[1]);
  //int smaqa_result = (int)smaqa_i_result; 
  int smaqa_result = (int)result; 
  printf("SMAQA Result = %d\n", smaqa_result); //Expect -> 32'h 0000004F = 1x5 + 2x6 + 3x7 + 4x8 + 9 
  
  //wait end of uart frame
  volatile int c, d;  
  for (c = 1; c <= 32767; c++)
    for (d = 1; d <= 32767; d++)
      {}
          
  return(0);
}

