#include <stdio.h>
#include <assert.h>
#include "randombytes.h"

void randombytes(unsigned char *r,unsigned long long l) {
    FILE *fp = fopen("/dev/urandom", "r");  //TODO Remove hard-coded use of /dev/urandom.
    size_t bytes_read = fread(r, 1, l, fp);
    assert(bytes_read == l);
    fclose(fp);
}
