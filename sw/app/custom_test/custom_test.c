#include <stdio.h>
#include <stdint.h>

int main(void)
{
    printf("Begin\n");

    // SMAQA test : CREATE_RVP_INTRINSIC (intXLEN_t, smaqa, intXLEN_t, uintXLEN_t, uintXLEN_t)
    uint32_t operands[2] = {0x01020304, 0x05060708};
    int32_t accu = 0x00000009;
    int smaqa_result;

    asm volatile(
        "cstm_smaqa %[accu], %[a], %[b]\n"
        : [accu] "+r"(accu)
        : [a] "r"(operands[0]), [b] "r"(operands[1])
    );

    smaqa_result = (int)accu;

    printf("SMAQA Result = %d\n", smaqa_result);

    return 0;
}

