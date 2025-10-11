#ifndef MATRIX_LIB_H
#define MATRIX_LIB_H

struct matrix {
    unsigned long int height;   // número de linhas (múltiplo de 8)
    unsigned long int width;    // número de colunas (múltiplo de 8)
    float *rows;                // vetor com height*width floats
};

// Define o numero de threads
void set_number_threads(unsigned long int num_threads);

// Multiplicação escalar * matriz
int scalar_matrix_mult(float scalar_value, struct matrix *matrix);

// Multiplicação de matrizes A * B = C
int matrix_matrix_mult(struct matrix *matrixA, struct matrix *matrixB, struct matrix *matrixC);

// Print de matriz
void print_matrix(struct matrix *matrix);

#endif
