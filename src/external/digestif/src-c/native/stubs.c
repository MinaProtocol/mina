#include "digestif.h"

#include "md5.h"
#include "sha1.h"
#include "sha256.h"
#include "sha512.h"
#include "blake2b.h"
#include "blake2s.h"
#include "ripemd160.h"

#define __define_hash(name, upper)                                           \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _ba_init (value ctx) {                           \
    digestif_ ## name ## _init ((struct name ## _ctx *) String_val (ctx));   \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _st_init (value ctx) {                           \
    digestif_ ## name ## _init ((struct name ## _ctx *) String_val (ctx));   \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _ba_update (value ctx, value src, value off, value len) { \
    digestif_ ## name ## _update (                                           \
      (struct name ## _ctx *) String_val (ctx),                              \
      _ba_uint8_off (src, off), Int_val (len));                              \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _st_update (value ctx, value src, value off, value len) { \
    digestif_ ## name ## _update (                                           \
      (struct name ## _ctx *) String_val (ctx),                              \
      _st_uint8_off (src, off), Int_val (len));                              \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _ba_finalize (value ctx, value dst, value off) { \
    digestif_ ## name ## _finalize (                                         \
      (struct name ## _ctx *) String_val (ctx),                              \
      _ba_uint8_off (dst, off));                                             \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _st_finalize (value ctx, value dst, value off) { \
    digestif_ ## name ## _finalize(                                          \
      (struct name ## _ctx *) String_val (ctx),                              \
      _st_uint8_off (dst, off));                                             \
    return Val_unit;                                                         \
  }                                                                          \
                                                                             \
  CAMLprim value                                                             \
  caml_digestif_ ## name ## _ctx_size (__unit ()) {                          \
    return Val_int (upper ## _CTX_SIZE);                                     \
  }

__define_hash (md5, MD5)
__define_hash (sha1, SHA1)
__define_hash (sha224, SHA224)
__define_hash (sha256, SHA256)
__define_hash (sha384, SHA384)
__define_hash (sha512, SHA512)
__define_hash (blake2b, BLAKE2B)
__define_hash (blake2s, BLAKE2S)
__define_hash (rmd160, RMD160)

CAMLprim value
caml_digestif_sha256_ba_get_h(value ctx, value dst, value off) {
    digestif_sha256_get_h((struct sha256_ctx*) String_val(ctx), _ba_uint8_off(dst, off));
    return Val_unit;
}


CAMLprim value
caml_digestif_sha256_st_get_h(value ctx, value dst, value off) {
    digestif_sha256_get_h((struct sha256_ctx*) String_val(ctx), _st_uint8_off(dst, off));
    return Val_unit;
}

CAMLprim value
caml_digestif_blake2b_ba_init_with_outlen_and_key(value ctx, value outlen, value key, value off, value len)
{
  digestif_blake2b_init_with_outlen_and_key(
    (struct blake2b_ctx *) String_val (ctx), Int_val (outlen),
    _ba_uint8_off(key, off), Int_val (len));

  return Val_unit;
}

CAMLprim value
caml_digestif_blake2b_st_init_with_outlen_and_key(value ctx, value outlen, value key, value off, value len)
{
  digestif_blake2b_init_with_outlen_and_key(
    (struct blake2b_ctx *) String_val (ctx), Int_val (outlen),
    _st_uint8_off(key, off), Int_val (len));

  return Val_unit;
}

CAMLprim value
caml_digestif_blake2b_key_size(__unit ()) {
  return Val_int (BLAKE2B_KEYBYTES);
}

CAMLprim value
caml_digestif_blake2b_digest_size(value ctx) {
  return Val_int(((struct blake2b_ctx *) String_val (ctx))->outlen);
}

CAMLprim value
caml_digestif_blake2s_ba_init_with_outlen_and_key(value ctx, value outlen, value key, value off, value len)
{
  digestif_blake2s_init_with_outlen_and_key(
    (struct blake2s_ctx *) String_val (ctx), Int_val (outlen),
    _ba_uint8_off(key, off), Int_val (len));

  return Val_unit;
}

CAMLprim value
caml_digestif_blake2s_st_init_with_outlen_and_key(value ctx, value outlen, value key, value off, value len)
{
  digestif_blake2s_init_with_outlen_and_key(
    (struct blake2s_ctx *) String_val (ctx), Int_val (outlen),
    _st_uint8_off(key, off), Int_val (len));

  return Val_unit;
}

CAMLprim value
caml_digestif_blake2s_key_size(__unit ()) {
  return Val_int (BLAKE2S_KEYBYTES);
}

CAMLprim value
caml_digestif_blake2s_digest_size(value ctx) {
  return Val_int(((struct blake2s_ctx *) String_val (ctx))->outlen);
}
