(** Where a block stands in the archive's view of the chain. Carried by
    {!Extensional.Block}, and stored as text in the [blocks.chain_status]
    column. *)

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      | Canonical  (** On the canonical chain, and deep enough to be final. *)
      | Orphaned  (** Not on the canonical chain, at a height already final. *)
      | Pending  (** Within the last [k] blocks: not decided yet. *)
    [@@deriving yojson, equal]
  end
end]

type t = Stable.Latest.t = Canonical | Orphaned | Pending
[@@deriving yojson, equal]

(** ["canonical"], ["orphaned"] or ["pending"], as stored in the database. *)
val to_string : t -> string

(** The inverse of {!to_string}. @raise on any other string. *)
val of_string : string -> t
