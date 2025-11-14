#/bin/bash
gcc -o gen_matrix_bin gen_matrix_bin.c
nvcc -o matrix_lib_test matrix_lib_test.cu matrix_lib.cu timer.c
./gen_matrix_bin 2048 2048 floats_256_2.0.f.dat
./gen_matrix_bin 2048 2048 floats_256_5.0.f.dat
./matrix_lib_test 5.0 2048 2048 2048 2048 256 4096 1024 floats_256_2.0.f.dat floats_256_5.0.f.dat result1.dat result2.dat
