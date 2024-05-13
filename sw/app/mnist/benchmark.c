#include "benchmark.h"
#include "util.h"
#include <stdio.h>

Tick_T tick(void) {
    Tick_T t = {read_csr(mcycle), read_csr(minstret)};
    return t;
}

void benchmark(const char* name, Tick_T start, Tick_T end, RunningMean_T timing) {
    size_t cycles = ((size_t) (end.cycles - start.cycles));
    size_t insts = ((size_t) (end.instret - start.instret));
    //timing->count++;
    //timing->mean = ((timing->mean * (timing->count - 1)) + duration) / timing->count;
    //printf("%s: %f\n", name, timing->mean);
    printf("%s: %d insts, %d cycles\n", name, insts, cycles);
}