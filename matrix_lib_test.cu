#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "matrix_lib.h"
extern "C" {
#include "timer.h"
}

int main(int argc, char *argv[]) {
    if (argc != 10) {
        printf("Usage: %s <scalar> <A_height> <A_width> <B_height> <B_width> <A_file> <B_file> <result1_file> <result2_file>\n", argv[0]);
        return 1;
    }
    float scalar = atof(argv[1]);
    unsigned long int A_height = strtoul(argv[2], NULL, 10);
    unsigned long int A_width  = strtoul(argv[3], NULL, 10);
    unsigned long int B_height = strtoul(argv[4], NULL, 10);
    unsigned long int B_width  = strtoul(argv[5], NULL, 10);
    char *A_file = argv[6];
    char *B_file = argv[7];
    char *result1_file = argv[8];
    char *result2_file = argv[9];

    // Allocate matrices
    struct matrix A = {A_height, A_width, (float *) malloc(A_height * A_width * sizeof(float))};
    struct matrix B = {B_height, B_width, (float *) malloc(B_height * B_width * sizeof(float))};
    struct matrix C = {A_height, B_width, (float *) calloc(A_height * B_width, sizeof(float))};
    if (!A.rows || !B.rows || !C.rows) {
        printf("Memory allocation error.\n");
        return 1;
    }

    // Load matrix A
    FILE *fa = fopen(A_file, "rb");
    if (!fa || fread(A.rows, sizeof(float), A_height * A_width, fa) != A_height * A_width) {
        printf("Error reading matrix A from %s\n", A_file);
        return 1;
    }
    fclose(fa);

    // Load matrix B
    FILE *fb = fopen(B_file, "rb");
    if (!fb || fread(B.rows, sizeof(float), B_height * B_width, fb) != B_height * B_width) {
        printf("Error reading matrix B from %s\n", B_file);
        return 1;
    }
    fclose(fb);

    struct timeval overall_t1, overall_t2, t_start, t_stop;
    gettimeofday(&overall_t1, NULL);

    // Scalar multiplication
    gettimeofday(&t_start, NULL);
    int ok1 = scalar_matrix_mult(scalar, &A);
    gettimeofday(&t_stop, NULL);
    printf("scalar_matrix_mult time: %f ms\n", timedifference_msec(t_start, t_stop));
    if (!ok1) printf("scalar_matrix_mult failed!\n");

    // Save result1
    FILE *fr1 = fopen(result1_file, "wb");
    if (!fr1 || fwrite(A.rows, sizeof(float), A_height * A_width, fr1) != A_height * A_width) {
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
    if (!fr2 || fwrite(C.rows, sizeof(float), A_height * B_width, fr2) != A_height * B_width) {
        printf("Error writing result2 to %s\n", result2_file);
        return 1;
    }
    fclose(fr2);

    gettimeofday(&overall_t2, NULL);
    printf("Overall time: %f ms\n", timedifference_msec(overall_t1, overall_t2));

    free(A.rows); free(B.rows); free(C.rows);
    return 0;
}
