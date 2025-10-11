#include <stdio.h>
#include <immintrin.h>
#include <pthread.h>
#include "matrix_lib.h"

#define MAX_PRINT_SIZE 256

struct thread_data {
    long thread_id;
    unsigned long int offset;
    unsigned long int m;
    unsigned long int n;
    unsigned long int p;
    float scalar;
    float *matrix;
    float *matrixA;
    float *matrixB;
};

unsigned long int NUM_THREADS = 1;

void set_number_threads(unsigned long int num_threads) {
    NUM_THREADS = num_threads;
}

void* work_scalar(void *threadarg) {
    struct thread_data *my_data;
    my_data = (struct thread_data*) threadarg;

    __m256 scalar_vec = _mm256_set1_ps(my_data->scalar);
    unsigned long int size = my_data->n;
    float *curr = my_data->matrix + my_data->offset;
    for (unsigned long int i = 0; i < size; i += 8, curr += 8) {
        //matrix->rows[i] *= scalar_value;
        __m256 matrix_vec = _mm256_load_ps(curr);
        __m256 result = _mm256_mul_ps(scalar_vec, matrix_vec);
        _mm256_store_ps(curr, result);
    }

    pthread_exit(NULL);
}

void* work_mult(void *threadarg) {
    struct thread_data *my_data;
    my_data = (struct thread_data*) threadarg;

    float *A = my_data->matrixA + my_data->offset;
    float *B = my_data->matrixB;
    float *C = my_data->matrix + my_data->offset;

    for (unsigned long int i = 0; i < my_data->m; i++) {
        float *currA = A + i * my_data->n;
        for (unsigned long int j = 0; j < my_data->n; j++, currA++) {
            float *currB = B + j * my_data->p;
            float *currC = C + i * my_data->p;
            __m256 a_elem_vec = _mm256_set1_ps(*currA);
            for (unsigned long int k = 0; k < my_data->p; k += 8, currB += 8, currC += 8) {
                __m256 matrixB_vec = _mm256_load_ps(currB);
                __m256 matrixC_vec = _mm256_load_ps(currC);
                __m256 result = _mm256_fmadd_ps(a_elem_vec, matrixB_vec, matrixC_vec);
                _mm256_store_ps(currC, result);
            }
        }
    }

    pthread_exit(NULL);
}

int scalar_matrix_mult(float scalar_value, struct matrix *matrix) {
    if (matrix == NULL || matrix->rows == NULL) return 0;

    pthread_t threads[NUM_THREADS];
    pthread_attr_t attr;
    int rc;
    unsigned long int t;
    void *status;
    struct thread_data thread_data_array[NUM_THREADS];
    unsigned long int size = matrix->height * matrix->width;
    
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

    for (t=0; t<NUM_THREADS; t++){
        printf("In main: creating thread %ld\n", t);
        thread_data_array[t].thread_id = t;
        thread_data_array[t].n = size / NUM_THREADS;
        thread_data_array[t].offset = t * (size / NUM_THREADS);
        thread_data_array[t].scalar = scalar_value;
        thread_data_array[t].matrix = matrix->rows; 

        rc = pthread_create(&threads[t], NULL, work_scalar, (void *)&thread_data_array[t]);
        if (rc) {
            printf("ERROR; return code from pthread_create() is %d\n", rc);
            exit(-1);
        }
    }


    pthread_attr_destroy(&attr);
    for(t=0; t<NUM_THREADS; t++) {
        rc = pthread_join(threads[t], &status);
        if (rc) {
            printf("ERROR; return code from pthread_join() is %d\n", rc);
            exit(-1);
        }
        printf("Main: completed join with thread %ld having a status of %ld\n",t,(long)status);
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
    // for (unsigned long int i = 0; i < AH; i++) {
    //     float *currA = matrixA->rows + i * AW;
    //     for (unsigned long int j = 0; j < AW; j++, currA++) {
    //         float *currB = matrixB->rows + j * BW;
    //         float *currC = matrixC->rows + i * BW;
    //         __m256 a_elem_vec = _mm256_set1_ps(*currA);
    //         for (unsigned long int k = 0; k < BW; k += 8, currB += 8, currC += 8) {
    //             __m256 matrixB_vec = _mm256_load_ps(currB);
    //             __m256 matrixC_vec = _mm256_load_ps(currC);
    //             __m256 result = _mm256_fmadd_ps(a_elem_vec, matrixB_vec, matrixC_vec);
    //             _mm256_store_ps(currC, result);
    //         }
    //     }
    // }

    pthread_t threads[NUM_THREADS];
    pthread_attr_t attr;
    int rc;
    unsigned long int t;
    void *status;
    struct thread_data thread_data_array[NUM_THREADS];
    unsigned long int size = matrixA->height * matrixA->width;
    
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

    for (t=0; t<NUM_THREADS; t++){
        printf("In main: creating thread %ld\n", t);
        thread_data_array[t].thread_id = t;
        thread_data_array[t].offset = t * (size / NUM_THREADS);
        thread_data_array[t].matrix = matrixC->rows;
        thread_data_array[t].m = AH / NUM_THREADS;
        thread_data_array[t].p = BW;
        thread_data_array[t].n = AW;
        thread_data_array[t].matrixA = matrixA->rows;
        thread_data_array[t].matrixB = matrixB->rows;

        rc = pthread_create(&threads[t], NULL, work_mult, (void *)&thread_data_array[t]);
        if (rc) {
            printf("ERROR; return code from pthread_create() is %d\n", rc);
            exit(-1);
        }
    }


    pthread_attr_destroy(&attr);
    for(t=0; t<NUM_THREADS; t++) {
        rc = pthread_join(threads[t], &status);
        if (rc) {
            printf("ERROR; return code from pthread_join() is %d\n", rc);
            exit(-1);
        }
        printf("Main: completed join with thread %ld having a status of %ld\n",t,(long)status);
    }

    printf("\nmatriz a:");
    print_matrix(matrixA);
    printf("\nmatriz b:");
    print_matrix(matrixB);
    printf("\nmatriz c:");
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
