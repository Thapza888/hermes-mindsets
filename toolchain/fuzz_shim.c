/* fallback driver: run one file through LLVMFuzzerTestOneInput (no libFuzzer runtime) */
#include <stdio.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const unsigned char *, size_t);

int main(int argc, char **argv) {
  if (argc < 2) return 2;
  FILE *f = fopen(argv[1], "rb");
  if (!f) return 2;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (n < 0) { fclose(f); return 2; }
  unsigned char *b = malloc((size_t)n + 1);
  size_t got = fread(b, 1, (size_t)n, f);
  fclose(f);
  LLVMFuzzerTestOneInput(b, got);
  free(b);
  return 0;
}
