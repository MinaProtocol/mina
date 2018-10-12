#include <string.h>
#include "blake2b.h"
#include "bitfn.h"

static const uint64_t IV[8] =
{
  0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL,
  0x3c6ef372fe94f82bULL, 0xa54ff53a5f1d36f1ULL,
  0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL,
  0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL
};

static const uint8_t sigma[12][16] =
{
  {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 } ,
  { 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 } ,
  { 11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4 } ,
  {  7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8 } ,
  {  9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13 } ,
  {  2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9 } ,
  { 12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11 } ,
  { 13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10 } ,
  {  6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5 } ,
  { 10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13 , 0 } ,
  {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 } ,
  { 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 }
};

#include <stdint.h>

static const struct blake2b_param P[] =
  { { BLAKE2B_OUTBYTES /* digest_length */
    , 0 /* key_length */
    , 1 /* fanout */
    , 1 /* depth */
    , 0 /* leaf_length */
    , 0 /* node_offset */
    , 0 /* xof_length */
    , 0 /* node_depth */
    , 0 /* inner_length */
    , { 0 } /* reserver[14] */
    , { 0 } /* salt[BLAKE2B_SLATBYTES] */
    , { 0 } /* personal[BLAKE2B_PERSONALBYTES] */ } };

static void blake2b_increment_counter( struct blake2b_ctx *ctx, const uint64_t inc )
{
  ctx->t[0] += inc;
  ctx->t[1] += ( ctx->t[0] < inc );
}

static void blake2b_set_lastnode( struct blake2b_ctx *ctx )
{
  ctx->f[1] = (uint64_t)-1;
}

static void blake2b_set_lastblock( struct blake2b_ctx *ctx )
{
  if( ctx->last_node ) blake2b_set_lastnode( ctx );

  ctx->f[0] = (uint64_t)-1;
}

#define G(r,i,a,b,c,d)                      \
  do {                                      \
    a = a + b + m[sigma[r][2*i+0]];         \
    d = ror64(d ^ a, 32);                   \
    c = c + d;                              \
    b = ror64(b ^ c, 24);                   \
    a = a + b + m[sigma[r][2*i+1]];         \
    d = ror64(d ^ a, 16);                   \
    c = c + d;                              \
    b = ror64(b ^ c, 63);                   \
  } while(0)

#define R(r)                        \
  do {                              \
    G(r,0,v[ 0],v[ 4],v[ 8],v[12]); \
    G(r,1,v[ 1],v[ 5],v[ 9],v[13]); \
    G(r,2,v[ 2],v[ 6],v[10],v[14]); \
    G(r,3,v[ 3],v[ 7],v[11],v[15]); \
    G(r,4,v[ 0],v[ 5],v[10],v[15]); \
    G(r,5,v[ 1],v[ 6],v[11],v[12]); \
    G(r,6,v[ 2],v[ 7],v[ 8],v[13]); \
    G(r,7,v[ 3],v[ 4],v[ 9],v[14]); \
  } while(0)

static void blake2b_compress(struct blake2b_ctx *ctx, const uint8_t block[BLAKE2B_BLOCKBYTES])
{
  uint64_t m[16];
  uint64_t v[16];
  size_t i;

  for( i = 0; i < 16; ++i ) {
    m[i] = load64( block + i * sizeof( m[i] ) );
  }

  for( i = 0; i < 8; ++i ) {
    v[i] = ctx->h[i];
  }

  v[ 8] = IV[0];
  v[ 9] = IV[1];
  v[10] = IV[2];
  v[11] = IV[3];
  v[12] = IV[4] ^ ctx->t[0];
  v[13] = IV[5] ^ ctx->t[1];
  v[14] = IV[6] ^ ctx->f[0];
  v[15] = IV[7] ^ ctx->f[1];

  R( 0 );
  R( 1 );
  R( 2 );
  R( 3 );
  R( 4 );
  R( 5 );
  R( 6 );
  R( 7 );
  R( 8 );
  R( 9 );
  R( 10 );
  R( 11 );

  for( i = 0; i < 8; ++i )
    ctx->h[i] = ctx->h[i] ^ v[i] ^ v[i + 8];
}

#undef G
#undef R

void digestif_blake2b_update( struct blake2b_ctx *ctx, uint8_t *data, uint32_t inlen )
{
  const unsigned char * in = (const unsigned char *) data;

  if( inlen > 0 )
  {
    size_t left = ctx->buflen;
    size_t fill = BLAKE2B_BLOCKBYTES - left;

    if( inlen > fill )
    {
      ctx->buflen = 0;
      memcpy( ctx->buf + left, in, fill );
      blake2b_increment_counter( ctx, BLAKE2B_BLOCKBYTES );
      blake2b_compress( ctx, ctx->buf );
      in += fill;
      inlen -= fill;

      while (inlen > BLAKE2B_BLOCKBYTES)
      {
        blake2b_increment_counter( ctx, BLAKE2B_BLOCKBYTES );
        blake2b_compress( ctx, in );
        in += BLAKE2B_BLOCKBYTES;
        inlen -= BLAKE2B_BLOCKBYTES;
      }
    }

    memcpy( ctx->buf + ctx->buflen, in, inlen );
    ctx->buflen += inlen;
  }
}

void digestif_blake2b_init_with_outlen_and_key(struct blake2b_ctx *ctx, size_t outlen, const void *key, size_t keylen)
{
  struct blake2b_param P[1];
  const unsigned char * p = ( const uint8_t * )( P );
  size_t i;

  memset( ctx, 0, sizeof( struct blake2b_ctx ) );

  P->digest_length = (uint8_t) outlen;
  P->key_length    = (uint8_t) keylen;
  P->fanout        = 1;
  P->depth         = 1;
  P->leaf_length   = 0;
  P->node_offset   = 0;
  P->xof_length    = 0;
  P->node_depth    = 0;
  P->inner_length  = 0;

  memset( P->reserved, 0, sizeof( P->reserved ) );
  memset( P->salt, 0, sizeof( P->salt ) );
  memset( P->personal, 0, sizeof( P->personal ) );

  for( i = 0; i < 8; ++i )
    ctx->h[i] = IV[i] ^ load64(p + sizeof(uint64_t) * i);

  ctx->outlen = P->digest_length;

  if( keylen > 0 )
    {
      uint8_t block[BLAKE2B_BLOCKBYTES];
      memset( block, 0, BLAKE2B_BLOCKBYTES );
      memcpy( block, key, keylen );
      digestif_blake2b_update( ctx, block, BLAKE2B_BLOCKBYTES );
      secure_zero_memory( block, BLAKE2B_BLOCKBYTES );
    }
}

void digestif_blake2b_init(struct blake2b_ctx *ctx)
{
  digestif_blake2b_init_with_outlen_and_key(ctx, BLAKE2B_OUTBYTES, NULL, 0);
}

void digestif_blake2b_finalize( struct blake2b_ctx *ctx, uint8_t *out )
{
  uint8_t buffer[BLAKE2B_OUTBYTES] = { 0 };
  size_t  i;

  blake2b_increment_counter( ctx, ctx->buflen );
  blake2b_set_lastblock( ctx );
  memset( ctx->buf + ctx->buflen, 0, BLAKE2B_BLOCKBYTES - ctx->buflen );
  blake2b_compress( ctx, ctx->buf );

  for( i = 0; i < 8; ++i )
    store64(buffer + sizeof( ctx->h[i] ) * i, ctx->h[i]);

  memcpy( out, buffer, ctx->outlen );
  secure_zero_memory( buffer, sizeof(buffer) );
}
