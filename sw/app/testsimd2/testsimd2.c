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
  uintXLEN_t* inputs_ptr;
  intXLEN_t* weights_ptr;
  intXLEN_t* weightedSum;

  inputs_ptr = (uint8x4_t*)malloc(2 * sizeof(uint8x4_t));
  weights_ptr = (int8x4_t*)malloc(2 * sizeof(int8x4_t));
  weightedSum = (intXLEN_t*)malloc(sizeof(intXLEN_t));

  inputs_ptr[0] = 0x01020304;
  inputs_ptr[1] = 0x00000004;
  weights_ptr[0] = 0x05060708;
  weights_ptr[1] = 0x00000001;
  weightedSum[0] = 0x00000009;

  int iter = 0;

  // asm volatile(
  //               "lw s6, 0(%[inputs_ptr])\n"  // Load input from memory into $a1
  //               "lw s7, 0(%[weights_ptr])\n" // Load weight from memory into $a2
  //               "smaqa %[result], s6, s7\n" // Perform the operation with $a1 and $a3
  //               : [result] "+r"(*weightedSum) // Output operand
  //               : [inputs_ptr] "r"(&inputs_ptr[iter]), [weights_ptr] "r"(&weights_ptr[iter]) // Input operands
  //               : "s6", "s7" // Clobbered registers
  //               );

  asm volatile(
        "lw a1, 0(%[inputs_ptr])\n"  // Load input from memory into $a1
        "lw a3, 0(%[weights_ptr])\n" // Load weight from memory into $a3
        "lw a2, 4(%[inputs_ptr])\n"  // Load input from memory into $a2
        "lw a4, 4(%[weights_ptr])\n" // Load weight from memory into $a4
        "cstm_smaqa %[result], a1, a3\n" // Perform the operation with $a1 and $a3
        //"smaqa %[result], a2, a4\n" // Perform the operation with $a2 and $a4
        : [result] "+r"(*weightedSum) // Output operand
        : [inputs_ptr] "r"(&inputs_ptr[iter]), [weights_ptr] "r"(&weights_ptr[iter]) // Input operands
        : "a1", "a2", "a3", "a4" // Clobbered registers
    );




  //intXLEN_t smaqa_i_result = __rv_smaqa(accu,smaqa_i_elements[0], smaqa_i_elements[1]);
  //int smaqa_result = (int)smaqa_i_result; 
  printf("SMAQA Result = %d\n", weightedSum[0]); //Expect -> 32'h 0000004F = 1x5 + 2x6 + 3x7 + 4x8 + 9 
  
  //wait end of uart frame
  volatile int c, d;  
  for (c = 1; c <= 32767; c++)
    for (d = 1; d <= 32767; d++)
      {}
          
  return(0);
}

