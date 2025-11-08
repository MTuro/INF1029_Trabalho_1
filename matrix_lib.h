#ifndef MATRIX_LIB_H
#define MATRIX_LIB_H

struct matrix {
    unsigned long int height;   // número de linhas (múltiplo de 8)
    unsigned long int width;    // número de colunas (múltiplo de 8)
    float *h_rows;              // vetor com height*width floats no host
    float *d_rows;              // vetor com height*width floats no device
    int alloc_mode;             // modo de alocação: FULL_ALLOC(1), PARTIAL_ALLOC(0)
};

// Define Blocos por Grid e Threads por Bloco
void set_gpu_variables(unsigned long int threadsPerBlock, unsigned long int blocksPerGrid);

// Multiplicação escalar * matriz
int scalar_matrix_mult(float scalar_value, struct matrix *matrix);

// Multiplicação de matrizes A * B = C
int matrix_matrix_mult(struct matrix *matrixA, struct matrix *matrixB, struct matrix *matrixC);

// Print de matriz
void print_matrix(struct matrix *matrix);

#endif
