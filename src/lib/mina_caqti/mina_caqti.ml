(* mina_caqti.ml -- Mina helpers for the Caqti database bindings *)

open Async
open Core
open Mina_base

(* Caqti keys BOTH the server-side PREPARE and its own per-connection cache by
   request-object identity, so a [Caqti_request.t] built afresh on every call
   accumulates a prepared statement per call on every pooled connection, for
   the life of that connection (#18857). Its documented remedy is to define
   each request once in module scope, but nothing enforces that, and a call
   site that gets it wrong leaks silently rather than failing.

   So the constructors below memoise instead of relying on every call site:
   the request is keyed by its SQL text, and a cached request is only handed
   back when [Caqti_type.unify] certifies that the parameter and row types
   match. That is a type-equality proof from Caqti itself, which is what makes
   the shared cache sound without [Obj.magic].

   A query whose SQL text embeds its values differs on every call and must NOT
   be memoised -- pass [~oneshot:true], which is also what tells Caqti not to
   prepare it at all. *)
module Request_cache = struct
  type 'm entry =
    | E :
        'a Caqti_type.t * 'b Caqti_type.t * ('a, 'b, 'm) Caqti_request.t
        -> 'm entry

  (* The key set is the set of distinct SQL texts in the source, so it is
     bounded by construction: ~150 across the archive today. The cap is a
     tripwire for the one way that can stop being true -- a query whose text
     varies per call reaching the memoised path -- not a working limit.

     Note there is deliberately no eviction. Dropping an entry would not
     release anything: the prepared statement lives in the driver's
     per-connection table and on the server, both keyed by the request
     identity we would be discarding, and Caqti frees them only via
     [deallocate] on the very request object or on disconnect. Evicting would
     therefore keep the leak while hiding it from these counters, and force a
     re-PREPARE the next time the query ran. Refusing to grow, and saying so,
     is the honest failure mode. *)
  let max_entries = 512

  let hits = ref 0

  let first_builds = ref 0

  (* A repeat miss means the SQL was cached but the types did not unify, i.e.
     the call site builds its [Caqti_type.t] per call (an inline [t2]/[t3] or
     [custom] mints a fresh identity every time) and so can never share. Those
     still leak; the count is the regression signal. *)
  let repeat_misses : int String.Table.t = String.Table.create ()

  let capped = ref false

  let one : [ `One ] entry String.Table.t = String.Table.create ()

  let zero_or_one : [ `Zero | `One ] entry String.Table.t =
    String.Table.create ()

  let many : [ `Zero | `One | `Many ] entry String.Table.t =
    String.Table.create ()

  let zero : [ `Zero ] entry String.Table.t = String.Table.create ()

  let entries () =
    Hashtbl.length one + Hashtbl.length zero_or_one + Hashtbl.length many
    + Hashtbl.length zero

  let note_repeat_miss sql =
    Hashtbl.update repeat_misses sql ~f:(function None -> 1 | Some n -> n + 1)

  (* [true] once the cache is full: new SQL is then built [~oneshot:true],
     which is slower but registers nothing, so the failure mode is lost
     throughput rather than unbounded memory. *)
  let room_for sql =
    if entries () < max_entries then true
    else (
      if not !capped then (
        capped := true ;
        eprintf
          "mina_caqti: request cache reached %d entries; further queries run \
           un-prepared. A query whose SQL text varies per call has reached the \
           memoised path and should pass ~oneshot:true. First offender: %s\n\
           %!"
          max_entries (String.prefix sql 200) ) ;
      false )

  type stats =
    { hits : int
    ; first_builds : int
    ; repeat_misses : int
    ; entries : int
    ; capped : bool
    }

  let stats () =
    { hits = !hits
    ; first_builds = !first_builds
    ; repeat_misses =
        Hashtbl.fold repeat_misses ~init:0 ~f:(fun ~key:_ ~data acc ->
            acc + data )
    ; entries = entries ()
    ; capped = !capped
    }

  (* the SQL of each call site that cannot share its request, worst first *)
  let repeat_miss_report () =
    Hashtbl.to_alist repeat_misses
    |> List.sort ~compare:(fun (_, a) (_, b) -> Int.descending a b)
    |> List.map ~f:(fun (sql, n) -> (n, String.prefix sql 200))
end

(* Interned row types.

   [Caqti_type.t2] and friends mint a fresh product identity on every
   evaluation, and [Caqti_type.unify] -- which is what makes the request cache
   below sound -- compares products by that identity. So a query whose
   parameter type is written inline, [Caqti_type.(t2 int int)], gets a type
   that unifies with nothing but itself, and its request can never be shared.

   These combinators return the SAME type value for the same component types,
   by searching the types already built and reusing the one whose components
   [unify]. Call sites can then keep writing the type where it reads best,
   inline, and still land on the cached request. Interning is closed under
   itself: nested products come back interned too, so the components of a
   later lookup are identity-equal and unify in turn.

   Only products are interned. [Caqti_type.custom] carries encode/decode
   functions that cannot be compared, so two customs must never be treated as
   the same type -- those are expected to be named once in their table module,
   as {!Type_spec.custom_type} users already do. *)
module Typ = struct
  (* the field types, re-exported so [Typ.(t2 int int)] reads like the
     [Caqti_type] it replaces. Fields unify structurally, so they need no
     interning. *)
  let int = Caqti_type.int

  let int32 = Caqti_type.int32

  let int64 = Caqti_type.int64

  let string = Caqti_type.string

  let bool = Caqti_type.bool

  let float = Caqti_type.float

  let unit = Caqti_type.unit

  let option = Caqti_type.option

  type pair =
    | P : 'a Caqti_type.t * 'b Caqti_type.t * ('a * 'b) Caqti_type.t -> pair

  (* Small and append-only: one entry per distinct pair shape in the source,
     a handful in practice, so a list scan costs less than hashing would. *)
  let pairs : pair list ref = ref []

  let t2 : type a b. a Caqti_type.t -> b Caqti_type.t -> (a * b) Caqti_type.t =
   fun a b ->
    let rec search = function
      | [] ->
          let t = Caqti_type.t2 a b in
          pairs := P (a, b, t) :: !pairs ;
          t
      | P (a', b', t) :: rest -> (
          match (Caqti_type.unify a' a, Caqti_type.unify b' b) with
          | Some Caqti_type.Equal, Some Caqti_type.Equal ->
              t
          | _ ->
              search rest )
    in
    search !pairs

  (* [t3]/[t4] are flat tuples in Caqti, not nested pairs, so each arity is
     interned against its own table rather than composed out of [t2]. *)
  type triple =
    | T :
        'a Caqti_type.t
        * 'b Caqti_type.t
        * 'c Caqti_type.t
        * ('a * 'b * 'c) Caqti_type.t
        -> triple

  let triples : triple list ref = ref []

  let t3 : type a b c.
         a Caqti_type.t
      -> b Caqti_type.t
      -> c Caqti_type.t
      -> (a * b * c) Caqti_type.t =
   fun a b c ->
    let rec search = function
      | [] ->
          let t = Caqti_type.t3 a b c in
          triples := T (a, b, c, t) :: !triples ;
          t
      | T (a', b', c', t) :: rest -> (
          match
            (Caqti_type.unify a' a, Caqti_type.unify b' b, Caqti_type.unify c' c)
          with
          | Some Caqti_type.Equal, Some Caqti_type.Equal, Some Caqti_type.Equal
            ->
              t
          | _ ->
              search rest )
    in
    search !triples

  type quad =
    | Q :
        'a Caqti_type.t
        * 'b Caqti_type.t
        * 'c Caqti_type.t
        * 'd Caqti_type.t
        * ('a * 'b * 'c * 'd) Caqti_type.t
        -> quad

  let quads : quad list ref = ref []

  let t4 : type a b c d.
         a Caqti_type.t
      -> b Caqti_type.t
      -> c Caqti_type.t
      -> d Caqti_type.t
      -> (a * b * c * d) Caqti_type.t =
   fun a b c d ->
    let rec search = function
      | [] ->
          let t = Caqti_type.t4 a b c d in
          quads := Q (a, b, c, d, t) :: !quads ;
          t
      | Q (a', b', c', d', t) :: rest -> (
          match
            ( Caqti_type.unify a' a
            , Caqti_type.unify b' b
            , Caqti_type.unify c' c
            , Caqti_type.unify d' d )
          with
          | ( Some Caqti_type.Equal
            , Some Caqti_type.Equal
            , Some Caqti_type.Equal
            , Some Caqti_type.Equal ) ->
              t
          | _ ->
              search rest )
    in
    search !quads

  let interned () =
    List.length !pairs + List.length !triples + List.length !quads
end

(* The request constructors. Every query in the tree is built through these,
   which is what keeps the prepared-statement count bounded no matter where the
   call site puts them; scripts/lint_caqti_requests.sh keeps [Caqti_request]
   itself out of the rest of the tree.

   [Caqti_request.t]'s multiplicity parameter is constrained, which a locally
   abstract type cannot carry, so the lookup is written out once per
   multiplicity rather than shared. *)
let find_req : type a b.
       ?oneshot:bool
    -> a Caqti_type.t
    -> b Caqti_type.t
    -> string
    -> (a, b, [ `One ]) Caqti_request.t =
 fun ?(oneshot = false) t u s ->
  let open Request_cache in
  let build () = Caqti_request.Infix.(t ->! u) ~oneshot s in
  if oneshot then build ()
  else
    match Hashtbl.find one s with
    | Some (E (t', u', req)) -> (
        match (Caqti_type.unify t' t, Caqti_type.unify u' u) with
        | Some Caqti_type.Equal, Some Caqti_type.Equal ->
            incr hits ; req
        | _ ->
            note_repeat_miss s ; build () )
    | None ->
        incr first_builds ;
        let req = build () in
        if room_for s then Hashtbl.set one ~key:s ~data:(E (t, u, req)) ;
        req

let find_opt_req : type a b.
       ?oneshot:bool
    -> a Caqti_type.t
    -> b Caqti_type.t
    -> string
    -> (a, b, [ `Zero | `One ]) Caqti_request.t =
 fun ?(oneshot = false) t u s ->
  let open Request_cache in
  let build () = Caqti_request.Infix.(t ->? u) ~oneshot s in
  if oneshot then build ()
  else
    match Hashtbl.find zero_or_one s with
    | Some (E (t', u', req)) -> (
        match (Caqti_type.unify t' t, Caqti_type.unify u' u) with
        | Some Caqti_type.Equal, Some Caqti_type.Equal ->
            incr hits ; req
        | _ ->
            note_repeat_miss s ; build () )
    | None ->
        incr first_builds ;
        let req = build () in
        if room_for s then Hashtbl.set zero_or_one ~key:s ~data:(E (t, u, req)) ;
        req

let collect_req : type a b.
       ?oneshot:bool
    -> a Caqti_type.t
    -> b Caqti_type.t
    -> string
    -> (a, b, [ `Zero | `One | `Many ]) Caqti_request.t =
 fun ?(oneshot = false) t u s ->
  let open Request_cache in
  let build () = Caqti_request.Infix.(t ->* u) ~oneshot s in
  if oneshot then build ()
  else
    match Hashtbl.find many s with
    | Some (E (t', u', req)) -> (
        match (Caqti_type.unify t' t, Caqti_type.unify u' u) with
        | Some Caqti_type.Equal, Some Caqti_type.Equal ->
            incr hits ; req
        | _ ->
            note_repeat_miss s ; build () )
    | None ->
        incr first_builds ;
        let req = build () in
        if room_for s then Hashtbl.set many ~key:s ~data:(E (t, u, req)) ;
        req

let exec_req : type a.
       ?oneshot:bool
    -> a Caqti_type.t
    -> string
    -> (a, unit, [ `Zero ]) Caqti_request.t =
 fun ?(oneshot = false) t s ->
  let open Request_cache in
  let build () = Caqti_request.Infix.(t ->. Caqti_type.unit) ~oneshot s in
  if oneshot then build ()
  else
    match Hashtbl.find zero s with
    | Some (E (t', u', req)) -> (
        match (Caqti_type.unify t' t, Caqti_type.unify u' Caqti_type.unit) with
        | Some Caqti_type.Equal, Some Caqti_type.Equal ->
            incr hits ; req
        | _ ->
            note_repeat_miss s ; build () )
    | None ->
        incr first_builds ;
        let req = build () in
        if room_for s then
          Hashtbl.set zero ~key:s ~data:(E (t, Caqti_type.unit, req)) ;
        req

module type CONNECTION = sig
  include Caqti_async.CONNECTION

  (** Code expects any queries to differing sources to never interfere. *)
  val source : Uri.t
end

module Wrap
    (Conn : Caqti_async.CONNECTION)
    (Arg : sig
      val source : Uri.t
    end) : CONNECTION = struct
  include Conn
  include Arg
end

let wrap_conn (module Conn : Caqti_async.CONNECTION) ~source =
  let module Conn =
    Wrap
      (Conn)
      (struct
        let source = source
      end)
  in
  (module Conn : CONNECTION)

module Pool = struct
  type ('a, 'e) t = { source : Uri.t; pool : ('a, 'e) Caqti_async.Pool.t }

  let wrap ~source pool = { source; pool }

  let use (f : (module CONNECTION) -> 'a) pool =
    Caqti_async.Pool.use
      (fun (module Conn : Caqti_async.CONNECTION) ->
        f (wrap_conn (module Conn) ~source:pool.source) )
      pool.pool
end

let connect_pool ?max_size uri =
  let size = max_size in
  let%map.Result pool =
    Caqti_async.connect_pool
      ~pool_config:
        Caqti_pool_config.(
          merge_left (default_from_env ()) (create ?max_size:size ()) )
      uri
  in
  Pool.wrap ~source:uri pool

let connect uri =
  let%map.Deferred.Result conn = Caqti_async.connect uri in
  wrap_conn ~source:uri conn

module Type_spec = struct
  type (_, _) t =
    | [] : (unit, unit) t
    | ( :: ) : 'c Caqti_type.t * ('a, 'b) t -> ('c -> 'a, 'c * 'b) t

  let rec to_rep : 'hlist 'tuple. ('hlist, 'tuple) t -> 'tuple Caqti_type.t =
   fun (type hlist tuple) (spec : (hlist, tuple) t) ->
    match spec with
    | [] ->
        (Caqti_type.unit : tuple Caqti_type.t)
    | rep :: spec ->
        Caqti_type.t2 rep (to_rep spec)

  let rec hlist_to_tuple :
      'hlist 'tuple. ('hlist, 'tuple) t -> (unit, 'hlist) H_list.t -> 'tuple =
   fun (type hlist tuple) (spec : (hlist, tuple) t)
       (l : (unit, hlist) H_list.t) ->
    match (spec, l) with
    | [], [] ->
        (() : tuple)
    | _ :: spec, x :: l ->
        ((x, hlist_to_tuple spec l) : tuple)

  let rec tuple_to_hlist :
      'hlist 'tuple. ('hlist, 'tuple) t -> 'tuple -> (unit, 'hlist) H_list.t =
   fun (type hlist tuple) (spec : (hlist, tuple) t) (t : tuple) ->
    match (spec, t) with
    | [], () ->
        ([] : (unit, hlist) H_list.t)
    | _ :: spec, (x, t) ->
        x :: tuple_to_hlist spec t

  let custom_type ~to_hlist ~of_hlist tys =
    let encode t = Ok (hlist_to_tuple tys (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist tys t)) in
    Caqti_type.custom ~encode ~decode (to_rep tys)
end

module Vector = struct
  type (_, _, _, _) t =
    | [] : ('elem, unit, unit, Pickles_types.Nat.z) t
    | ( :: ) :
        'elem Caqti_type.t * ('elem, 'fun_t, 'tup_t, 'n) t
        -> ('elem, 'elem -> 'fun_t, 'elem * 'tup_t, 'n Pickles_types.Nat.s) t

  let rec vec_to_hlist :
      'elem 'hlist 'tup 'n.
         ('elem, 'hlist, 'tup, 'n) t
      -> ('elem, 'n) Pickles_types.Vector.t
      -> (unit, 'hlist) H_list.t =
   fun (type elem hlist tup n) (spec : (elem, hlist, tup, n) t)
       (v : (elem, n) Pickles_types.Vector.t) ->
    match (spec, v) with
    | [], [] ->
        ([] : (unit, hlist) H_list.t)
    | _ :: spec, x :: v ->
        x :: vec_to_hlist spec v

  let rec hlist_to_vec :
      'elem 'hlist 'tup 'n.
         ('elem, 'hlist, 'tup, 'n) t
      -> (unit, 'hlist) H_list.t
      -> ('elem, 'n) Pickles_types.Vector.t =
   fun (type elem hlist tup n) (spec : (elem, hlist, tup, n) t)
       (l : (unit, hlist) H_list.t) ->
    match (spec, l) with
    | _ :: spec, x :: l ->
        (x :: hlist_to_vec spec l : (elem, n) Pickles_types.Vector.t)
    | [], [] ->
        []

  module type Intf = sig
    (** defines a function type, like ['elem -> 'elem -> ... -> 'elem -> unit] *)
    type 'elem fun_t

    (** defines a tuple type, like ['elem * 'elem * ... * 'elem * unit] *)
    type 'elem tup_t

    type n

    val spec : 'elem Caqti_type.t -> ('elem, 'elem fun_t, 'elem tup_t, n) t

    val type_spec : 'elem Caqti_type.t -> ('elem fun_t, 'elem tup_t) Type_spec.t
  end

  let rec spec_of_nat : type n.
      n Plonkish_prelude.Nat.nat -> (module Intf with type n = n) = function
    | Z ->
        let module N = struct
          type 'elem fun_t = unit

          type 'elem tup_t = unit

          type n = Pickles_types.Nat.z

          let spec _ = []

          let type_spec _ = Type_spec.[]
        end in
        (module N : Intf with type n = n)
    | S p ->
        let (module Prev) = spec_of_nat p in
        let module N = struct
          type 'elem fun_t = 'elem -> 'elem Prev.fun_t

          type 'elem tup_t = 'elem * 'elem Prev.tup_t

          type n = Prev.n Pickles_types.Nat.s

          let spec : type elem.
              elem Caqti_type.t -> (elem, elem fun_t, elem tup_t, n) t =
           fun t -> t :: Prev.spec t

          let type_spec :
              'elem Caqti_type.t -> ('elem fun_t, 'elem tup_t) Type_spec.t =
           fun t -> t :: Prev.type_spec t
        end in
        (module N : Intf with type n = n)

  let typ : type elem n.
         elem Caqti_type.t * n Plonkish_prelude.Nat.nat
      -> (elem, n) Pickles_types.Vector.vec Caqti_type.t =
   fun (elem, n) ->
    let (module M) = spec_of_nat n in
    Type_spec.custom_type
      ~to_hlist:(vec_to_hlist (M.spec elem))
      ~of_hlist:(hlist_to_vec (M.spec elem))
      (M.type_spec elem)
end

(* build coding for array type that can be interpreted as a string

   for example, the ocaml string array `[| "foo"; "bar"; "baz" |]` would be encoded to
   `'{foo, bar, baz}'` for postgresql. There is no need to add the single quotes,
   as caqti does this when using a string representation.
   type annotations are necessary for array values in postgresql, e.g.
   `SELECT id FROM zkapp_states WHERE element_ids = '{foo,bar,baz,...}'::string[]`
*)

let make_coding (type a) ~(elem_to_string : a -> string)
    ~(elem_of_string : string -> a) =
  let encode xs =
    Array.map xs ~f:(Option.value_map ~f:elem_to_string ~default:"NULL")
    |> String.concat_array ~sep:", "
    |> sprintf "{ %s }" |> Result.return
  in
  let decode s =
    let open Result.Let_syntax in
    let error = "Failed to decode nullable array" in
    let decode_elem = function
      | "NULL" | "null" ->
          return None
      | elem -> (
          try return @@ Option.some @@ elem_of_string elem
          with _ -> Result.fail error )
    in
    String.chop_prefix ~prefix:"{" s
    |> Result.of_option ~error
    >>= fun s ->
    String.chop_suffix ~suffix:"}" s
    |> Result.of_option ~error
    >>= fun s ->
    String.filter ~f:(Char.( <> ) ' ') s
    |> String.split ~on:','
    |> List.filter ~f:(fun s -> not @@ String.is_empty s)
    |> List.map ~f:decode_elem |> Result.all >>| List.to_array
  in
  (encode, decode)

(** this type may require type annotations in queries, eg.
   `SELECT id FROM zkapp_states WHERE element_ids = ?::int[]`
*)
let array_nullable_int_typ =
  let encode, decode =
    make_coding ~elem_to_string:Int.to_string ~elem_of_string:Int.of_string
  in
  Caqti_type.custom ~encode ~decode Caqti_type.string

let array_int_typ : int array Caqti_type.t =
  let open Result.Let_syntax in
  let encode xs = return @@ Array.map ~f:Option.some xs in
  let decode xs =
    Option.all (Array.to_list xs)
    |> Result.of_option
         ~error:"Failed to decode int array, encountered NULL value"
    >>| Array.of_list
  in
  Caqti_type.custom array_nullable_int_typ ~encode ~decode

(** this type may require type annotations in queries, eg.
   `SELECT id FROM zkapp_states WHERE element_ids = ?::bigint[]`
*)
let array_nullable_int64_typ =
  let encode, decode =
    make_coding ~elem_to_string:Int64.to_string ~elem_of_string:Int64.of_string
  in
  Caqti_type.custom ~encode ~decode Caqti_type.string

let array_int64_typ : int64 array Caqti_type.t =
  let open Result.Let_syntax in
  let encode xs = return @@ Array.map ~f:Option.some xs in
  let decode xs =
    Option.all (Array.to_list xs)
    |> Result.of_option
         ~error:"Failed to decode int64 array, encountered NULL value"
    >>| Array.of_list
  in
  Caqti_type.custom array_nullable_int64_typ ~encode ~decode

(*** this type may require type annotations in queries, e.g.
   `SELECT id FROM zkapp_states WHERE element_ids = ?::string[]`
*)
let array_nullable_string_typ =
  let encode, decode =
    make_coding ~elem_to_string:Fn.id ~elem_of_string:Fn.id
  in
  Caqti_type.custom ~encode ~decode Caqti_type.string

let array_string_typ : string array Caqti_type.t =
  let open Result.Let_syntax in
  let encode xs = return @@ Array.map ~f:Option.some xs in
  let decode xs =
    Option.all (Array.to_list xs)
    |> Result.of_option
         ~error:"Failed to decode string array, encountered NULL value"
    >>| Array.of_list
  in
  Caqti_type.custom array_nullable_string_typ ~encode ~decode

(* process a Caqti query on list of items
   if we were instead to simply map the query over the list,
    we'd get "in use" assertion failures for the connection
   the bind makes sure the connection is available for
    each query
*)
let rec deferred_result_list_fold ls ~init ~f =
  let open Deferred.Result.Let_syntax in
  match ls with
  | [] ->
      return init
  | h :: t ->
      let%bind init = f init h in
      deferred_result_list_fold t ~init ~f

let deferred_result_list_mapi ~f xs =
  let open Deferred.Result.Let_syntax in
  deferred_result_list_fold xs ~init:(0, []) ~f:(fun (index, acc) x ->
      let%map res = f index x in
      (Int.succ index, res :: acc) )
  >>| snd >>| List.rev

let deferred_result_list_map ~f = deferred_result_list_mapi ~f:(Fn.const f)

let deferred_result_lift_opt :
    ('a, 'err) Deferred.Result.t option -> ('a option, 'err) Deferred.Result.t =
  let open Deferred.Result.Let_syntax in
  function Some x -> x >>| Option.some | None -> return None

let add_if_some (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg option -> ('res option, 'err) Deferred.Result.t =
  Fn.compose deferred_result_lift_opt @@ Option.map ~f

(* if zkApp-related item is Set, run `f` *)
let add_if_zkapp_set (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Zkapp_basic.Set_or_keep.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (add_if_some f) Zkapp_basic.Set_or_keep.to_option

(* if zkApp-related item is Check, run `f` *)
let add_if_zkapp_check (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Zkapp_basic.Or_ignore.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (add_if_some f) Zkapp_basic.Or_ignore.to_option

(* `select_cols ~select:"s0" ~table_name:"t0" ~cols:["col0";"col1";...] ()`
   creates the string
   `"SELECT s0 FROM t0 WHERE (col0 = $1 OR (col0 IS NULL AND $1 IS NULL)) AND ..."`

   The optional `tannot` function maps column names to type annotations.
*)

let select_cols ~(select : string) ~(table_name : string)
    ?(tannot : string -> string option = Fn.const None) ~(cols : string list) ()
    : string =
  List.mapi cols ~f:(fun ndx col ->
      let param = ndx + 1 in
      let annot =
        match tannot col with None -> "" | Some tannot -> "::" ^ tannot
      in
      sprintf "(%s = $%d%s OR (%s IS NULL AND $%d IS NULL))" col param annot col
        param )
  |> String.concat ~sep:" AND "
  |> sprintf "SELECT %s FROM %s WHERE %s" select table_name

(* `select_cols_from_id ~table_name:"t0" ~cols:["col0";"col1";...]`
   creates the string
   `"SELECT col0,col1,... FROM t0 WHERE id = ?"`
*)
let select_cols_from_id ~(table_name : string) ~(cols : string list) : string =
  let comma_cols = String.concat cols ~sep:"," in
  sprintf "SELECT %s FROM %s WHERE id = ?" comma_cols table_name

(* `insert_into_cols ~returning:ret0 ~table_name:t0 ~cols:["col0";"col1";...]`
   creates the string
   `"INSERT INTO t0 (col0, col1, ...) VALUES (?, ?, ...) RETURNING ret0"`.
   The optional `tannot` function maps column names to type annotations.
   No type annotation is included if `tannot` returns an empty string. *)
let insert_into_cols ~(returning : string) ~(table_name : string)
    ?(tannot : string -> string option = Fn.const None) ~(cols : string list)
    ?(on_conflict : string option) () : string =
  let values =
    List.map cols ~f:(fun col ->
        match tannot col with None -> "?" | Some tannot -> "?::" ^ tannot )
    |> String.concat ~sep:", "
  in
  let insert =
    sprintf "INSERT INTO %s (%s) VALUES (%s)" table_name
      (String.concat ~sep:", " cols)
      values
  in
  match on_conflict with
  | Some col ->
      let assignments =
        String.split col ~on:',' |> List.map ~f:String.strip
        |> List.map ~f:(fun col -> sprintf "%s = EXCLUDED.%s" col col)
        |> String.concat ~sep:", "
      in
      sprintf "%s ON CONFLICT (%s) DO UPDATE SET %s RETURNING %s" insert col
        assignments returning
  | None ->
      sprintf "%s RETURNING %s" insert returning

(* run `select_cols` and return the result, if found
   if not found, run `insert_into_cols` and return the result
*)
let select_insert_into_cols ~(select : string * 'select Caqti_type.t)
    ~(table_name : string) ?tannot ~(cols : string list * 'cols Caqti_type.t)
    (module Conn : CONNECTION) (value : 'cols) =
  let open Deferred.Result.Let_syntax in
  Conn.find_opt
    ( find_opt_req (snd cols) (snd select)
    @@ select_cols ~select:(fst select) ~table_name ?tannot ~cols:(fst cols) ()
    )
    value
  >>= function
  | Some id ->
      return id
  | None ->
      Conn.find
        ( find_req (snd cols) (snd select)
        @@ insert_into_cols ~returning:(fst select) ~table_name ?tannot
             ~cols:(fst cols) () )
        value

let sep_by_comma ?(parenthesis = false) xs =
  List.map xs ~f:(if parenthesis then sprintf "('%s')" else sprintf "'%s'")
  |> String.concat ~sep:", "

(* The values are rendered into the SQL text, so the statement differs on every
   call: it cannot be shared and is built [~oneshot:true], which keeps Caqti
   from preparing it at all. (Binding them as parameters instead is #18860.) *)
let insert_multi_into_col ~(table_name : string)
    ~(col : string * 'col Caqti_type.t) (module Conn : CONNECTION)
    (values : string list) =
  let open Deferred.Result.Let_syntax in
  let insert =
    sprintf
      {sql| INSERT INTO %s (%s) VALUES %s
            ON CONFLICT (%s)
            DO NOTHING |sql}
      table_name (fst col)
      (sep_by_comma ~parenthesis:true values)
      (fst col)
  in
  let%bind () = Conn.exec (exec_req ~oneshot:true Caqti_type.unit insert) () in
  let search =
    sprintf
      {sql| SELECT %s, id FROM %s
            WHERE %s in (%s) |sql}
      (fst col) table_name (fst col) (sep_by_comma values)
  in
  Conn.collect_list
    (collect_req ~oneshot:true Caqti_type.unit
       Caqti_type.(t2 (snd col) int)
       search )
    ()

(* Like the [None] branch of [select_insert_into_cols]: always INSERT and return
   the new [returning] value. Performs NO content lookup/dedup, so it is safe for
   columns without a UNIQUE constraint or index (e.g. the unbounded int[]
   zkapp_events/zkapp_field_array.element_ids whose UNIQUE/index was dropped). *)
let insert_into_cols_returning ~(returning : string * 'r Caqti_type.t)
    ~(table_name : string) ?tannot ~(cols : string list * 'cols Caqti_type.t)
    (module Conn : CONNECTION) (value : 'cols) =
  Conn.find
    ( find_req (snd cols) (snd returning)
    @@ insert_into_cols ~returning:(fst returning) ~table_name ?tannot
         ~cols:(fst cols) () )
    value

(* Like [insert_into_cols] but generates an upsert:
   INSERT INTO table (cols) VALUES (params)
   ON CONFLICT (on_conflict) DO UPDATE SET on_conflict = EXCLUDED.on_conflict
   RETURNING returning.
   The DO UPDATE is a no-op that returns the existing row's id when a conflict
   occurs, preventing UNIQUE violation errors under concurrent insertion. *)
let upsert_into_cols ~(on_conflict : string) ~(returning : string)
    ~(table_name : string) ?(tannot : string -> string option = Fn.const None)
    ~(cols : string list) () : string =
  insert_into_cols ~returning ~table_name ~tannot ~cols ~on_conflict ()

(* Upsert with ON CONFLICT, returning the id of either the newly inserted row
   or the existing row that caused the conflict. *)
let upsert_into_cols_returning ~(on_conflict : string)
    ~(returning : string * 'r Caqti_type.t) ~(table_name : string) ?tannot
    ~(cols : string list * 'cols Caqti_type.t) (module Conn : CONNECTION)
    (value : 'cols) =
  Conn.find
    ( find_req (snd cols) (snd returning)
    @@ upsert_into_cols ~on_conflict ~returning:(fst returning) ~table_name
         ?tannot ~cols:(fst cols) () )
    value

(* No-dedup multi-row insert of one column's pre-rendered SQL literals, returning
   the new ids in VALUES order (a single INSERT ... RETURNING returns rows in
   VALUES order in PostgreSQL). Unlike [insert_multi_into_col] there is NO
   ON CONFLICT and NO content SELECT-back, so it does not require a UNIQUE
   constraint and never deduplicates: identical inputs yield distinct rows. Used
   for zkapp_field_array.element_ids after its UNIQUE/index was dropped.
   As in [insert_multi_into_col] the values are rendered into the SQL, so the
   request is [~oneshot:true]. *)
let insert_multi_into_col_no_dedup ~(table_name : string) ~(col : string)
    (module Conn : CONNECTION) (values : string list) =
  let open Deferred.Result.Let_syntax in
  match values with
  | [] ->
      return []
  | _ ->
      let insert =
        sprintf "INSERT INTO %s (%s) VALUES %s RETURNING id" table_name col
          (sep_by_comma ~parenthesis:true values)
      in
      Conn.collect_list
        (collect_req ~oneshot:true Caqti_type.unit Caqti_type.int insert)
        ()

(** Unwrap a Caqti result, raising on error. [ctx] names the operation being
    performed and is prepended to the message. *)
let ok_exn ?ctx = function
  | Ok v ->
      v
  | Error msg ->
      failwithf "%sError querying db, error: %s"
        (Option.value_map ctx ~default:"" ~f:(sprintf "%s: "))
        (Caqti_error.show msg) ()

let query ~f pool =
  let%map res = Pool.use f pool in
  ok_exn res

(** functions to retrieve an item from the db, where the input has
    option type; the resulting option is converted to a suitable type
*)
let make_get_opt ~of_option ~f item_opt =
  let%map res_opt =
    Option.value_map item_opt ~default:(return None) ~f:(fun item ->
        let%map res = f item in
        Some (ok_exn res) )
  in
  of_option res_opt

(** convert options to Set or Keep for zkApps-related results *)
let get_zkapp_set_or_keep (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Set_or_keep.t Deferred.t =
  make_get_opt ~of_option:Zkapp_basic.Set_or_keep.of_option ~f item_opt

(** convert options to Check or Ignore for zkApps-related results *)
let get_zkapp_or_ignore (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Or_ignore.t Deferred.t =
  make_get_opt item_opt ~of_option:Zkapp_basic.Or_ignore.of_option ~f

let get_opt_item (arg_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) : 'res option Deferred.t =
  make_get_opt ~of_option:Fn.id ~f arg_opt

let%test_module "request cache" =
  ( module struct
    (* The point of the cache is object identity: Caqti prepares and caches per
       request object, so "the same query twice" must be physically the same
       value, not merely an equal one. *)
    let sql n = sprintf "SELECT id FROM cache_test_%d WHERE value = ?" n

    let%test "the same query with the same types is the same object" =
      let a = find_req Caqti_type.string Caqti_type.int (sql 1) in
      let b = find_req Caqti_type.string Caqti_type.int (sql 1) in
      phys_equal a b

    let%test "different multiplicities do not collide" =
      let a = find_req Caqti_type.string Caqti_type.int (sql 2) in
      let b = find_opt_req Caqti_type.string Caqti_type.int (sql 2) in
      (* [b] cannot be [a]: their types differ. Distinct tables, so both are
         cached, and each is stable across calls. *)
      phys_equal b (find_opt_req Caqti_type.string Caqti_type.int (sql 2))
      && phys_equal a (find_req Caqti_type.string Caqti_type.int (sql 2))

    let%test "a oneshot request is never shared" =
      let a = find_req ~oneshot:true Caqti_type.string Caqti_type.int (sql 3) in
      let b = find_req ~oneshot:true Caqti_type.string Caqti_type.int (sql 3) in
      (not (phys_equal a b))
      (* and it does not poison the cache for the shared path *)
      && phys_equal
           (find_req Caqti_type.string Caqti_type.int (sql 3))
           (find_req Caqti_type.string Caqti_type.int (sql 3))

    (* A call site that builds its [Caqti_type.t] inside the function gets a
       fresh product identity every call, so it can never share -- this is the
       failure the repeat-miss counter exists to make visible. *)
    let%test "a per-call type is counted as a repeat miss" =
      let before = (Request_cache.stats ()).repeat_misses in
      let query = sql 4 in
      let mk () = Caqti_type.(t2 string string) in
      let a = find_req (mk ()) Caqti_type.int query in
      let b = find_req (mk ()) Caqti_type.int query in
      let after = (Request_cache.stats ()).repeat_misses in
      (not (phys_equal a b)) && after > before

    (* [Typ] exists so that a type written inline still shares. If interning
       ever broke, the request cache would silently stop sharing every query
       whose type is built at the call site. *)
    let%test "an interned pair is the same object as an equal one" =
      phys_equal Typ.(t2 int int) Typ.(t2 int int)
      && phys_equal Typ.(t3 int string int64) Typ.(t3 int string int64)
      && phys_equal Typ.(t4 int int int int) Typ.(t4 int int int int)

    let%test "interning distinguishes different component types" =
      (* different shapes must not be conflated: [unify] is the predicate the
         request cache trusts, so ask it rather than [phys_equal], which would
         not even typecheck across two different row types *)
      Option.is_none (Caqti_type.unify Typ.(t2 int int) Typ.(t2 int string))

    let%test "interning nests: a pair of pairs shares too" =
      phys_equal Typ.(t2 (t2 int string) int) Typ.(t2 (t2 int string) int)

    let%test "a type written inline at the call site still shares its request" =
      let query = sql 6 in
      let a = find_req Typ.(t2 int string) Caqti_type.int query in
      let b = find_req Typ.(t2 int string) Caqti_type.int query in
      phys_equal a b

    let%test "a shared type is not counted as a repeat miss" =
      let before = (Request_cache.stats ()).repeat_misses in
      let query = sql 5 in
      let typ = Caqti_type.(t2 string string) in
      let a = find_req typ Caqti_type.int query in
      let b = find_req typ Caqti_type.int query in
      let after = (Request_cache.stats ()).repeat_misses in
      phys_equal a b && after = before
  end )
