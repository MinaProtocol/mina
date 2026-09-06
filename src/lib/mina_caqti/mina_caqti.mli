(* mina_caqti.mli -- Mina helpers for the Caqti database bindings *)

open Async
open Core
open Mina_base

(** {1 Building requests}

    Caqti caches a prepared statement per request {e object}, on every
    connection that runs it, for the life of that connection. A request built
    inside a function therefore leaks one prepared statement per call, on the
    client and on the server both (MinaProtocol/mina#18857).

    These constructors are the only way to build a request in this tree --
    [Caqti_request] is off limits elsewhere, enforced by
    [scripts/lint_caqti_requests.sh] -- and they memoise on the SQL text, so a
    call site cannot leak that way whatever it does with the result. *)

(** A request built by this library.

    The type is private, so a value can only come from the constructors below,
    and {!CONNECTION} accepts nothing else. Bypassing the memoisation is
    therefore not a matter of convention: a hand-built [Caqti_request.t] is not
    something any connection here will run. *)
type ('a, 'b, 'm) query = private ('a, 'b, 'm) Caqti_request.t
  constraint 'm = [< `Zero | `One | `Many ]

(** [find_req pt rt sql] is a request returning exactly one row.

    The request is shared with every other call passing the same [sql] whose
    [pt]/[rt] {!Caqti_type.unify}, so it is prepared once per connection rather
    than once per call.

    Pass [~oneshot:true] when the SQL text embeds its values and so differs per
    call: such a query cannot be shared, and this keeps Caqti from preparing it
    at all. Everything else must be left cacheable. *)
val find_req :
     ?oneshot:bool
  -> 'a Caqti_type.t
  -> 'b Caqti_type.t
  -> string
  -> ('a, 'b, [ `One ]) query

(** as {!find_req}, for a request returning zero or one row *)
val find_opt_req :
     ?oneshot:bool
  -> 'a Caqti_type.t
  -> 'b Caqti_type.t
  -> string
  -> ('a, 'b, [ `Zero | `One ]) query

(** as {!find_req}, for a request returning any number of rows *)
val collect_req :
     ?oneshot:bool
  -> 'a Caqti_type.t
  -> 'b Caqti_type.t
  -> string
  -> ('a, 'b, [ `Zero | `One | `Many ]) query

(** as {!find_req}, for a request returning no rows *)
val exec_req :
  ?oneshot:bool -> 'a Caqti_type.t -> string -> ('a, unit, [ `Zero ]) query

(** Row types that can be shared.

    [Caqti_type.t2] and friends mint a fresh product identity per evaluation,
    and {!Caqti_type.unify} compares products by identity, so a type written
    inline at a call site would stop {!Req} from sharing that query's request.
    These return the same type value for the same components, so a type may be
    written where it reads best. Custom types are not interned -- they carry
    encode/decode functions that cannot be compared -- so those are still
    named once per table module, as {!Type_spec.custom_type} users do. *)
module Typ : sig
  val int : int Caqti_type.t

  val int32 : int32 Caqti_type.t

  val int64 : int64 Caqti_type.t

  val string : string Caqti_type.t

  val bool : bool Caqti_type.t

  val float : float Caqti_type.t

  val unit : unit Caqti_type.t

  val option : 'a Caqti_type.t -> 'a option Caqti_type.t

  val t2 : 'a Caqti_type.t -> 'b Caqti_type.t -> ('a * 'b) Caqti_type.t

  val t3 :
       'a Caqti_type.t
    -> 'b Caqti_type.t
    -> 'c Caqti_type.t
    -> ('a * 'b * 'c) Caqti_type.t

  val t4 :
       'a Caqti_type.t
    -> 'b Caqti_type.t
    -> 'c Caqti_type.t
    -> 'd Caqti_type.t
    -> ('a * 'b * 'c * 'd) Caqti_type.t

  (** number of distinct product types interned so far; for tests *)
  val interned : unit -> int
end

(** What the request cache is doing, for benchmarks and regression guards.

    [repeat_misses] is the number to watch: a query whose SQL was cached but
    whose types did not unify, which means the call site builds its
    [Caqti_type.t] per call and so prepares a fresh statement every time.
    [capped] means the cache stopped growing (see {!Req}) because some query's
    SQL text varies per call. Both should be zero/false. *)
module Request_cache : sig
  type stats =
    { hits : int
    ; first_builds : int
    ; repeat_misses : int
    ; entries : int
    ; capped : bool
    }

  val stats : unit -> stats

  (** the SQL of each query that could not share its request, worst first,
      truncated for logging *)
  val repeat_miss_report : unit -> (int * string) list
end

(** {1 Connections} *)

(** The connection surface Mina uses, stated over {!query} rather than included
    from Caqti_async, whose members would take any request at all. Anything
    Caqti offers that is missing here can be added; it is deliberately the set
    the tree actually calls. *)
module type CONNECTION = sig
  (** Code expects any queries to differing sources to never interfere. *)
  val source : Uri.t

  val find :
       ('a, 'b, [< `One ]) query
    -> 'a
    -> ('b, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

  val find_opt :
       ('a, 'b, [< `Zero | `One ]) query
    -> 'a
    -> ('b option, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

  val collect_list :
       ('a, 'b, [< `Zero | `One | `Many ]) query
    -> 'a
    -> ('b list, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

  val fold :
       ('a, 'b, [< `Zero | `One | `Many ]) query
    -> ('b -> 'c -> 'c)
    -> 'a
    -> 'c
    -> ('c, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

  val exec :
       ('a, unit, [< `Zero ]) query
    -> 'a
    -> (unit, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

  val populate :
       table:string
    -> columns:string list
    -> 'a Caqti_type.t
    -> ('a, 'err) Caqti_async.Stream.t
    -> ( unit
       , [> Caqti_error.call_or_retrieve | `Congested of 'err ] )
       Deferred.Result.t

  val start : unit -> (unit, [> Caqti_error.transact ]) Deferred.Result.t

  val commit : unit -> (unit, [> Caqti_error.transact ]) Deferred.Result.t

  val rollback : unit -> (unit, [> Caqti_error.transact ]) Deferred.Result.t

  val disconnect : unit -> unit Deferred.t
end

module Pool : sig
  (* the error parameter is covariant, as in [Caqti_async.Pool], so a pool of a
     specific error type can be used where a wider one is expected *)
  type ('a, +'e) t

  (** [use f pool] runs [f] on a connection drawn from [pool] *)
  val use :
       ((module CONNECTION) -> ('b, 'e) Deferred.Result.t)
    -> ((module Caqti_async.CONNECTION), 'e) t
    -> ('b, 'e) Deferred.Result.t
end

val connect_pool :
     ?max_size:int
  -> Uri.t
  -> ( ((module Caqti_async.CONNECTION), [> Caqti_error.connect ]) Pool.t
     , [> Caqti_error.load ] )
     Result.t

val connect :
     Uri.t
  -> ((module CONNECTION), [> Caqti_error.load_or_connect ]) Deferred.Result.t

(** run [f] on a pooled connection, raising on error *)
val query :
     f:
       (   (module CONNECTION)
        -> ('a, ([< Caqti_error.t ] as 'e)) Deferred.Result.t )
  -> ((module Caqti_async.CONNECTION), 'e) Pool.t
  -> 'a Deferred.t

(** Render a query for a log line, with its parameters when given. *)
val query_to_string : ?params:'a -> ('a, 'b, 'm) query -> string

(** Unwrap a Caqti result, raising on error. [ctx] names the operation being
    performed and is prepended to the message. *)
val ok_exn : ?ctx:string -> ('a, [< Caqti_error.t ]) Result.t -> 'a

(** {1 Row types} *)

module Type_spec : sig
  type (_, _) t =
    | [] : (unit, unit) t
    | ( :: ) : 'c Caqti_type.t * ('a, 'b) t -> ('c -> 'a, 'c * 'b) t

  val custom_type :
       to_hlist:('a -> (unit, 'hlist) H_list.t)
    -> of_hlist:((unit, 'hlist) H_list.t -> 'a)
    -> ('hlist, 'tuple) t
    -> 'a Caqti_type.t
end

module Vector : sig
  type (_, _, _, _) t =
    | [] : ('elem, unit, unit, Pickles_types.Nat.z) t
    | ( :: ) :
        'elem Caqti_type.t * ('elem, 'fun_t, 'tup_t, 'n) t
        -> ('elem, 'elem -> 'fun_t, 'elem * 'tup_t, 'n Pickles_types.Nat.s) t

  val typ :
       'elem Caqti_type.t * 'n Plonkish_prelude.Nat.nat
    -> ('elem, 'n) Pickles_types.Vector.vec Caqti_type.t
end

(** these may require a type annotation in the query, e.g.
    [SELECT id FROM zkapp_states WHERE element_ids = ?::int[]] *)

val array_int_typ : int array Caqti_type.t

val array_int64_typ : int64 array Caqti_type.t

val array_string_typ : string array Caqti_type.t

(** {1 Query building}

    SQL fragments assembled from a table module's [table_name] and [Fields.names],
    and the insert/upsert helpers built on them. *)

(** [select_cols ~select:"s0" ~table_name:"t0" ~cols:["col0";"col1"] ()] is
    ["SELECT s0 FROM t0 WHERE (col0 = $1 OR (col0 IS NULL AND $1 IS NULL)) AND ..."].
    [tannot] maps a column name to a type annotation. *)
val select_cols :
     select:string
  -> table_name:string
  -> ?tannot:(string -> string option)
  -> cols:string list
  -> unit
  -> string

(** [select_cols_from_id ~table_name:"t0" ~cols:["col0";"col1"]] is
    ["SELECT col0,col1 FROM t0 WHERE id = ?"] *)
val select_cols_from_id : table_name:string -> cols:string list -> string

(** [insert_into_cols ~returning ~table_name ~cols ()] is
    ["INSERT INTO t0 (col0, ...) VALUES (?, ...) RETURNING ret0"], with an
    [ON CONFLICT (c) DO UPDATE] clause when [on_conflict] is given. *)
val insert_into_cols :
     returning:string
  -> table_name:string
  -> ?tannot:(string -> string option)
  -> cols:string list
  -> ?on_conflict:string
  -> unit
  -> string

(** run {!select_cols} and return the result if found, otherwise
    {!insert_into_cols} and return that *)
val select_insert_into_cols :
     select:string * 'select Caqti_type.t
  -> table_name:string
  -> ?tannot:(string -> string option)
  -> cols:string list * 'cols Caqti_type.t
  -> (module CONNECTION)
  -> 'cols
  -> ('select, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

(** Like the [None] branch of {!select_insert_into_cols}: always INSERT and
    return the new [returning] value. Performs NO content lookup, so it is safe
    for columns without a UNIQUE constraint. *)
val insert_into_cols_returning :
     returning:string * 'r Caqti_type.t
  -> table_name:string
  -> ?tannot:(string -> string option)
  -> cols:string list * 'cols Caqti_type.t
  -> (module CONNECTION)
  -> 'cols
  -> ('r, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

(** Upsert with ON CONFLICT, returning the id of either the newly inserted row
    or the existing row that caused the conflict. *)
val upsert_into_cols_returning :
     on_conflict:string
  -> returning:string * 'r Caqti_type.t
  -> table_name:string
  -> ?tannot:(string -> string option)
  -> cols:string list * 'cols Caqti_type.t
  -> (module CONNECTION)
  -> 'cols
  -> ('r, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

(** Multi-row insert of one column's values, ON CONFLICT DO NOTHING, returning
    each value with its id. The values are rendered into the SQL text, so the
    statement is [~oneshot] and never shared. *)
val insert_multi_into_col :
     table_name:string
  -> col:string * 'col Caqti_type.t
  -> (module CONNECTION)
  -> string list
  -> (('col * int) list, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

(** As {!insert_multi_into_col} but with NO ON CONFLICT and no select-back, so
    it needs no UNIQUE constraint and never deduplicates: identical inputs
    yield distinct rows. Returns the new ids in VALUES order. *)
val insert_multi_into_col_no_dedup :
     table_name:string
  -> col:string
  -> (module CONNECTION)
  -> string list
  -> (int list, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t

(** {1 Sequencing queries}

    A Caqti connection is single-use at a time, so a list of queries has to be
    folded rather than mapped: the bind is what keeps the connection free for
    the next one. *)

val deferred_result_list_fold :
     'a list
  -> init:'b
  -> f:('b -> 'a -> ('b, 'e) Deferred.Result.t)
  -> ('b, 'e) Deferred.Result.t

val deferred_result_list_map :
     f:('a -> ('b, 'e) Deferred.Result.t)
  -> 'a list
  -> ('b list, 'e) Deferred.Result.t

(** run [f] on the value if there is one *)
val add_if_some :
     ('arg -> ('res, 'err) Deferred.Result.t)
  -> 'arg option
  -> ('res option, 'err) Deferred.Result.t

(** run [f] if the zkApp-related item is Set *)
val add_if_zkapp_set :
     ('arg -> ('res, 'err) Deferred.Result.t)
  -> 'arg Zkapp_basic.Set_or_keep.t
  -> ('res option, 'err) Deferred.Result.t

(** run [f] if the zkApp-related item is Check *)
val add_if_zkapp_check :
     ('arg -> ('res, 'err) Deferred.Result.t)
  -> 'arg Zkapp_basic.Or_ignore.t
  -> ('res option, 'err) Deferred.Result.t

(** convert an option result to Set or Keep for zkApps-related results *)
val get_zkapp_set_or_keep :
     'arg option
  -> f:('arg -> ('res, [< Caqti_error.t ]) Deferred.Result.t)
  -> 'res Zkapp_basic.Set_or_keep.t Deferred.t

val get_opt_item :
     'arg option
  -> f:('arg -> ('res, [< Caqti_error.t ]) Deferred.Result.t)
  -> 'res option Deferred.t
