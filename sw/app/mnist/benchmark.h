#ifndef BENCHMARK_H
#define BENCHMARK_H

#include <time.h>

typedef struct{
    size_t cycles;
    size_t instret;
} Tick_T;

typedef struct {
    double mean;
    int count;
} RunningMean_T;

Tick_T tick(void);
void benchmark(const char* name, Tick_T start, Tick_T end, RunningMean_T timing);

#endif // BENCHMARK_H