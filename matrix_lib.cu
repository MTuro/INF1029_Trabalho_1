#include <stdio.h>
#include <cuda_runtime.h>
#include "matrix_lib.h"

#define MAX_PRINT_SIZE 256

unsigned long int blocksPerGrid = 1;
unsigned long int threadsPerBlock = 1;

__host__
void set_gpu_variables(unsigned long int tpb, unsigned long int bpg) {
    threadsPerBlock = tpb;
    blocksPerGrid = bpg;
}

__global__ 
void scalar_mult(unsigned long int n, unsigned long int offset, float scalar, float *rows)
{
    unsigned long int index = blockIdx.x * blockDim.x + threadIdx.x;
   
    if (index < n) {
    	rows[index + offset] *= scalar;
    }
}

__host__
int scalar_matrix_mult(float scalar_value, struct matrix *matrix) {
    if (matrix == NULL || matrix->h_rows == NULL || matrix->d_rows == NULL) return 0;

    unsigned long int N;
    unsigned long int size;
    
    // Allocation type
    if (matrix->alloc_mode) {
        printf("Full alloc scalar_matrix_mult\n");
        N = matrix->height * matrix->width;
        size = N * sizeof(float);

        unsigned long int blockSize = threadsPerBlock;
        unsigned long int numBlocks = (N + blockSize - 1) / blockSize;
        if (numBlocks > blocksPerGrid) numBlocks = blocksPerGrid;
        unsigned long int threads = blockSize * numBlocks;

        // Not enough threads for 1 call
        if (N > threads) {
            unsigned long int it = N / threads;
            unsigned long int n = threads;
            unsigned long int remaining;
            printf("it: %lu; n: %lu;\n", it, n);
            // Use fixed base pointer (matrix->d_rows) and offset into it.
            for (unsigned long int i = 0; i < it; i++) {
                scalar_mult<<<numBlocks, blockSize>>>(n, n*i, scalar_value, matrix->d_rows);
            }
            // last (partial) iteration, if any
            remaining = N - it * n;
            if (remaining > 0) {
                scalar_mult<<<numBlocks, blockSize>>>(remaining, it * n, scalar_value, matrix->d_rows);
            }
        // Enough threads for 1 call
        } else {
            scalar_mult<<<numBlocks, blockSize>>>(N, 0, scalar_value, matrix->d_rows);
        }
        
        cudaDeviceSynchronize();
        cudaMemcpy(matrix->h_rows, matrix->d_rows, size, cudaMemcpyDeviceToHost);
    } else {
        printf("Partial alloc scalar_matrix_mult\n");
        N = matrix->width;
        size = N * sizeof(float);

        // Makes sure memory is at start
        int blockSize = threadsPerBlock;
        int numBlocks = (N + blockSize - 1) / blockSize;
        if (numBlocks > blocksPerGrid) numBlocks = blocksPerGrid;
        unsigned long int threads = blockSize * numBlocks;
        
        // Not enough threads for 1 call per line
        if (N > threads) {
            unsigned long int it = N / threads;
            unsigned long int n = threads;
            unsigned long int remaining;
            printf("it: %lu; n: %lu;\n", it, n);
            for (unsigned long int i = 0; i < matrix->height; i++) {
                // copy one row to device
                cudaMemcpy(matrix->d_rows, matrix->h_rows + N * i, size, cudaMemcpyHostToDevice);
                // launch full chunks using fixed base pointer and offsets
                for (unsigned long int j = 0; j < it; j++) {
                    scalar_mult<<<numBlocks, blockSize>>>(n, n*j, scalar_value, matrix->d_rows);
                }
                // last partial chunk if necessary
                remaining = N - it * n;
                if (remaining > 0) {
                    scalar_mult<<<numBlocks, blockSize>>>(remaining, it * n, scalar_value, matrix->d_rows);
                }
                cudaDeviceSynchronize();
                cudaMemcpy(matrix->h_rows + N * i, matrix->d_rows, size, cudaMemcpyHostToDevice);
            }
        // Enough threads for 1 call per line
        } else {
            for (unsigned long int i = 0; i < matrix->height; i++) {
                cudaMemcpy(matrix->d_rows, matrix->h_rows + N * i, size, cudaMemcpyHostToDevice);
                scalar_mult<<<numBlocks, blockSize>>>(N, 0, scalar_value, matrix->d_rows);
                cudaDeviceSynchronize();
                cudaMemcpy(matrix->h_rows + N * i, matrix->d_rows, size, cudaMemcpyHostToDevice);
            }
        }
    }
    
    return 1;
}

int matrix_matrix_mult(struct matrix *matrixA, struct matrix *matrixB, struct matrix *matrixC) {
    if (!matrixA || !matrixB || !matrixC) return 0;
    if (!matrixA->h_rows || !matrixB->h_rows || !matrixC->h_rows) return 0;
    if (!matrixA->d_rows || !matrixB->d_rows || !matrixC->d_rows) return 0;

    // Condição de multiplicação: A.width == B.height
    if (matrixA->width != matrixB->height) return 0;
    if (matrixA->height != matrixC->height || matrixB->width != matrixC->width) return 0;

    unsigned long int AH = matrixA->height;
    unsigned long int AW = matrixA->width;   // também = B.height
    unsigned long int BW = matrixB->width;

    // for (unsigned long int i = 0; i < AH; i++) {
        // for (unsigned long int j = 0; j < BW; j++) {
           //  float sum = 0.0f;
           //  for (unsigned long int k = 0; k < AW; k++) {
           //      sum += matrixA->rows[i * AW + k] * matrixB->rows[k * BW + j];
         //    }
         //    matrixC->rows[i * BW + j] = sum;
       //  }
     //}

    // for (unsigned long int i = 0; i < AH; i++) {
    //     unsigned long int i_AW = i * AW;
    //     unsigned long int i_BW = i * BW;
    //     for (unsigned long int j = 0; j < AW; j++) {
    //         float a_elem = matrixA->rows[i_AW + j];
    //         unsigned long int j_BW = j * BW;
    //         for (unsigned long int k = 0; k < BW; k++) {
    //             matrixC->rows[i_BW + k] +=  a_elem * matrixB->rows[j_BW + k];
    //         }
    //     }
    // }

    //print_matrix(matrixA);
    //print_matrix(matrixB);
    //print_matrix(matrixC);

    return 1;
}

void print_matrix(struct matrix *matrix) {
    unsigned long int printed_count = 0;
    for (unsigned long int i = 0; i < matrix->height && printed_count < MAX_PRINT_SIZE; i++) {
        printf("\n");
        for (unsigned long int j = 0; j < matrix->width && printed_count < MAX_PRINT_SIZE; j++) {
            printf("%.2f ", matrix->h_rows[i * matrix->width + j]);
            printed_count++;
        }
    }
    printf("\n");
}
