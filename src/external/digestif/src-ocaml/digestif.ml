type bigstring = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

type 'a iter = ('a -> unit) -> unit
type 'a compare = 'a -> 'a -> int
type 'a equal = 'a -> 'a -> bool
type 'a pp = Format.formatter -> 'a -> unit

module By = Digestif_by
module Bi = Digestif_bi
module Eq = Digestif_eq
module Hash = Digestif_hash
module Conv = Digestif_conv

module type S = sig

  val digest_size : int

  type ctx
  type kind
  type t = private string

  val empty: ctx
  val init: unit -> ctx
  val feed_bytes: ctx -> ?off:int -> ?len:int -> Bytes.t -> ctx
  val feed_string: ctx -> ?off:int -> ?len:int -> String.t -> ctx
  val feed_bigstring: ctx -> ?off:int -> ?len:int -> bigstring -> ctx
  val feedi_bytes: ctx -> Bytes.t iter -> ctx
  val feedi_string: ctx -> String.t iter -> ctx
  val feedi_bigstring: ctx -> bigstring iter -> ctx
  val get: ctx -> t
  val digest_bytes: ?off:int -> ?len:int -> Bytes.t -> t
  val digest_string: ?off:int -> ?len:int -> String.t -> t
  val digest_bigstring: ?off:int -> ?len:int -> bigstring -> t
  val digesti_bytes: Bytes.t iter -> t
  val digesti_string: String.t iter -> t
  val digesti_bigstring: bigstring iter -> t
  val digestv_bytes: Bytes.t list -> t
  val digestv_string: String.t list -> t
  val digestv_bigstring: bigstring list -> t
  val hmac_bytes: key:Bytes.t -> ?off:int -> ?len:int -> Bytes.t -> t
  val hmac_string: key:String.t -> ?off:int -> ?len:int -> String.t -> t
  val hmac_bigstring: key:bigstring -> ?off:int -> ?len:int -> bigstring -> t
  val hmaci_bytes: key:Bytes.t -> Bytes.t iter -> t
  val hmaci_string: key:String.t -> String.t iter -> t
  val hmaci_bigstring: key:bigstring -> bigstring iter -> t
  val hmacv_bytes: key:Bytes.t -> Bytes.t list -> t
  val hmacv_string: key:String.t -> String.t list -> t
  val hmacv_bigstring: key:bigstring -> bigstring list -> t
  val unsafe_compare: t compare
  val compare: t compare
  val eq: t equal
  val neq: t equal
  val pp: t pp
  val of_hex: string -> t
  val consistent_of_hex: string -> t
  val to_hex: t -> string
end

module type S' = sig
  include S
  val get_h : ctx -> int32 array
end

module type Desc =
sig
  val digest_size : int
  val block_size  : int
end

module type Hash =
sig
  type ctx
  type kind

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Unsafe (Hash : Hash) (D : Desc) =
struct
  open Hash

  let digest_size = D.digest_size
  let block_size = D.block_size

  let empty = init ()
  let init = init

  let unsafe_feed_bytes ctx ?off ?len buf =
    let off, len = match off, len with
      | Some off, Some len -> off, len
      | Some off, None -> off, By.length buf - off
      | None, Some len -> 0, len
      | None, None -> 0, By.length buf in
    unsafe_feed_bytes ctx buf off len

  let unsafe_feed_string ctx ?off ?len buf =
    unsafe_feed_bytes ctx ?off ?len (By.unsafe_of_string buf)

  let unsafe_feed_bigstring ctx ?off ?len buf =
    let off, len = match off, len with
      | Some off, Some len -> off, len
      | Some off, None -> off, Bi.length buf - off
      | None, Some len -> 0, len
      | None, None -> 0, Bi.length buf in
    unsafe_feed_bigstring ctx buf off len

  let unsafe_get = unsafe_get
end

