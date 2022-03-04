(* mina_caqti.ml -- Mina helpers for the Caqti database bindings *)

open Async
open Core_kernel
open Caqti_async
open Mina_base

type _ Caqti_type.field +=
  | Array_nullable_int : int option array Caqti_type.field

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

(* register coding for nullable int arrays.
   for example, the ocaml int array `[| 0; 1; 2 |]` would be encoded to
   `'{0, 1, 2}'` for postgresql. There is no need to add the single quotes,
   as caqti does this when using a string representation.
   type annotations are necessary for int array values in postgresql, eg.
   `SELECT id FROM snapp_states WHERE element_ids = '{0,1,2,...}'::int[]` *)
let () =
  let open Caqti_type.Field in
  let rep = Caqti_type.String in
  let encode xs =
    Array.map xs ~f:(Option.value_map ~f:Int.to_string ~default:"NULL")
    |> String.concat_array ~sep:", "
    |> sprintf "{ %s }" |> Result.return
  in
  let decode s =
    let open Result.Let_syntax in
    let error = "Failed to decode nullable int array" in
    let decode_elem = function
      | "NULL" | "null" ->
          return None
      | elem -> (
          try return @@ Option.some @@ Int.of_string elem
          with _ -> Result.fail error )
    in
    String.chop_prefix ~prefix:"{" s
    |> Result.of_option ~error
    >>= fun s ->
    String.chop_suffix ~suffix:"}" s
    |> Result.of_option ~error
    >>= fun s ->
    String.filter ~f:(Char.( <> ) ' ') s
    |> String.split ~on:',' |> List.map ~f:decode_elem |> Result.all
    >>| List.to_array
  in
  let get_coding : type a. _ -> a t -> a coding =
   fun _ -> function
    | Array_nullable_int ->
        Coding { rep; encode; decode }
    | _ ->
        assert false
  in
  define_coding Array_nullable_int { get_coding }

(* this type may require type annotations in queries, eg.
  `SELECT id FROM snapp_states WHERE element_ids = ?::int[]`
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

let add_if_snapp_set (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Snapp_basic.Set_or_keep.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (add_if_some f) Snapp_basic.Set_or_keep.to_option

let add_if_snapp_check (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Snapp_basic.Or_ignore.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (add_if_some f) Snapp_basic.Or_ignore.to_option

(* `select_cols ~select:"s0" ~table_name:"t0" ~cols:["col0";"col1";...]`
   creates the string
   `"SELECT s0 FROM t0 WHERE col0 = ? AND col1 = ? AND..."`.
   The optional `tannot` function maps column names to type annotations. *)
let select_cols ~(select : string) ~(table_name : string)
    ?(tannot : string -> string option = Fn.const None) (cols : string list) :
    string =
  List.map cols ~f:(fun col ->
      let annot =
        match tannot col with None -> "" | Some tannot -> "::" ^ tannot
      in
      sprintf "%s = ?%s" col annot)
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
    ?(tannot : string -> string option = Fn.const None) (cols : string list) :
    string =
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
    @@ select_cols ~select:(fst select) ~table_name ?tannot (fst cols) )
    value
  >>= function
  | Some id ->
      return id
  | None ->
      Conn.find
        ( Caqti_request.find (snd cols) (snd select)
        @@ insert_into_cols ~returning:(fst select) ~table_name ?tannot
             (fst cols) )
        value

let query ~f pool =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error querying db, error: %s" (Caqti_error.show msg) ()
