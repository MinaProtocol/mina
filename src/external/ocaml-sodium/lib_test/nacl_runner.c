/*
 * Copyright (c) 2013 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
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
 *
 */

// WARNING: THIS FUNCTIONAL TEST HARNESS IS NOT GENERALLY SAFE OR SECURE
// *** DO NOT USE EXCEPT IN SPECIAL TRUSTED ENVIRONMENTS ***

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sodium/crypto_box.h>

typedef unsigned char uchar;

void bin2hex(char *hex,const uchar *bin,unsigned int blen) {
  char *halpha = "0123456789abcdef";
  int i;
  for (i=0; i<blen; i++) {
    hex[i*2]     = halpha[ bin[i] >> 4 ];
    hex[i*2 + 1] = halpha[ bin[i] & 15 ];
  }
}

uchar hexc2uchar(uchar hexc) {
  switch (hexc) {
  case '0': case '1': case '2': case '3': case '4':
  case '5': case '6': case '7': case '8': case '9':
    return hexc - 0x30;
  case 'A': case 'B': case 'C':
  case 'D': case 'E': case 'F':
    return hexc - 0x41 + 10;
  case 'a': case 'b': case 'c':
  case 'd': case 'e': case 'f':
    return hexc - 0x61 + 10;
  default:
    fprintf(stderr,"'%c' not valid hex character\nexit(2)\n",hexc); exit(2);
  }
}

void hex2bin(uchar *bin,const char *hex,unsigned int hlen) {
  int i;
  for (i=0; i<hlen; i+=2) {
    bin[ i >> 1 ] = (hexc2uchar(hex[i]) << 4) | hexc2uchar(hex[i + 1]);
  }
}

void box(int argc, char *argv[]) {
  int r;
  uchar n[crypto_box_NONCEBYTES],
        pk[crypto_box_PUBLICKEYBYTES],
        sk[crypto_box_SECRETKEYBYTES];
  size_t mlen = strlen(argv[0]) / 2 + crypto_box_ZEROBYTES;
  size_t clen = mlen - crypto_box_BOXZEROBYTES;
  uchar *m, *c;
  char *h;
  m = calloc(mlen, sizeof(uchar));
  c = calloc(mlen, sizeof(uchar));
  h = calloc(clen * 2 + 1, sizeof(char));

  hex2bin(m + crypto_box_ZEROBYTES,argv[0],strlen(argv[0]));
  hex2bin(n,argv[1],strlen(argv[1]));
  hex2bin(pk,argv[2],strlen(argv[2]));
  hex2bin(sk,argv[3],strlen(argv[3]));

  r = crypto_box(c,m,mlen,n,pk,sk);

  bin2hex(h,c + crypto_box_BOXZEROBYTES,clen);
  h[ clen * 2 ] = 0;

  if (r == 0) printf("%s",h);
  else fprintf(stderr,"error in crypto_box\n");

  free(m);
  free(c);
  free(h);
}

void box_open(int argc, char *argv[]) {
  int r;
  uchar n[crypto_box_NONCEBYTES],
        pk[crypto_box_PUBLICKEYBYTES],
        sk[crypto_box_SECRETKEYBYTES];
  size_t clen = strlen(argv[0]) / 2 + crypto_box_BOXZEROBYTES;
  size_t mlen = clen - crypto_box_ZEROBYTES;
  uchar *m, *c;
  char *h;
  m = calloc(clen, sizeof(uchar));
  c = calloc(clen, sizeof(uchar));
  h = calloc(mlen * 2 + 1, sizeof(char));

  hex2bin(c + crypto_box_BOXZEROBYTES,argv[0],strlen(argv[0]));
  hex2bin(n,argv[1],strlen(argv[1]));
  hex2bin(pk,argv[2],strlen(argv[2]));
  hex2bin(sk,argv[3],strlen(argv[3]));

  r = crypto_box_open(m,c,clen,n,pk,sk);

  bin2hex(h,m + crypto_box_ZEROBYTES,mlen);
  h[ mlen * 2 ] = 0;

  if (r == 0) printf("%s",h);
  else fprintf(stderr,"error in crypto_box_open\n");

  free(m);
  free(c);
  free(h);
}