module Core (Hash : Hash) (D : Desc) =
struct
  type t = string
  type ctx = Hash.ctx
  type kind = Hash.kind

  include Unsafe (Hash) (D)
  include Conv.Make (D)
  include Eq.Make (D)

  let eq = String.equal
  let neq a b = not (eq a b)
  let unsafe_compare = String.compare

  let get t =
    let t = Hash.dup t in
    unsafe_get t |> By.unsafe_to_string

  let feed_bytes t ?off ?len buf =
    let t = Hash.dup t in
    ( unsafe_feed_bytes t ?off ?len buf; t )

  let feed_string t ?off ?len buf =
    let t = Hash.dup t in
    ( unsafe_feed_string t ?off ?len buf; t )

  let feed_bigstring t ?off ?len buf =
    let t = Hash.dup t in
    ( unsafe_feed_bigstring t ?off ?len buf; t )

  let feedi_bytes t iter =
    let t = Hash.dup t in
    let feed buf = unsafe_feed_bytes t buf in
    ( iter feed; t )

  let feedi_string t iter =
    let t = Hash.dup t in
    let feed buf = unsafe_feed_string t buf in
    ( iter feed; t )

  let feedi_bigstring t iter =
    let t = Hash.dup t in
    let feed buf = unsafe_feed_bigstring t buf in
    ( iter feed; t )

  let digest_bytes ?off ?len buf = feed_bytes empty ?off ?len buf |> get
  let digest_string ?off ?len buf = feed_string empty ?off ?len buf |> get
  let digest_bigstring ?off ?len buf = feed_bigstring empty ?off ?len buf |> get

  let digesti_bytes iter = feedi_bytes empty iter |> get
  let digesti_string iter = feedi_string empty iter |> get
  let digesti_bigstring iter = feedi_bigstring empty iter |> get

  let digestv_bytes lst = digesti_bytes (fun f -> List.iter f lst)
  let digestv_string lst = digesti_string (fun f -> List.iter f lst)
  let digestv_bigstring lst = digesti_bigstring (fun f -> List.iter f lst)
end

module Make (H : Hash) (D : Desc) = struct
  include Core (H) (D)

  let bytes_opad = By.init block_size (fun _ -> '\x5c')
  let bytes_ipad = By.init block_size (fun _ -> '\x36')

  let rec norm_bytes key =
    match Pervasives.compare (By.length key) block_size with
    | 1  -> norm_bytes (By.unsafe_of_string (digest_bytes key))
    | -1 -> By.rpad key block_size '\000'
    | _  -> key

  let bigstring_opad = Bi.init block_size (fun _ -> '\x5c')
  let bigstring_ipad = Bi.init block_size (fun _ -> '\x36')

  let norm_bigstring key =
    let key = Bi.to_string key in
    let res0 = norm_bytes (By.unsafe_of_string key) in
    let res1 = Bi.create (By.length res0) in
    Bi.blit_from_bytes res0 0 res1 0 (By.length res0); res1

  let hmaci_bytes ~key iter =
    let key = norm_bytes key in
    let outer = Xor.Bytes.xor key bytes_opad in
    let inner = Xor.Bytes.xor key bytes_ipad in
    let res = digesti_bytes (fun f -> f inner; iter f) in
    digesti_bytes (fun f -> f outer; f (By.unsafe_of_string res))

  let hmaci_string ~key iter =
    let key = norm_bytes (By.unsafe_of_string key) in
    (* XXX(dinosaure): safe, [rpad] and [digest] have a read-only access. *)
    let outer = Xor.Bytes.xor key bytes_opad in
    let inner = Xor.Bytes.xor key bytes_ipad in
    let ctx = feed_bytes empty inner in
    let res = feedi_string ctx iter |> get in
    let ctx = feed_bytes empty outer in
    feed_string ctx (res :> string) |> get

  let hmaci_bigstring ~key iter =
    let key = norm_bigstring key in
    let outer = Xor.Bigstring.xor key bigstring_opad in
    let inner = Xor.Bigstring.xor key bigstring_ipad in
    let res = digesti_bigstring (fun f -> f inner; iter f) in
    let ctx = feed_bigstring empty outer in
    feed_string ctx (res :> string) |> get

  let hmac_bytes ~key ?off ?len buf =
    let buf = match off, len with
      | Some off, Some len -> By.sub buf off len
      | Some off, None -> By.sub buf off (By.length buf - off)
      | None, Some len -> By.sub buf 0 len
      | None, None -> buf in
    hmaci_bytes ~key (fun f -> f buf)

  let hmac_string ~key ?off ?len buf =
    let buf = match off, len with
      | Some off, Some len -> String.sub buf off len
      | Some off, None -> String.sub buf off (String.length buf - off)
      | None, Some len -> String.sub buf 0 len
      | None, None -> buf in
    hmaci_string ~key (fun f -> f buf)

  let hmac_bigstring ~key ?off ?len buf =
    let buf = match off, len with
      | Some off, Some len -> Bi.sub buf off len
      | Some off, None -> Bi.sub buf off (Bi.length buf - off)
      | None, Some len -> Bi.sub buf 0 len
      | None, None -> buf in
    hmaci_bigstring ~key (fun f -> f buf)

  let hmacv_bytes ~key bufs = hmaci_bytes ~key (fun f -> List.iter f bufs)
  let hmacv_string ~key bufs = hmaci_string ~key (fun f -> List.iter f bufs)
  let hmacv_bigstring ~key bufs = hmaci_bigstring ~key (fun f -> List.iter f bufs)
