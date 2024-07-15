(* named L and R here cause this should probably be a functor *)
module L = Lmdb_kvdb.Kvdb
module R = Rocksdb.Database

module Db : Merkle_ledger.Intf.Key_value_database with type config := string =
struct
  let logger = Logger.create ()

  let log_bs bs = `String (Core_kernel.Bigstring.to_string bs)

  let log_opt_bs optbs =
    `String
      (Option.fold ~none:"None" ~some:Core_kernel.Bigstring.to_string optbs)
  (*
  let log_db db =`List (List.map (fun (k,v) -> `List [log_bs k;log_bs v]) db)
    *)

  type t = L.t * R.t [@@deriving sexp]

  let create conf =
    [%log info] "creating l" ;
    let l = L.create conf in
    [%log info] "creating r" ;
    let r = R.create conf in
    [%log info] "creating done" ;
    (l, r)
  (* this check isn't really practical
     let ll = L.to_alist l in
     let rl = R.to_alist r in
     if  ll = rl
       then ([%log info] "passed eq check"; (l,r))
       else ( [%log fatal] "Create discrepency lengths"; exit 1)
  *)

  let close (l, r) = L.close l ; R.close r

  let get (l, r) ~key =
    let lv = L.get l ~key in
    let rv = R.get r ~key in
    if lv = rv then lv
    else (
      [%log fatal] "bad get $lv $rv"
        ~metadata:[ ("lv", log_opt_bs lv); ("rv", log_opt_bs rv) ] ;
      exit 1 )

  let get_batch (l, r) ~keys =
    let lvs = L.get_batch l ~keys in
    let rvs = R.get_batch r ~keys in
    if lvs = rvs then lvs
    else (
      (List.iter
        (fun (key,(lv,rv)) ->
          match lv,rv with
            | None,None -> ()
            | Some(_),None -> [%log fatal] "Rocksdb missing entry at $key"
              ~metadata:[("key",log_bs key)];
            | None,Some(_) -> [%log fatal] "LMDB missing entry at $key"
              ~metadata:[("key",log_bs key)];
            | Some(l),Some(r) ->
              (if l != r then [%log fatal] "Discrepency at $key of $l vs $r"
              ~metadata:
              [("key",log_bs key)
              ;("l",log_bs l)
              ;("r",log_bs r)
              ];)
        )
        (List.combine keys (List.combine lvs rvs))
      );
      failwith "get_batch failed" )

  let set (l, r) ~key ~data =
    [%log info] "calling set $key $data"
      ~metadata:[ ("key", log_bs key); ("data", log_bs data) ] ;
    L.set l ~key ~data ;
    R.set r ~key ~data

  let set_batch (l, r) ?remove_keys ~key_data_pairs =
    [%log info] "calling set_batch" ;
    L.set_batch l ?remove_keys ~key_data_pairs ;
    R.set_batch r ?remove_keys ~key_data_pairs;
    match remove_keys with
      | None -> ()
      | Some(keys) -> if not (L.get_batch l ~keys = R.get_batch r ~keys)
        then ([%log fatal] "set_batch broke on remove keys"; exit 1)
      ;
    let keys = List.map fst key_data_pairs in
    if not (L.get_batch l ~keys = R.get_batch r ~keys)
      then ([%log fatal] "set_batch broke on key_data_pairs"; exit 1)

  let to_alist (l, r) =
    let lv = L.to_alist l in
    let rv = R.to_alist r in
    if lv = rv then lv else failwith "to_alist"

  let remove (l, r) ~key = L.remove l ~key ; R.remove r ~key

  let create_checkpoint (l, r) name =
    let lr = L.create_checkpoint l name in
    let rr = R.create_checkpoint r name in
    (lr, rr)

  let make_checkpoint (l, r) name =
    L.make_checkpoint l name ; R.make_checkpoint r name

  let foldi (l, r) ~init ~f =
    let lv = L.foldi l ~init ~f in
    let rv = R.foldi r ~init ~f in
    if lv = rv then lv else failwith "foldi"

  let fold_until (l, r) ~init ~f ~finish =
    let lv = L.fold_until l ~init ~f ~finish in
    let rv = R.fold_until r ~init ~f ~finish in
    if lv = rv then lv else failwith "fold_until"

  (* Some are les easy to test *)

  let get_uuid (_l, r) = R.get_uuid r
end
