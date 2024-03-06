#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "rvp_intrinsic.h"

int main(void)
{

  //SMAQA test : CREATE_RVP_INTRINSIC (intXLEN_t, smaqa, intXLEN_t, uintXLEN_t, uintXLEN_t)
  uintXLEN_t a = 0x01020304;
  uintXLEN_t b = 0x05060708;
  intXLEN_t accu = 0x00000009;
  intXLEN_t smaqa_i_result = __rv_smaqa(accu,a, b);
  int smaqa_result = (int)smaqa_i_result; 
  printf("SMAQA Result = %d\n", smaqa_result); //Expect -> 32'h 0000004F = 1x5 + 2x6 + 3x7 + 4x8 + 9 
  
  //wait end of uart frame
  volatile int c, d;  
  for (c = 1; c <= 32767; c++)
    for (d = 1; d <= 32767; d++)
      {}        
  return(0);
}

