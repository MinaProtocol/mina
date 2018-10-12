#ifndef crypto_hash_sha512_H
#define crypto_hash_sha512_H

#include <openssl/rand.h>
#include <stddef.h>
#include <openssl/opensslv.h>
#define crypto_hash_sha512_openssl_VERSION OPENSSL_VERSION_TEXT
#define crypto_hash_sha512_openssl_BYTES 64

#ifdef __cplusplus
extern "C" {
#endif
extern int crypto_hash_sha512_openssl(unsigned char *,const unsigned char *,unsigned long long);
#ifdef __cplusplus
}
#endif

#define crypto_hash_sha512 crypto_hash_sha512_openssl
#define crypto_hash_sha512_BYTES crypto_hash_sha512_openssl_BYTES
#define crypto_hash_sha512_IMPLEMENTATION "crypto_hash/sha512/openssl"
#ifndef crypto_hash_sha512_openssl_VERSION
#define crypto_hash_sha512_openssl_VERSION "-"
#endif
#define crypto_hash_sha512_VERSION crypto_hash_sha512_openssl_VERSION

#endif
