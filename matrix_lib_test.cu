#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "matrix_lib.h"
extern "C" {
#include "timer.h"
}

int main(int argc, char *argv[]) {
    if (argc != 13) {
        printf("Usage: %s <scalar> <A_height> <A_width> <B_height> <B_width> <Threads_per_Block> <Blocks_per_Grid> <Max_MiB_GPU_Memory> <A_file> <B_file> <result1_file> <result2_file>\n", argv[0]);
        return 1;
    }
    float scalar = atof(argv[1]);
    unsigned long int A_height = strtoul(argv[2], NULL, 10);
    unsigned long int A_width  = strtoul(argv[3], NULL, 10);
    unsigned long int B_height = strtoul(argv[4], NULL, 10);
    unsigned long int B_width  = strtoul(argv[5], NULL, 10);
    unsigned long int threads_per_block = strtoul(argv[6], NULL, 10);
    unsigned long int blocks_per_grid = strtoul(argv[7], NULL, 10);
    unsigned long int max_gpu_memory = strtoul(argv[8], NULL, 10);
    char *A_file = argv[9];
    char *B_file = argv[10];
    char *result1_file = argv[11];
    char *result2_file = argv[12];

    // Set GPU variables
    set_gpu_variables(threads_per_block, blocks_per_grid);

    // Allocate matrices in host
    struct matrix A = {A_height, A_width, (float *) malloc(A_height * A_width * sizeof(float)), NULL, 0};
    struct matrix B = {B_height, B_width, (float *) malloc(B_height * B_width * sizeof(float)), NULL, 0};
    struct matrix C = {A_height, B_width, (float *) calloc(A_height * B_width, sizeof(float)), NULL, 0};
    if (!A.h_rows || !B.h_rows || !C.h_rows) {
        printf("Memory allocation error.\n");
        return 1;
    }

    // Load matrix A
    FILE *fa = fopen(A_file, "rb");
    if (!fa || fread(A.h_rows, sizeof(float), A_height * A_width, fa) != A_height * A_width) {
        printf("Error reading matrix A from %s\n", A_file);
        return 1;
    }
    fclose(fa);

    // Load matrix B
    FILE *fb = fopen(B_file, "rb");
    if (!fb || fread(B.h_rows, sizeof(float), B_height * B_width, fb) != B_height * B_width) {
        printf("Error reading matrix B from %s\n", B_file);
        return 1;
    }
    fclose(fb);

    cudaError_t error;
    // Tries to allocate full matrices in device
    unsigned long int mem_to_alloc = sizeof(float) * (
        A_height * A_width +
        B_height * B_width +
        A_height * B_width) / 1000000;
    if (mem_to_alloc <= max_gpu_memory) {
        printf("Allocating all matrices in GPU\n");
        error = cudaMalloc(&A.d_rows, sizeof(float) * A_height * A_width);
        if (error != cudaSuccess) {
            printf("Error in allocating memory in GPU\n");
            return 1;
        }
        A.alloc_mode = 1; // FULL_ALLOC

        error = cudaMalloc(&B.d_rows, sizeof(float) * B_height * B_width);
        if (error != cudaSuccess) {
            printf("Error in allocating memory in GPU\n");
            return 1;
        }
        B.alloc_mode = 1; // FULL_ALLOC

        error = cudaMalloc(&C.d_rows, sizeof(float) * A_height * B_width);
        if (error != cudaSuccess) {
            printf("Error in allocating memory in GPU\n");
            return 1;
        }
        C.alloc_mode = 1; // FULL_ALLOC
    }
    else {
        mem_to_alloc = sizeof(float) * (A_width + B_height * B_width + B_width) / 1000000;
        if (mem_to_alloc <= max_gpu_memory) {
            printf("Partially allocating matrices in GPU\n");
            error = cudaMalloc(&A.d_rows, sizeof(float) * A_width);
            if (error != cudaSuccess) {
                printf("Error in allocating memory in GPU\n");
                return 1;
            }
            A.alloc_mode = 0; // PARTIAL_ALLOC

            error = cudaMalloc(&B.d_rows, sizeof(float) * B_height * B_width);
            if (error != cudaSuccess) {
                printf("Error in allocating memory in GPU\n");
                return 1;
            }
            B.alloc_mode = 1; // FULL_ALLOC

            error = cudaMalloc(&C.d_rows, sizeof(float) * B_width);
            if (error != cudaSuccess) {
                printf("Error in allocating memory in GPU\n");
                return 1;
            }
            C.alloc_mode = 0; // PARTIAL_ALLOC
        } else {
            printf("Error can't allocate enough memory in GPU. Exiting...\n");
            return 1;
        }
    }
    
    // Transfer matrices to device
    if (A.alloc_mode) {
        error = cudaMemcpy(A.d_rows, A.h_rows, sizeof(float) * A_height * A_width, cudaMemcpyHostToDevice);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    } else {
        error = cudaMemcpy(A.d_rows, A.h_rows, sizeof(float) * A_width, cudaMemcpyHostToDevice);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    }

    if (B.alloc_mode) {
        error = cudaMemcpy(B.d_rows, B.h_rows, sizeof(float) * B_height * B_width, cudaMemcpyHostToDevice);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    } else {
        error = cudaMemcpy(B.d_rows, B.h_rows, sizeof(float) * B_width, cudaMemcpyHostToDevice);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    }

    if (C.alloc_mode) {
        error = cudaMemset(C.d_rows, 0, sizeof(float) * A_height * B_width);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    } else {
        error = cudaMemset(C.d_rows, 0, sizeof(float) * B_width);
        if (error != cudaSuccess) {
            printf("Error transfering data from Host to Device\n");
            return 1;
        }
    }

    struct timeval overall_t1, overall_t2, t_start, t_stop;
    gettimeofday(&overall_t1, NULL);

    // Scalar multiplication
    gettimeofday(&t_start, NULL);
    int ok1 = scalar_matrix_mult(scalar, &A);
    gettimeofday(&t_stop, NULL);
    printf("scalar_matrix_mult time: %f ms\n", timedifference_msec(t_start, t_stop));
    if (!ok1) printf("scalar_matrix_mult failed!\n");

    print_matrix(&A);

    // Save result1
    FILE *fr1 = fopen(result1_file, "wb");
    if (!fr1 || fwrite(A.h_rows, sizeof(float), A_height * A_width, fr1) != A_height * A_width) {
        printf("Error writing result1 to %s\n", result1_file);
        return 1;
    }
    fclose(fr1);

    // Matrix multiplication
    gettimeofday(&t_start, NULL);
    int ok2 = matrix_matrix_mult(&A, &B, &C);
    gettimeofday(&t_stop, NULL);
    printf("matrix_matrix_mult time: %f ms\n", timedifference_msec(t_start, t_stop));
    if (!ok2) printf("matrix_matrix_mult failed!\n");

    // Save result2
    FILE *fr2 = fopen(result2_file, "wb");
    if (!fr2 || fwrite(C.h_rows, sizeof(float), A_height * B_width, fr2) != A_height * B_width) {
        printf("Error writing result2 to %s\n", result2_file);
        return 1;
    }
    fclose(fr2);

    gettimeofday(&overall_t2, NULL);
    printf("Overall time: %f ms\n", timedifference_msec(overall_t1, overall_t2));

    free(A.h_rows); free(B.h_rows); free(C.h_rows);
    cudaFree(A.d_rows); cudaFree(B.d_rows); cudaFree(C.d_rows);
    return 0;
}
