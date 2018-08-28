open Core

module type Key = sig
  type t [@@deriving sexp, bin_io]

  val empty : t

  include Hashable.S_binable with type t := t
end

module type Balance = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account = sig
  type t [@@deriving bin_io, eq]

  type balance

  val empty : t

  val balance : t -> balance

  val set_balance : t -> balance -> t

  val public_key : t -> string
end

module type Hash = sig
  type t [@@deriving bin_io]

  type account

  val empty : t

  val merge : height:int -> t -> t -> t

  val hash_account : account -> t
end

module type Depth = sig
  val depth : int
end

module type Key_value_database = sig
  type t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database = sig
  type t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option

  val length : t -> int
end
