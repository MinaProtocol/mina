/*
 * Copyright (C) 2017 Romain Calascibetta
 * <romain.calascibetta@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef CRYPTOHASH_RMD160_H
#define CRYPTOHASH_RMD160_H

#include <stdint.h>

struct rmd160_ctx
{
  uint32_t h[5];
  uint32_t sz[2];
  int      n;
  uint8_t  buf[64];
};

#define RMD160_DIGEST_SIZE 20
#define RMD160_CTX_SIZE (sizeof(struct rmd160_ctx))

void digestif_rmd160_init(struct rmd160_ctx *ctx);
void digestif_rmd160_update(struct rmd160_ctx *ctx, uint8_t *data, uint32_t len);
void digestif_rmd160_finalize(struct rmd160_ctx *ctx, uint8_t *out);

#endif
