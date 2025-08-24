#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s <rows> <cols> <output_file>\n", argv[0]);
        return 1;
    }
    unsigned long int rows = strtoul(argv[1], NULL, 10);
    unsigned long int cols = strtoul(argv[2], NULL, 10);
    char *filename = argv[3];
    FILE *f = fopen(filename, "wb");
    if (!f) {
        printf("Error opening file %s\n", filename);
        return 1;
    }
    for (unsigned long int i = 0; i < rows * cols; ++i) {
        float val = (float)(i + 1); // Example: fill with 1, 2, 3, ...
        fwrite(&val, sizeof(float), 1, f);
    }
    fclose(f);
    printf("Generated %lu floats in %s\n", rows * cols, filename);
    return 0;
}
