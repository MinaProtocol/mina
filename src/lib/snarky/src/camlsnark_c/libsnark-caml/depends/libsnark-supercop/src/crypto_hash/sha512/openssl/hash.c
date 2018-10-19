#include <stddef.h>
#include <openssl/sha.h>
#include "crypto_hash_sha512.h"

int crypto_hash_sha512(unsigned char *out,const unsigned char *in,unsigned long long inlen)
{
  SHA512(in,inlen,out);
  return 0;
}
