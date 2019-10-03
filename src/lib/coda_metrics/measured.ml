open Core_kernel
open Prometheus

module type Metric_info_intf = sig
  val name : string

  val help : string
end

module type Hashtbl_limited_intf = sig
  type _ _real

  type 'a t = private 'a _real

  type key

  val cast : 'a _real -> 'a t

  (* raw *)
  val data : 'a t -> 'a list

  val mem : _ t -> key -> bool

  val find : 'a t -> key -> 'a option

  val find_exn : 'a t -> key -> 'a

  val iter : 'a t -> f:('a -> unit) -> unit

  val fold : 'a t -> init:'b -> f:(key:key -> data:'a -> 'b -> 'b) -> 'b

  (* wrapped *)
  val create : unit -> _ t

  val of_alist_exn : (key, 'a) List.Assoc.t -> 'a t

  val remove : _ t -> key -> unit

  val add : 'a t -> key:key -> data:'a -> [`Duplicate | `Ok]

  val add_exn : 'a t -> key:key -> data:'a -> unit

  val set : 'a t -> key:key -> data:'a -> unit

  val change : 'a t -> key -> f:('a option -> 'a option) -> unit

  val update : 'a t -> key -> f:('a option -> 'a) -> unit
end

module Wrap_singleton_table
    (Tbl : Hashtbl_intf.S)
    (Metric_info : Metric_info_intf) :
  Hashtbl_limited_intf with type key = Tbl.key and type 'a _real = 'a Tbl.t =
(* we explicitly avoid an equality on the original hashtable type
     * so that the new interface MUST be used to ensure consistency of
     * reported metrics *)
struct
  include Tbl

  type 'a _real = 'a t

  let cast x = x

  let lock = ref false

  let gauge = Gauge.v Metric_info.name ~help:Metric_info.help

  let wrap_create ~f =
    assert (not !lock) ;
    let tbl = f () in
    lock := true ;
    Gc.Expert.add_finalizer_exn tbl (fun _ ->
        Gauge.set gauge 0. ;
        lock := false ) ;
    tbl

  let create () = wrap_create ~f:Tbl.create

  let of_alist_exn ls =
    let tbl = wrap_create ~f:(fun () -> Tbl.of_alist_exn ls) in
    Gauge.set gauge (Int.to_float @@ List.length ls) ;
    tbl

  let remove t k =
    (* assuming Tbl.remove cannot throw an exn *)
    if Tbl.mem t k then Gauge.dec_one gauge ;
    Tbl.remove t k

  let add t ~key ~data =
    let res = Tbl.add t ~key ~data in
    if res = `Ok then Gauge.inc_one gauge ;
    res

  let add_exn t ~key ~data =
    try Tbl.add_exn t ~key ~data ; Gauge.inc_one gauge with exn -> raise exn

  let set t ~key ~data =
    (* assuming Tbl.set cannot throw an exn *)
    if not @@ Tbl.mem t key then Gauge.inc_one gauge ;
    Tbl.set t ~key ~data

  let change t key ~f =
    Tbl.change t key ~f:(fun x ->
        match (x, f x) with
        | Some _, Some y ->
            Some y
        | None, None ->
            None
        | None, Some y ->
            Gauge.inc_one gauge ; Some y
        | Some _, None ->
            Gauge.dec_one gauge ; None )

  let update t key ~f =
    Tbl.update t key ~f:(fun x ->
        let y = f x in
        if x = None then Gauge.inc_one gauge ;
        y )
end
