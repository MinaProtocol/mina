#ifndef CRYPTOHASH_BLAKE2S_H
#define CRYPTOHASH_BLAKE2S_H

#include <stdint.h>

#if defined(_MSC_VER)
#define PACKED(x) __pragma(pack(push, 1)) x __pragma(pack(pop))
#else
#define PACKED(x) x __attribute((packed))
#endif

enum blake2s_constant
{
  BLAKE2S_BLOCKBYTES    = 64,
  BLAKE2S_OUTBYTES      = 32,
  BLAKE2S_KEYBYTES      = 32,
  BLAKE2S_SALTBYTES     = 8,
  BLAKE2S_PERSONALBYTES = 8
};

struct blake2s_ctx
{
  uint32_t h[8];
  uint32_t t[2];
  uint32_t f[2];
  uint8_t  buf[BLAKE2S_BLOCKBYTES];
  size_t   buflen;
  size_t   outlen;
  uint8_t  last_node;
};

PACKED(struct blake2s_param
{
  uint8_t  digest_length; /* 1 */
  uint8_t  key_length;    /* 2 */
  uint8_t  fanout;        /* 3 */
  uint8_t  depth;         /* 4 */
  uint32_t leaf_length;   /* 8 */
  uint32_t node_offset;   /* 12 */
  uint16_t xof_length;    /* 14 */
  uint8_t  node_depth;    /* 15 */
  uint8_t  inner_length;  /* 16 */
  uint8_t  salt[BLAKE2S_SALTBYTES]; /* 24 */
  uint8_t  personal[BLAKE2S_PERSONALBYTES]; /* 32 */
});

#define BLAKE2S_DIGEST_SIZE BLAKE2S_BLOCKBYTES
#define BLAKE2S_CTX_SIZE    (sizeof(struct blake2s_ctx))

void digestif_blake2s_init(struct blake2s_ctx *ctx);
void digestif_blake2s_init_with_outlen_and_key(struct blake2s_ctx *ctx, size_t outlen, const void *key, size_t keylen);
void digestif_blake2s_update(struct blake2s_ctx *ctx, uint8_t *data, uint32_t len);
void digestif_blake2s_finalize(struct blake2s_ctx *ctx, uint8_t *out);

#endif
