#include <stdio.h>
#include <stdlib.h>
#include <>

int main(void)
{

    // Inline assembly for the add8 operation
    int a, b, r;
    r = __rv__add8(a,b);
   printf("XXXXXX");		
   printf("result = %x", r); 
   printf("YYYYYY");
   //wait end of uart frame
   volatile int c, d;  
   for (c = 1; c <= 32767; c++)
    for (d = 1; d <= 32767; d++)
     {}
          
  return(0);
}



