#/bin/bash
gcc -o gen_matrix_bin gen_matrix_bin.c
gcc -g -std=c11 -mfma -o matrix_lib_test matrix_lib_test.c matrix_lib.c timer.c
./gen_matrix_bin 2048 2048 floats_256_2.0.f.dat
./gen_matrix_bin 2048 2048 floats_256_5.0.f.dat
./matrix_lib_test 5.0 2048 2048 2048 2048 floats_256_2.0.f.dat floats_256_5.0.f.dat result1.dat result2.dat
