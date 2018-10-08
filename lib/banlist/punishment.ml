open Core_kernel
open Unsigned

module T = struct
  type t = Timeout of Time.t | Forever
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

  module Make (Timeout : sig
    val duration : Time.Span.t
  end) :
    S with type time := Time.t and type score := UInt32.t =
  struct
    type t = {score: UInt32.t; punishment: T.t}

    let eviction_time {punishment; _} =
      match punishment with Timeout time -> time | Forever -> failwith "TODO"

    let create_timeout score =
      let timeout = Timeout (Time.add (Time.now ()) Timeout.duration) in
      {score; punishment= timeout}
  end
end
