open Core_kernel

module Header = struct
  type ('hash, 'time, 'span) t_ =
    { previous_header_hash : Pedersen.Digest.t
    ; body_hash            : Pedersen.Digest.t
    ; time                 : Block_time.t
    ; deltas               : Block_time.Span.t list
    }
  [@@deriving bin_io]

  type t = (Pedersen.Digest.t, Block_time.t, Block_time.Span.t) t_
  [@@deriving bin_io]

  let hash t =
    let buf = Bigstring.create (bin_size_t t) in
    let s = Pedersen.State.create () in
    Pedersen.State.update s buf;
    Pedersen.State.digest s
end

module Body = struct
  type t = Int64.t
  [@@deriving bin_io]
end

type ('header, 'body) t_ =
  { header : 'header
  ; body   : 'body
  }
[@@deriving bin_io]

type t = (Header.t, Body.t) t_ [@@deriving bin_io]

let strongest (a : t) (b : t) : [ `First | `Second ] = failwith "TODO"