void box_beforenm(int argc, char *argv[]) {
  int r;
  uchar k[crypto_box_BEFORENMBYTES],
        pk[crypto_box_PUBLICKEYBYTES],
        sk[crypto_box_SECRETKEYBYTES];
  char h[crypto_box_BEFORENMBYTES * 2 + 1];

  hex2bin(pk,argv[0],strlen(argv[0]));
  hex2bin(sk,argv[1],strlen(argv[1]));

  r = crypto_box_beforenm(k,pk,sk);

  bin2hex(h,k,crypto_box_BEFORENMBYTES);
  h[ crypto_box_BEFORENMBYTES * 2 ] = 0;

  if (r == 0) printf("%s",h);
  else fprintf(stderr,"error in crypto_box_beforenm\n");
}

void box_afternm(int argc, char *argv[]) {
  int r;
  uchar n[crypto_box_NONCEBYTES],
        k[crypto_box_BEFORENMBYTES];
  size_t mlen = strlen(argv[0]) / 2 + crypto_box_ZEROBYTES;
  size_t clen = mlen - crypto_box_BOXZEROBYTES;
  uchar *m, *c;
  char *h;
  m = calloc(mlen, sizeof(uchar));
  c = calloc(mlen, sizeof(uchar));
  h = calloc(clen * 2 + 1, sizeof(char));

  hex2bin(m + crypto_box_ZEROBYTES,argv[0],strlen(argv[0]));
  hex2bin(n,argv[1],strlen(argv[1]));
  hex2bin(k,argv[2],strlen(argv[2]));

  r = crypto_box_afternm(c,m,mlen,n,k);

  bin2hex(h,c + crypto_box_BOXZEROBYTES,clen);
  h[ clen * 2 ] = 0;

  if (r == 0) printf("%s",h);
  else fprintf(stderr,"error in crypto_box_afternm\n");

  free(m);
  free(c);
  free(h);
}

void box_open_afternm(int argc, char *argv[]) {
  int r;
  uchar n[crypto_box_NONCEBYTES],
        k[crypto_box_BEFORENMBYTES];
  size_t clen = strlen(argv[0]) / 2 + crypto_box_BOXZEROBYTES;
  size_t mlen = clen - crypto_box_ZEROBYTES;
  uchar *m, *c;
  char *h;
  m = calloc(clen, sizeof(uchar));
  c = calloc(clen, sizeof(uchar));
  h = calloc(mlen * 2 + 1, sizeof(char));

  hex2bin(c + crypto_box_BOXZEROBYTES,argv[0],strlen(argv[0]));
  hex2bin(n,argv[1],strlen(argv[1]));
  hex2bin(k,argv[2],strlen(argv[2]));

  r = crypto_box_open_afternm(m,c,clen,n,k);

  bin2hex(h,m + crypto_box_ZEROBYTES,mlen);
  h[ mlen * 2 ] = 0;

  if (r == 0) printf("%s",h);
  else fprintf(stderr,"error in crypto_box_open_afternm\n");

  free(m);
  free(c);
  free(h);
}

int main(int argc, char *argv[]) {
  if (argc < 2) { fprintf(stderr,"must provide function\n"); exit(1); }

  if      (strcmp(argv[1],"box")==0)              box             (argc,argv+2);
  else if (strcmp(argv[1],"box_open")==0)         box_open        (argc,argv+2);
  else if (strcmp(argv[1],"box_beforenm")==0)     box_beforenm    (argc,argv+2);
  else if (strcmp(argv[1],"box_afternm")==0)      box_afternm     (argc,argv+2);
  else if (strcmp(argv[1],"box_open_afternm")==0) box_open_afternm(argc,argv+2);
  else { fprintf(stderr,"unknown function '%s'\nexit(1)\n",argv[1]); exit(1); }

  return 0;
}
