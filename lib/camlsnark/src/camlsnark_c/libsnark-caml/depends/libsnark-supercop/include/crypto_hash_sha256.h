#ifndef crypto_hash_sha256_H
#define crypto_hash_sha256_H

#define crypto_hash_sha256_sphlib_BYTES 32
#define crypto_hash_sha256_sphlib_VERSION "SPHLIB 3.0"
 
#ifdef __cplusplus
extern "C" {
#endif
extern int crypto_hash_sha256_sphlib(unsigned char *,const unsigned char *,unsigned long long);
#ifdef __cplusplus
}
#endif

#define crypto_hash_sha256 crypto_hash_sha256_sphlib
#define crypto_hash_sha256_BYTES crypto_hash_sha256_sphlib_BYTES
#define crypto_hash_sha256_IMPLEMENTATION "crypto_hash/sha256/sphlib"
#ifndef crypto_hash_sha256_sphlib_VERSION
#define crypto_hash_sha256_sphlib_VERSION "-"
#endif
#define crypto_hash_sha256_VERSION crypto_hash_sha256_sphlib_VERSION

#endif
