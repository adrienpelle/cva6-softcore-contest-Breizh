#include <stdio.h>


int main() {
    // Main function code

    // Return from main (optional)
    asm volatile (
    "andi t0, t0, 0\n\t"   //# Clear register t0
    "andi t1, t1, 0 \n\t"  //# Clear register t1
    "andi t2, t2, 0\n\t"   //# Clear register t2
    "andi t3, t3, 0 \n\t"  //# Clear register t3
    "andi t4, t4, 0\n\t"   //# Clear register t4

    "li t0, 394   \n\t"    //# Load register t0
    "li t1, 19   \n\t"     //# Load register t1

    "add8 t3, t0, t1\n\t"
        
    "li a7, 10      \n\t"  // syscall: exit
    "ecall           \n\t"
    );

    return 0;
}

