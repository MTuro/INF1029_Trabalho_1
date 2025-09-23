#include <stdio.h>
#include <immintrin.h>
#include "matrix_lib.h"

#define MAX_PRINT_SIZE 256

int scalar_matrix_mult(float scalar_value, struct matrix *matrix) {
    if (matrix == NULL || matrix->rows == NULL) return 0;

    __m256 scalar_vec = _mm256_set1_ps(scalar_value);
    unsigned long int size = matrix->height * matrix->width;
    float *curr = matrix->rows;
    for (unsigned long int i = 0; i < size; i += 8, curr += 8) {
        //matrix->rows[i] *= scalar_value;
        __m256 matrix_vec = _mm256_load_ps(curr);
        __m256 result = _mm256_mul_ps(scalar_vec, matrix_vec);
        _mm256_store_ps(curr, result);
    }

    return 1;
}

int matrix_matrix_mult(struct matrix *matrixA, struct matrix *matrixB, struct matrix *matrixC) {
    if (!matrixA || !matrixB || !matrixC) return 0;
    if (!matrixA->rows || !matrixB->rows || !matrixC->rows) return 0;

    // Condição de multiplicação: A.width == B.height
    if (matrixA->width != matrixB->height) return 0;
    if (matrixA->height != matrixC->height || matrixB->width != matrixC->width) return 0;

    unsigned long int AH = matrixA->height;
    unsigned long int AW = matrixA->width;   // também = B.height
    unsigned long int BW = matrixB->width;

    // original
    // for (unsigned long int i = 0; i < AH; i++) {
    //     for (unsigned long int j = 0; j < BW; j++) {
    //         float sum = 0.0f;
    //         for (unsigned long int k = 0; k < AW; k++) {
    //             sum += matrixA->rows[i * AW + k] * matrixB->rows[k * BW + j];
    //         }
    //         matrixC->rows[i * BW + j] = sum;
    //     }
    // }

    // optimized
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

    // vectorial optmized
    for (unsigned long int i = 0; i < AH; i++) {
        float *currA = matrixA->rows + i * AW;
        for (unsigned long int j = 0; j < AW; j++, currA++) {
            float *currB = matrixB->rows + j * BW;
            float *currC = matrixC->rows + i * BW;
            __m256 a_elem_vec = _mm256_set1_ps(*currA);
            for (unsigned long int k = 0; k < BW; k += 8, currB += 8, currC += 8) {
                __m256 matrixB_vec = _mm256_load_ps(currB);
                __m256 matrixC_vec = _mm256_load_ps(currC);
                __m256 result = _mm256_fmadd_ps(a_elem_vec, matrixB_vec, matrixC_vec);
                _mm256_store_ps(currC, result);
            }
        }
    }

    //print_matrix(matrixA);
    //print_matrix(matrixB);
    print_matrix(matrixC);

    return 1;
}

void print_matrix(struct matrix *matrix) {
    unsigned long int printed_count = 0;
    for (unsigned long int i = 0; i < matrix->height && printed_count < MAX_PRINT_SIZE; i++) {
        printf("\n");
        for (unsigned long int j = 0; j < matrix->width && printed_count < MAX_PRINT_SIZE; j++) {
            printf("%.2f ", matrix->rows[i * matrix->width + j]);
            printed_count++;
        }
    }
    printf("\n");
}