end

module type Hash_BLAKE2 =
sig
  type ctx
  type kind

  val init: unit -> ctx
  val with_outlen_and_bytes_key: int -> By.t -> int -> int -> ctx
  val with_outlen_and_bigstring_key: int -> Bi.t -> int -> int -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Core_BLAKE2 (H : Hash_BLAKE2) (D : Desc) = Core (H) (D)

module Make_BLAKE2 (H : Hash_BLAKE2) (D : Desc) =
struct
  include Core_BLAKE2 (H) (D)

  let hmaci_bytes ~key iter =
    let ctx = H.with_outlen_and_bytes_key digest_size key 0 (By.length key) in
    feedi_bytes ctx iter |> get

  let hmaci_string ~key iter =
    let ctx = H.with_outlen_and_bytes_key digest_size (By.unsafe_of_string key) 0 (String.length key) in
    feedi_string ctx iter |> get

  let hmaci_bigstring ~key iter =
    let ctx = H.with_outlen_and_bigstring_key digest_size key 0 (Bi.length key) in
    feedi_bigstring ctx iter |> get

  let hmac_bytes ~key ?off ?len buf : t =
    let buf = match off, len with
      | Some off, Some len -> By.sub buf off len
      | Some off, None -> By.sub buf off (By.length buf - off)
      | None, Some len -> By.sub buf 0 len
      | None, None -> buf in
    hmaci_bytes ~key (fun f -> f buf)

  let hmac_string ~key ?off ?len buf =
    let buf = match off, len with
      | Some off, Some len -> String.sub buf off len
      | Some off, None -> String.sub buf off (String.length buf - off)
      | None, Some len -> String.sub buf 0 len
      | None, None -> buf in
    hmaci_string ~key (fun f -> f buf)

  let hmac_bigstring ~key ?off ?len buf =
    let buf = match off, len with
      | Some off, Some len -> Bi.sub buf off len
      | Some off, None -> Bi.sub buf off (Bi.length buf - off)
      | None, Some len -> Bi.sub buf 0 len
      | None, None -> buf in
    hmaci_bigstring ~key (fun f -> f buf)

  let hmacv_bytes ~key bufs = hmaci_bytes ~key (fun f -> List.iter f bufs)
  let hmacv_string ~key bufs = hmaci_string ~key (fun f -> List.iter f bufs)
  let hmacv_bigstring ~key bufs = hmaci_bigstring ~key (fun f -> List.iter f bufs)
end

module MD5 : S with type kind = [ `MD5 ] = Make (Baijiu_md5.Unsafe) (struct let (digest_size, block_size) = (16, 64) end)
module SHA1 : S with type kind = [ `SHA1 ] = Make (Baijiu_sha1.Unsafe) (struct let (digest_size, block_size) = (20, 64) end)
module SHA224 : S with type kind = [ `SHA224 ] = Make (Baijiu_sha224.Unsafe) (struct let (digest_size, block_size) = (28, 64) end)
module SHA256 : S' with type kind = [ `SHA256 ] and type ctx = Baijiu_sha256.Unsafe.ctx = struct
  include Make (Baijiu_sha256.Unsafe) (struct let (digest_size, block_size) = (32, 64) end)
  let get_h = Baijiu_sha256.Unsafe.unsafe_get_h
end
module SHA384 : S with type kind = [ `SHA384 ] = Make (Baijiu_sha384.Unsafe) (struct let (digest_size, block_size) = (48, 128) end)
module SHA512 : S with type kind = [ `SHA512 ] = Make (Baijiu_sha512.Unsafe) (struct let (digest_size, block_size) = (64, 128) end)
module BLAKE2B : S with type kind = [ `BLAKE2B ] = Make_BLAKE2 (Baijiu_blake2b.Unsafe) (struct let (digest_size, block_size) = (64, 128) end)
module BLAKE2S : S with type kind = [ `BLAKE2S ] = Make_BLAKE2 (Baijiu_blake2s.Unsafe) (struct let (digest_size, block_size) = (32, 64) end)
module RMD160 : S with type kind = [ `RMD160 ] = Make (Baijiu_rmd160.Unsafe) (struct let (digest_size, block_size) = (20, 64) end)

type sha256_ctx = Baijiu_sha256.Unsafe.ctx =
  { mutable size : int64
  ; b : Bytes.t
  ; h : int32 array }

module Make_BLAKE2B (D : sig val digest_size : int end) : S with type kind = [ `BLAKE2B ]=
struct
  include Make_BLAKE2(Baijiu_blake2b.Unsafe)(struct let (digest_size, block_size) = (D.digest_size, 128) end)
