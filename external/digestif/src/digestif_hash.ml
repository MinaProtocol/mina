type 'kind hash =
  | MD5 : [ `MD5 ] hash
  | SHA1 : [ `SHA1 ] hash
  | RMD160 : [ `RMD160 ] hash
  | SHA224 : [ `SHA224 ] hash
  | SHA256 : [ `SHA256 ] hash
  | SHA384 : [ `SHA384 ] hash
  | SHA512 : [ `SHA512 ] hash
  | BLAKE2B : int -> [ `BLAKE2B ] hash
  | BLAKE2S : int-> [ `BLAKE2S ] hash
and kind =
  [ `MD5
  | `SHA1
  | `RMD160
  | `SHA224
  | `SHA256
  | `SHA384
  | `SHA512
  | `BLAKE2B
  | `BLAKE2S ]

let md5 = MD5
let sha1 = SHA1
let rmd160 = RMD160
let sha224 = SHA224
let sha256 = SHA256
let sha384 = SHA384
let sha512 = SHA512
let blake2b length = BLAKE2B length
let blake2s length = BLAKE2S length
