(** Type definitions and module signatures for library Pickles_types *)

(** {1 Serialization} *)

(** {2 To and from S-expressions} *)
module Sexpable = Core_kernel.Sexpable

(** {2 To and from binary format} *)
module Binable = Core_kernel.Binable

(** {2 Serialization to and from JSON} *)

(** Serialization to and from S-expressions or binary formats are directly
    imported from respectively {!Core_kernel.Sexpable} and {!Core_kernel.Binable} *)

type json = Yojson.Safe.t

type 'a jsonable = 'a -> json

type 'a maybe_json = Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or

module Jsonable : sig
  module type S1 = sig
    type 'a t

    val to_yojson : 'a jsonable -> 'a t jsonable

    val of_yojson : 'a maybe_json -> 'a t maybe_json
  end

  module type S2 = sig
    type ('a, 'b) t

    val to_yojson : 'a jsonable -> 'b jsonable -> ('a, 'b) t jsonable

    val of_yojson : 'a maybe_json -> 'b maybe_json -> ('a, 'b) t maybe_json
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    val to_yojson :
      'a jsonable -> 'b jsonable -> 'c jsonable -> ('a, 'b, 'c) t jsonable

    val of_yojson :
         'a maybe_json
      -> 'b maybe_json
      -> 'c maybe_json
      -> ('a, 'b, 'c) t maybe_json
  end
end

type 'a hashable =
  Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state

module Hash_foldable : sig
  module type S1 = sig
    type 'a t

    val hash_fold_t : 'a hashable -> 'a t hashable
  end

  module type S2 = sig
    type ('a, 'b) t

    val hash_fold_t : 'a hashable -> 'b hashable -> ('a, 'b) t hashable
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    val hash_fold_t :
      'a hashable -> 'b hashable -> 'c hashable -> ('a, 'b, 'c) t hashable
  end
end

(** {1 Modules implementing comparison and equality functions } *)

type ('a, 'res) rel2 = 'a -> 'a -> 'res

type 'a comparable = ('a, int) rel2

type 'a equalable = ('a, bool) rel2

module Comparable : sig
  module type S1 = sig
    type 'a t

    val compare : 'a comparable -> 'a t comparable

    val equal : 'a equalable -> 'a t equalable
  end

  module type S2 = sig
    type ('a, 'b) t

    val compare : 'a comparable -> 'b comparable -> ('a, 'b) t comparable

    val equal : 'a equalable -> 'b equalable -> ('a, 'b) t equalable
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    val compare :
         'a comparable
      -> 'b comparable
      -> 'c comparable
      -> ('a, 'b, 'c) t comparable

    val equal :
      'a equalable -> 'b equalable -> 'c equalable -> ('a, 'b, 'c) t equalable
  end
end

module type VERSIONED = sig
  val version : int

  val __versioned__ : unit
end

module Serializable : sig
  module type S1 = sig
    type 'a t

    include Sexpable.S1 with type 'a t := 'a t

    include Binable.S1 with type 'a t := 'a t

    include Jsonable.S1 with type 'a t := 'a t
  end

  module type S2 = sig
    type ('a, 'b) t

    include Sexpable.S2 with type ('a, 'b) t := ('a, 'b) t

    include Binable.S2 with type ('a, 'b) t := ('a, 'b) t

    include Jsonable.S2 with type ('a, 'b) t := ('a, 'b) t
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    include Sexpable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

    include Binable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

    include Jsonable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
  end
end

(** Module types for types that have the whole gamut of transformations /
    functions *)
module Full : sig
  module type S1 = sig
    type 'a t

    include VERSIONED

    include Serializable.S1 with type 'a t := 'a t

    include Comparable.S1 with type 'a t := 'a t

    include Hash_foldable.S1 with type 'a t := 'a t
  end

  module type S2 = sig
    type ('a, 'b) t

    include VERSIONED

    include Serializable.S2 with type ('a, 'b) t := ('a, 'b) t

    include Comparable.S2 with type ('a, 'b) t := ('a, 'b) t

    include Hash_foldable.S2 with type ('a, 'b) t := ('a, 'b) t
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    include VERSIONED

    include Serializable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

    include Comparable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

    include Hash_foldable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
  end
end
