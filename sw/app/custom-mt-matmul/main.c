#include "dataset.h"
#include "util.h"

int main(){
    //static data_t results_data[ARRAY_SIZE];
    //matmul(1, 1, DIM_SIZE, input1_data, input2_data, results_data);
    
    static data_t results_data[ARRAY_SIZE];
    int cid = 0;
    int nc = 1;

    stats(matmul(cid, nc, DIM_SIZE, input1_data, input2_data, results_data), DIM_SIZE/DIM_SIZE/DIM_SIZE);
    
    int res = verify(ARRAY_SIZE, results_data, verify_data);
    printf("res =  %ld \n", res);
    return 0;
}
