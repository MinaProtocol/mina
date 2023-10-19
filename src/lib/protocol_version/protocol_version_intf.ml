module type Full = sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, equal, sexp, yojson, hash, annot]
    end
  end]

  val transaction : t -> int

  val network : t -> int

  val patch : t -> int

  val create : transaction:int -> network:int -> patch:int -> t

  val current : t

  val get_proposed_opt : unit -> t option

  val set_proposed_opt : t option -> unit

  (** a daemon can accept blocks or RPC responses with compatible protocol versions *)
  val compatible_with_daemon : t -> bool

  val to_string : t -> string

  val of_string_exn : string -> t

  val of_string_opt : string -> t option

  (** useful when deserializing, could contain negative integers *)
  val is_valid : t -> bool

  val equal_to_current : t -> bool

  val older_than_current : t -> bool

  val gen : t Core_kernel.Quickcheck.Generator.t

  val deriver :
       (< contramap : (t -> t) ref
        ; graphql_arg :
            (unit -> t Fields_derivers_graphql.Schema.Arg.arg_typ) ref
        ; graphql_arg_accumulator :
            t Fields_derivers_graphql.Graphql.Args.Acc.T.t ref
        ; graphql_creator : ('a -> t) ref
        ; graphql_fields :
            t Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
        ; graphql_fields_accumulator :
            t Fields_derivers_graphql.Graphql.Fields.Accumulator.T.t list ref
        ; graphql_query : string option ref
        ; graphql_query_accumulator : (string * string option) option list ref
        ; js_layout : [> `Assoc of (string * Yojson.Safe.t) list ] ref
        ; js_layout_accumulator :
            Fields_derivers_zkapps.Js_layout.Accumulator.field option list ref
        ; map : (t -> t) ref
        ; nullable_graphql_arg :
            (unit -> 'b Fields_derivers_graphql.Schema.Arg.arg_typ) ref
        ; nullable_graphql_fields :
            t option Fields_derivers_graphql.Graphql.Fields.Input.T.t ref
        ; of_json : ([> `Assoc of (string * Yojson.Safe.t) list ] -> t) ref
        ; of_json_creator : Yojson.Safe.t Core_kernel.String.Map.t ref
        ; skip : bool ref
        ; to_json : (t -> [> `Assoc of (string * Yojson.Safe.t) list ]) ref
        ; to_json_accumulator : (string * (t -> Yojson.Safe.t)) option list ref
        ; .. >
        as
        'a )
    -> 'a
end
