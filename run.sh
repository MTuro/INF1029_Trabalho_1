#/bin/bash
gcc -o gen_matrix_bin gen_matrix_bin.c
nvcc -o matrix_lib_test matrix_lib_test.cu matrix_lib.cu timer.c
./gen_matrix_bin 256 256 floats_256_2.0.f.dat
./gen_matrix_bin 1024 1024 floats_256_5.0.f.dat
./matrix_lib_test 5.0 256 256 1024 1024 3 2 4 floats_256_2.0.f.dat floats_256_5.0.f.dat result1.dat result2.dat
