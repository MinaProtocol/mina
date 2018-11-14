open Core_kernel

module T = struct
  type t = Timeout of Time.t | Forever [@@deriving bin_io]
end

include T

module Record = struct
  module type S = sig
    type t

    type time

    type score

    val eviction_time : t -> time

    val create_timeout : score -> t
  end

  (* Added binable to make it easy to serialize Record into Rocksdb *)
  module Make (Timeout : sig
    val duration : Time.Span.t
  end) :
    sig
      include S

      include Binable.S with type t := t
    end
    with type time := Time.t
     and type score := Score.t = struct
    type t = {score: Score.t; punishment: T.t} [@@deriving bin_io]

    let eviction_time {punishment; _} =
      match punishment with Timeout time -> time | Forever -> failwith "TODO"

    let create_timeout score =
      let timeout = Timeout (Time.add (Time.now ()) Timeout.duration) in
      {score; punishment= timeout}
  end
end
