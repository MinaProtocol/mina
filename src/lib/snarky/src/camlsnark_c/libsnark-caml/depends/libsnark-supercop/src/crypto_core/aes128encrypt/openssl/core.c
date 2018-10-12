#include <openssl/aes.h>
#include "crypto_core_aes128encrypt.h"

int crypto_core_aes128encrypt_openssl(
        unsigned char *out,
  const unsigned char *in,
  const unsigned char *k,
  const unsigned char *c
)
{
  AES_KEY kexp;
  AES_set_encrypt_key(k,128,&kexp);
  AES_encrypt(in,out,&kexp);
  return 0;
}
