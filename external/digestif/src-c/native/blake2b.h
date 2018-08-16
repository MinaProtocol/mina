#ifndef CRYPTOHASH_BLAKE2B_H
#define CRYPTOHASH_BLAKE2B_H

#include <stdint.h>

#if defined(_MSC_VER)
#define PACKED(x) __pragma(pack(push, 1)) x __pragma(pack(pop))
#else
#define PACKED(x) x __attribute((packed))
#endif

enum blake2b_constant
{
  BLAKE2B_BLOCKBYTES    = 128,
  BLAKE2B_OUTBYTES      = 64,
  BLAKE2B_KEYBYTES      = 64,
  BLAKE2B_SALTBYTES     = 16,
  BLAKE2B_PERSONALBYTES = 16
};

struct blake2b_ctx
{
  uint64_t h[8];
  uint64_t t[2];
  uint64_t f[2];
  uint8_t  buf[BLAKE2B_BLOCKBYTES];
  size_t   buflen;
  size_t   outlen;
  uint8_t  last_node;
};

PACKED(struct blake2b_param
{
  uint8_t  digest_length; /* 1 */
  uint8_t  key_length;    /* 2 */
  uint8_t  fanout;        /* 3 */
  uint8_t  depth;         /* 4 */
  uint32_t leaf_length;   /* 8 */
  uint32_t node_offset;   /* 12 */
  uint32_t xof_length;    /* 16 */
  uint8_t  node_depth;    /* 17 */
  uint8_t  inner_length;  /* 18 */
  uint8_t  reserved[14];  /* 32 */
  uint8_t  salt[BLAKE2B_SALTBYTES]; /* 48 */
  uint8_t  personal[BLAKE2B_PERSONALBYTES];  /* 64 */
});

#define BLAKE2B_DIGEST_SIZE BLAKE2B_BLOCKBYTES
#define BLAKE2B_CTX_SIZE    (sizeof(struct blake2b_ctx))

void digestif_blake2b_init(struct blake2b_ctx *ctx);
void digestif_blake2b_init_with_outlen_and_key(struct blake2b_ctx *ctx, size_t outlen, const void *key, size_t keylen);
void digestif_blake2b_update(struct blake2b_ctx *ctx, uint8_t *data, uint32_t len);
void digestif_blake2b_finalize(struct blake2b_ctx *ctx, uint8_t *out);

#endif
