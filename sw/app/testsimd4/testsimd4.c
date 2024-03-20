#include <stdio.h>
#include <stdint.h>
#include "rvp_intrinsic.h"

int main(void)
{
    printf("Begin\n");

    // SMAQA test : CREATE_RVP_INTRINSIC (intXLEN_t, smaqa, intXLEN_t, uintXLEN_t, uintXLEN_t)
    uint32_t operands[2] = {0x0, 0xffffffff};
    uint8_t inputs[4] = {0, 0, 5, 4};
    int8_t weights[16] = {-2, -2, -6, -14, -10, -10, 1, 5, -4, 1, -5, 7, -2, -2, -6, -14};
    int32_t* accu;
    uint32_t* inputs_ptr = &inputs;
    int32_t* weights_ptr = &weights;
    int smaqa_result;

    *accu = 0;
    int32_t sum = 0;

    //intXLEN_t smaqa_i_result = __rv_smaqa(accu,operands[0], operands[1]);

    asm volatile(
        "smaqa %[accu], %[a], %[b]\n"
        : [accu] "r+"(sum)
        : [a] "r"(inputs_ptr[0]), [b] "r"(weights_ptr[0])
    );

    *accu = sum;    

/* asm volatile(
    "lw a3, %[ptr_accu]\n"
    "smaqa %[result], a3, %[a], %[b]\n"
    : [result] "=r"(*accu)
    : [a] "r"(operands[0]), [b] "r"(operands[1]), [ptr_accu] "m"(*accu)
    : "a3"
); */
    smaqa_result = (int)sum;

    printf("SMAQA Result = %d\n", smaqa_result);

    return 0;
}
