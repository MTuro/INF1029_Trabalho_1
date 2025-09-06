#include <stdio.h>
#include "matrix_lib.h"

int scalar_matrix_mult(float scalar_value, struct matrix *matrix) {
    if (matrix == NULL || matrix->rows == NULL) return 0;

    unsigned long int size = matrix->height * matrix->width;
    for (unsigned long int i = 0; i < size; i++) {
        matrix->rows[i] *= scalar_value;
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

    // for (unsigned long int i = 0; i < AH; i++) {
    //     for (unsigned long int j = 0; j < BW; j++) {
    //         float sum = 0.0f;
    //         for (unsigned long int k = 0; k < AW; k++) {
    //             sum += matrixA->rows[i * AW + k] * matrixB->rows[k * BW + j];
    //         }
    //         matrixC->rows[i * BW + j] = sum;
    //     }
    // }

 
    for (unsigned long int i = 0; i < AH * AW; i++) {
        for (unsigned long int j = 0; j < BW * AW; j++) {
            matrixC->rows[(i * AH) + (j % BW)] += matrixA->rows[i] * matrixB->rows[j];
        }
    }


    return 1;
}
