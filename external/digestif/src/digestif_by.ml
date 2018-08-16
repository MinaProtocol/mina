include Bytes

external unsafe_get_32 : t -> int -> int32 = "%caml_string_get32u"
external unsafe_get_64 : t -> int -> int64 = "%caml_string_get64u"

let unsafe_get_nat : t -> int -> nativeint = fun s i ->
  if Sys.word_size = 32
  then Nativeint.of_int32 @@ unsafe_get_32 s i
  else Int64.to_nativeint @@ unsafe_get_64 s i

external unsafe_set_32 : t -> int -> int32 -> unit = "%caml_string_set32u"
external unsafe_set_64 : t -> int -> int64 -> unit = "%caml_string_set64u"

let unsafe_set_nat : t -> int -> nativeint -> unit = fun s i v ->
  if Sys.word_size = 32
  then unsafe_set_32 s i (Nativeint.to_int32 v)
  else unsafe_set_64 s i (Int64.of_nativeint v)

let blit_from_bigstring src src_off dst dst_off len =
  for i = 0 to len - 1
  do set dst (dst_off + i) (Bigarray.Array1.get src (src_off + i)) done

let rpad a size x =
  let l = length a in
  let b = create size in
  blit a 0 b 0 l;
  fill b l (size - l) x; b

external swap32 : int32 -> int32 = "%bswap_int32"
external swap64 : int64 -> int64 = "%bswap_int64"
external swapnat : nativeint -> nativeint = "%bswap_native"

let cpu_to_be32 s i v =
  if Sys.big_endian
  then unsafe_set_32 s i v
  else unsafe_set_32 s i (swap32 v)

let cpu_to_le32 s i v =
  if Sys.big_endian
  then unsafe_set_32 s i (swap32 v)
  else unsafe_set_32 s i v

let cpu_to_be64 s i v =
  if Sys.big_endian
  then unsafe_set_64 s i v
  else unsafe_set_64 s i (swap64 v)

let cpu_to_le64 s i v =
  if Sys.big_endian
  then unsafe_set_64 s i (swap64 v)
  else unsafe_set_64 s i v

let be32_to_cpu s i =
  if Sys.big_endian
  then unsafe_get_32 s i
  else swap32 @@ unsafe_get_32 s i

let le32_to_cpu s i =
  if Sys.big_endian
  then swap32 @@ unsafe_get_32 s i
  else unsafe_get_32 s i

let be64_to_cpu s i =
  if Sys.big_endian
  then unsafe_get_64 s i
  else swap64 @@ unsafe_get_64 s i

let le64_to_cpu s i =
  if Sys.big_endian
  then swap64 @@ unsafe_get_64 s i
  else unsafe_get_64 s i

let benat_to_cpu s i =
  if Sys.big_endian
  then unsafe_get_nat s i
  else swapnat @@ unsafe_get_nat s i

let cpu_to_benat s i v =
  if Sys.big_endian
  then unsafe_set_nat s i v
  else unsafe_set_nat s i (swapnat v)
