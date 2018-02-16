#ifndef crypto_verify_8_H
#define crypto_verify_8_H

#define crypto_verify_8_ref_BYTES 8
 
#ifdef __cplusplus
extern "C" {
#endif
extern int crypto_verify_8_ref(const unsigned char *,const unsigned char *);
#ifdef __cplusplus
}
#endif

#define crypto_verify_8 crypto_verify_8_ref
#define crypto_verify_8_BYTES crypto_verify_8_ref_BYTES
#define crypto_verify_8_IMPLEMENTATION "crypto_verify/8/ref"
#ifndef crypto_verify_8_ref_VERSION
#define crypto_verify_8_ref_VERSION "-"
#endif
#define crypto_verify_8_VERSION crypto_verify_8_ref_VERSION

#endif