end

module Make_BLAKE2S (D : sig val digest_size : int end) : S with type kind = [ `BLAKE2S ] =
struct
  include Make_BLAKE2(Baijiu_blake2s.Unsafe)(struct let (digest_size, block_size) = (D.digest_size, 64) end)
end

include Hash

type blake2b = (module S with type kind = [ `BLAKE2B ])
type blake2s = (module S with type kind = [ `BLAKE2S ])

let module_of : type k. k hash -> (module S with type kind = k) = fun hash ->
  let b2b : (int, blake2b) Hashtbl.t = Hashtbl.create 13 in
  let b2s : (int, blake2s) Hashtbl.t = Hashtbl.create 13 in
  match hash with
  | MD5     -> (module MD5)
  | SHA1    -> (module SHA1)
  | RMD160  -> (module RMD160)
  | SHA224  -> (module SHA224)
  | SHA256  -> (module SHA256)
  | SHA384  -> (module SHA384)
  | SHA512  -> (module SHA512)
  | BLAKE2B digest_size -> begin
      match Hashtbl.find b2b digest_size with
      | exception Not_found ->
        let m : (module S with type kind = [ `BLAKE2B ]) =
          (module Make_BLAKE2B(struct let digest_size = digest_size end)
             : S with type kind = [ `BLAKE2B ]) in
        Hashtbl.replace b2b digest_size m ; m
      | m -> m
    end
  | BLAKE2S digest_size -> begin
      match Hashtbl.find b2s digest_size with
      | exception Not_found ->
        let m =
          (module Make_BLAKE2S(struct let digest_size = digest_size end)
             : S with type kind = [ `BLAKE2S ]) in
        Hashtbl.replace b2s digest_size m ; m
      | m -> m
    end

type 'kind t = string

let digesti_bytes
  : type k. k hash -> Bytes.t iter -> k t
  = fun hash iter ->
    let module H = (val (module_of hash)) in
    ((H.digesti_bytes iter :> string) : H.kind t)

let digesti_string
  : type k. k hash -> String.t iter -> k t
  = fun hash iter ->
    let module H = (val (module_of hash)) in
    ((H.digesti_string iter :> string) : H.kind t)

let digesti_bigstring
  : type k. k hash -> bigstring iter -> k t
  = fun hash iter ->
    let module H = (val (module_of hash)) in
    ((H.digesti_bigstring iter :> string) : H.kind t)

let hmaci_bytes
  : type k. k hash -> key:Bytes.t -> Bytes.t iter -> k t
  = fun hash ~key iter ->
    let module H = (val (module_of hash)) in
    ((H.hmaci_bytes ~key iter :> string) : H.kind t)

let hmaci_string
  : type k. k hash -> key:String.t -> String.t iter -> k t
  = fun hash ~key iter ->
    let module H = (val (module_of hash)) in
    ((H.hmaci_string ~key iter :> string) : H.kind t)

let hmaci_bigstring
  : type k. k hash -> key:bigstring -> bigstring iter -> k t
  = fun hash ~key iter ->
    let module H = (val (module_of hash)) in
    ((H.hmaci_bigstring ~key iter :> string) : H.kind t)

(* XXX(dinosaure): unsafe part to avoid overhead. *)

let unsafe_compare
  : type k. k hash -> k t -> k t -> int
  = fun hash a b ->
    let module H = (val (module_of hash)) in
    let unsafe : 'k t -> H. t = Obj.magic in
    H.unsafe_compare (unsafe a) (unsafe b)

let eq
  : type k. k hash -> k t equal
  = fun hash a b ->
    let module H = (val (module_of hash)) in
    let unsafe : 'k t -> H. t = Obj.magic in
    H.eq (unsafe a) (unsafe b)

let neq
  : type k. k hash -> k t equal
  = fun hash a b ->
    let module H = (val (module_of hash)) in
    let unsafe : 'k t -> H. t = Obj.magic in
    H.neq (unsafe a) (unsafe b)

let pp
  : type k. k hash -> k t pp
  = fun hash ppf t  ->
    let module H = (val (module_of hash)) in
    let unsafe : 'k t -> H. t = Obj.magic in
    H.pp ppf (unsafe t)

let of_hex
  : type k. k hash -> string -> k t
  = fun hash hex ->
    let module H = (val (module_of hash)) in
    (H.of_hex hex :> string)

let to_hex
  : type k. k hash -> k t -> string
  = fun hash t ->
    let module H = (val (module_of hash)) in
    let unsafe : 'k t -> H.t = Obj.magic in
    (H.to_hex (unsafe t))
