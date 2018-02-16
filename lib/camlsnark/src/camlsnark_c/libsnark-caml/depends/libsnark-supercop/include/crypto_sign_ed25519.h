#ifndef crypto_sign_ed25519_H
#define crypto_sign_ed25519_H

#define crypto_sign_ed25519_amd64_51_30k_SECRETKEYBYTES 64
#define crypto_sign_ed25519_amd64_51_30k_PUBLICKEYBYTES 32
#define crypto_sign_ed25519_amd64_51_30k_BYTES 64
#define crypto_sign_ed25519_amd64_51_30k_DETERMINISTIC 1
 
#ifdef __cplusplus
extern "C" {
#endif
extern int crypto_sign_ed25519_amd64_51_30k(unsigned char *,unsigned long long *,const unsigned char *,unsigned long long,const unsigned char *);
extern int crypto_sign_ed25519_amd64_51_30k_open(unsigned char *,unsigned long long *,const unsigned char *,unsigned long long,const unsigned char *);
extern int crypto_sign_ed25519_amd64_51_30k_keypair(unsigned char *,unsigned char *);
extern int crypto_sign_ed25519_amd64_51_30k_open_batch(
    unsigned char* const m[],unsigned long long mlen[],
    unsigned char* const sm[],const unsigned long long smlen[],
    unsigned char* const pk[], 
    unsigned long long num
    );
#ifdef __cplusplus
}
#endif

#define crypto_sign_ed25519 crypto_sign_ed25519_amd64_51_30k
#define crypto_sign_ed25519_open crypto_sign_ed25519_amd64_51_30k_open
#define crypto_sign_ed25519_keypair crypto_sign_ed25519_amd64_51_30k_keypair
#define crypto_sign_ed25519_BYTES crypto_sign_ed25519_amd64_51_30k_BYTES
#define crypto_sign_ed25519_SECRETKEYBYTES crypto_sign_ed25519_amd64_51_30k_SECRETKEYBYTES
#define crypto_sign_ed25519_PUBLICKEYBYTES crypto_sign_ed25519_amd64_51_30k_PUBLICKEYBYTES
#define crypto_sign_ed25519_DETERMINISTIC crypto_sign_ed25519_amd64_51_30k_DETERMINISTIC
#define crypto_sign_ed25519_IMPLEMENTATION "crypto_sign/ed25519/amd64-51-30k"
#ifndef crypto_sign_ed25519_amd64_51_30k_VERSION
#define crypto_sign_ed25519_amd64_51_30k_VERSION "-"
#endif
#define crypto_sign_ed25519_VERSION crypto_sign_ed25519_amd64_51_30k_VERSION

#endif
