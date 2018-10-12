/*
 * Copyright (c) 2014-2016 David Kaloper Meršinjak
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#if !defined(H__DIGESTIF)
#define H__DIGESTIF

#include <stdint.h>
#include <caml/mlvalues.h>
#include <caml/bigarray.h>

#include "bitfn.h"

#if defined (__x86_64__) && defined (ACCELERATE)
#include <x86intrin.h>
#endif

#if defined (__x86_64__) && defined (ACCELERATE) && defined (__SSE2__)
#define __digestif_SSE2
#endif

#ifndef __unused
#define __unused(x) x __attribute__((unused))
#endif
#define __unit() value __unused(unit)

typedef unsigned long u_long;

#define _ba_uint8_off(ba, off) ((uint8_t*) Caml_ba_data_val (ba) + Long_val (off))
#define _ba_uint32_off(ba, off) ((uint32_t*) Caml_ba_data_val (ba) + Long_val (off))
#define _ba_ulong_off(ba, off) ((u_long*) Caml_ba_data_val (ba) + Long_val (off))

#define _st_uint8_off(st, off) ((uint8_t*) String_val (st) + Long_val (off))
#define _st_uint32_off(st, off) ((uint32_t*) String_val (st) + Long_val (off))
#define _st_ulong_off(st, off) ((u_long*) String_val (st) + Long_val (off))

#define _ba_uint8(ba) _ba_uint8_off (ba, 0)
#define _ba_uint32(ba) _ba_uint32_off (ba, 0)
#define _ba_ulong(ba) _ba_ulong_off (ba, 0)

#define _st_uint8(st) _st_uint8_off(st, 0)
#define _st_uint32(st) _st_uint32_off(st, 0)
#define _st_ulong(st) _st_ulong_off (st, 0)

#define _ba_uint8_option_off(ba, off) (Is_block(ba) ? _ba_uint8_off(Field(ba, 0), off) : 0)
#define _ba_uint8_option(ba)          _ba_uint8_option_off (ba, 0)

#define _st_uint8_option_off(st, off) (Is_block(st) ? _st_uint8_off(Field(st, 0), off) : 0)
#define _st_uint8_option(st)          _ba_uint8_option_off (st, 0)

#define __define_bc_6(f) \
  CAMLprim value f ## _bc (value *v, int __unused(c) ) { return f(v[0], v[1], v[2], v[3], v[4], v[5]); }

#define __define_bc_7(f) \
  CAMLprim value f ## _bc (value *v, int __unused(c) ) { return f(v[0], v[1], v[2], v[3], v[4], v[5], v[6]); }

#endif /* H__DIGESTIF */
