open Core

module Sender : sig
  module Stable : sig
    module V1 : sig
      type t = Local | Remote of Unix.Inet_addr.Stable.V1.t
      [@@deriving sexp, bin_io, eq, yojson, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = Local | Remote of Unix.Inet_addr.Stable.V1.t
  [@@deriving sexp, eq, yojson]
end

module Incoming : sig
  module Stable : sig
    module V1 : sig
      type 'a t = {data: 'a; sender: Sender.Stable.V1.t [@compare.ignore]}
      [@@deriving eq, sexp, bin_io, yojson, version, compare]
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.Latest.t [@@deriving eq, sexp, yojson, compare]

  val sender : 'a t -> Sender.t

  val data : 'a t -> 'a

  val wrap : data:'a -> sender:Sender.t -> 'a t

  val map : f:('a -> 'b) -> 'a t -> 'b t

  val local : 'a -> 'a t

  val max : f:('a -> 'a -> int) -> 'a t -> 'a t -> 'a t
end
