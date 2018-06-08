open Core

module Make
    (Hash : sig
       type t [@@deriving bin_io, eq, sexp]

       val merge : height:int -> t -> t -> t
     end)
    (Key : sig type t [@@deriving bin_io, eq, sexp] end)
    (Account : sig
       type t [@@deriving bin_io, eq, sexp]

       val hash : t -> Hash.t

       val key : t -> Key.t
     end) : sig
  type t
  [@@deriving bin_io, sexp]

  type index = int

  val of_hash : depth:int -> Hash.t -> t

  val get_exn : t -> index -> Account.t

  val path_exn : t -> index -> [ `Left of Hash.t | `Right of Hash.t ] list

  val set_exn : t -> index -> Account.t -> t

  val find_index_exn : t -> Key.t -> index

  val add_path : t -> [`Left of Hash.t | `Right of Hash.t] list -> Account.t -> t

  val merkle_root : t -> Hash.t
end

