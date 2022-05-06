(* mina_caqti.ml -- Mina helpers for the Caqti database bindings *)

open Async
open Core_kernel
open Caqti_async
open Mina_base

type _ Caqti_type.field +=
  | Array_nullable_int : int option array Caqti_type.field

type _ Caqti_type.field +=
  | Array_nullable_string : string option array Caqti_type.field

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
         Caqti_type.tup2 rep (to_rep spec)

  let rec hlist_to_tuple :
            'hlist 'tuple.    ('hlist, 'tuple) t -> (unit, 'hlist) H_list.t
            -> 'tuple =
    fun (type hlist tuple) (spec : (hlist, tuple) t)
        (l : (unit, hlist) H_list.t) ->
     match (spec, l) with
     | [], [] ->
         (() : tuple)
     | _ :: spec, x :: l ->
         ((x, hlist_to_tuple spec l) : tuple)

  let rec tuple_to_hlist :
            'hlist 'tuple.    ('hlist, 'tuple) t -> 'tuple
            -> (unit, 'hlist) H_list.t =
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

(* register coding for nullable int arrays *)
let () =
  let open Caqti_type.Field in
  let rep = Caqti_type.String in
  let encode, decode =
    make_coding ~elem_to_string:Int.to_string ~elem_of_string:Int.of_string
  in
  let get_coding : type a. _ -> a t -> a coding =
   fun _ -> function
    | Array_nullable_int ->
        Coding { rep; encode; decode }
    | _ ->
        assert false
  in
  define_coding Array_nullable_int { get_coding }

(* register coding for nullable string arrays *)
let () =
  let open Caqti_type.Field in
  let rep = Caqti_type.String in
  let encode, decode =
    make_coding ~elem_to_string:Fn.id ~elem_of_string:Fn.id
  in
  let get_coding : type a. _ -> a t -> a coding =
   fun _ -> function
    | Array_nullable_string ->
        Coding { rep; encode; decode }
    | _ ->
        assert false
  in
  define_coding Array_nullable_string { get_coding }

(* this type may require type annotations in queries, eg.
  `SELECT id FROM zkapp_states WHERE element_ids = ?::int[]`
*)
let array_nullable_int_typ : int option array Caqti_type.t =
  Caqti_type.field Array_nullable_int

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

(* this type may require type annotations in queries, e.g.
  `SELECT id FROM zkapp_states WHERE element_ids = ?::string[]`
*)
let array_nullable_string_typ : string option array Caqti_type.t =
  Caqti_type.field Array_nullable_string

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
      (Int.succ index, res :: acc))
  >>| snd >>| List.rev

let deferred_result_list_map ~f = deferred_result_list_mapi ~f:(Fn.const f)

let deferred_result_lift_opt :
    ('a, 'err) Deferred.Result.t option -> ('a option, 'err) Deferred.Result.t =
  let open Deferred.Result.Let_syntax in
  function Some x -> x >>| Option.some | None -> return None

let add_if_some (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg option -> ('res option, 'err) Deferred.Result.t =
  Fn.compose deferred_result_lift_opt @@ Option.map ~f

let add_if_zkapp_set (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Zkapp_basic.Set_or_keep.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (add_if_some f) Zkapp_basic.Set_or_keep.to_option

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
        param)
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
    ?(tannot : string -> string option = Fn.const None) ~(cols : string list) ()
    : string =
  let values =
    List.map cols ~f:(fun col ->
        match tannot col with None -> "?" | Some tannot -> "?::" ^ tannot)
    |> String.concat ~sep:", "
  in
  sprintf "INSERT INTO %s (%s) VALUES (%s) RETURNING %s" table_name
    (String.concat ~sep:", " cols)
    values returning

let select_insert_into_cols ~(select : string * 'select Caqti_type.t)
    ~(table_name : string) ?tannot ~(cols : string list * 'cols Caqti_type.t)
    (module Conn : CONNECTION) (value : 'cols) =
  let open Deferred.Result.Let_syntax in
  Conn.find_opt
    ( Caqti_request.find_opt (snd cols) (snd select)
    @@ select_cols ~select:(fst select) ~table_name ?tannot ~cols:(fst cols) ()
    )
    value
  >>= function
  | Some id ->
      return id
  | None ->
      Conn.find
        ( Caqti_request.find (snd cols) (snd select)
        @@ insert_into_cols ~returning:(fst select) ~table_name ?tannot
             ~cols:(fst cols) () )
        value

let query ~f pool =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error querying db, error: %s" (Caqti_error.show msg) ()

(** functions to retrieve an item from the db, where the input has
    option type; the resulting option is converted to a suitable type
*)
let make_get_opt ~of_option ~f item_opt =
  let%map res_opt =
    Option.value_map item_opt ~default:(return None) ~f:(fun item ->
        match%map f item with
        | Ok v ->
            Some v
        | Error msg ->
            failwithf "Error querying db, error: %s" (Caqti_error.show msg) ())
  in
  of_option res_opt

let get_zkapp_set_or_keep (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Set_or_keep.t Deferred.t =
  make_get_opt ~of_option:Zkapp_basic.Set_or_keep.of_option ~f item_opt

let get_zkapp_or_ignore (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Or_ignore.t Deferred.t =
  make_get_opt item_opt ~of_option:Zkapp_basic.Or_ignore.of_option ~f

let get_opt_item (arg_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) : 'res option Deferred.t =
  make_get_opt ~of_option:Fn.id ~f arg_opt
