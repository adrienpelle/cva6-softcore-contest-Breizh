// See LICENSE for license details.

#include "dataset.h"
#include "util.h"
#include <stddef.h>
#include "rvp_intrinsic.h"

//#pragma GCC optimize ("unroll-loops")

/* // SMAQA test : CREATE_RVP_INTRINSIC (intXLEN_t, smaqa, intXLEN_t, uintXLEN_t, uintXLEN_t)
    uint32_t operands[2] = {0x01020304, 0x05060708};
    int32_t accu = 0x00000009;
    int smaqa_result;

    asm volatile(
        "smaqa %[accu], %[a], %[b]\n"
        : [accu] "+r"(accu)
        : [a] "r"(operands[0]), [b] "r"(operands[1])
    );

    smaqa_result = (int)accu;

    printf("SMAQA Result = %d\n", smaqa_result); */


void simd_matmul(const size_t coreid, const size_t ncores, const size_t lda,  const data_t A[], const data_t B[], data_t C[])
{
  size_t i, j, k;
  size_t block = lda / ncores;
  size_t start = block * coreid;
 
  for (i = 0; i < lda; i++) {
    for (j = start; j < (start+block); j++) {
      data_t sum = 0;
      for (k = 0; k < lda; k++)
        sum += A[j*lda + k] * B[k*lda + i];
      C[i + j*lda] = sum;
    }
  }
}

