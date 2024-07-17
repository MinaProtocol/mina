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

  let log_db db =
    `List (List.map (fun (k, v) -> `List [ log_bs k; log_bs v ]) db)

  type t = L.t * R.t [@@deriving sexp]

  module Maps = Map.Make (Core_kernel.Bigstring)

  let validate_no_dups_lmdb (l : L.t) (label : string) =
    Lmdb.Cursor.go Ro l.lmdb Lmdb.Cursor.(fun cursor ->
        match first cursor with
          | exception Not_found [@alert "-deprecated"] -> ()
          | (k_first,_) ->
            [%log info] "First key $key" ~metadata:[("key",log_bs k_first)];
            let rec check_dups k m = (
              let m' = (match Maps.find k m with
                | exception Not_found -> Maps.add k 1 m
                | n -> [%log info] "duplicate found"; Maps.add k (n+1) m
              ) in
              match fst @@ next cursor with
                | exception Not_found [@alert "-deprecated"] -> [%log info] "No dups in lmdb"
                | k_next ->
                  if k = k_next then ([%log fatal] "Found a duplicate $label"
                    ~metadata:[("label",`String label)]; exit 1
                  );
              if k_next < k then ([%log info] "Key DECREASED $key" ~metadata:[("key",log_bs k_next)]);
              if k_next > k then ([%log info] "Key increased $key" ~metadata:[("key",log_bs k_next)]);
              if k_next = k_first then ([%log fatal] "Key looped to first";exit 1);
                  check_dups k_next m')
            in check_dups k_first Maps.empty

      )

  let validate ((l, r) : t) (label : string) =
    L.foldi l ~init:() ~f:(fun _ _ ~key ~data ->
        match R.get r ~key with
        | None ->
            [%log fatal] "Missing entry in rocksdb" ;
            exit 1
        | Some r_data ->
            if r_data <> data then (
              [%log fatal] "validate_l $label , $key $ldata $rdata"
                ~metadata:
                  [ ("label", `String label)
                  ; ("key", log_bs key)
                  ; ("ldata", log_bs data)
                  ; ("rdata", log_bs r_data)
                  ] ;
              exit 1 ) ) ;
    List.iter (fun (key,data) ->
        if L.get l ~key <> Some data then (
          [%log fatal] "validate_r $label"
            ~metadata:[ ("label", `String label) ] ;
        exit 1 ))
        (R.to_alist r);
    validate_no_dups_lmdb l label;
    let l_len : int = L.foldi l ~init:0 ~f:(fun _ i ~key:_ ~data:_ -> i+1) in
    let r_len_alt = List.length (R.to_alist r) in
    R.foldi r ~init:() ~f:(fun _ _ ~key:_ ~data:_ -> [%log fatal] "foldi works";exit 1);
    R.fold_until r ~init:() ~f:(fun _ ~key:_ ~data:_ -> [%log fatal] "fold_until works";exit 1) ~finish:(fun () -> ());
    if r_len_alt > 0 then [%log info] "both folds ignored all the data";
    if l_len <> r_len_alt then ([%log fatal] "database sizes differ $l $r"
        ~metadata:[("l",`Int l_len);("r",`Int r_len_alt)]
        ; exit 1)


      (*
  let validate_1 ((l, r) : t) (label : string) =
    let label () =
      [%log fatal] "Validation failure in $label"
        ~metadata:[ ("label", `String label) ]
    in
    Lmdb.Cursor.go Ro l.lmdb (fun cursor ->
        R.fold_until r
          ~init:
            ( try Some (Lmdb.Cursor.first cursor)
              with (Not_found [@alert "-deprecated"]) -> None)
          ~f:(fun lmdb_state ~key ~data ->
            let key', data' =
              match lmdb_state with
              | Some (key', data') ->
                  (key', data')
              | None ->
                  label () ;
                  [%log fatal] "Validation error LMDB missing data" ;
                  exit 1
            in
            if key <> key' || data <> data' then (
              label () ;
              [%log fatal] "Validation error with lmdb $lk $lv rocksdb $rk $rv"
                ~metadata:
                  [ ("lk", log_bs key')
                  ; ("lv", log_bs data')
                  ; ("rk", log_bs key)
                  ; ("rv", log_bs data)
                  ] ;
              exit 1 ) ;
            try Continue (Some (Lmdb.Cursor.next cursor))
            with (Not_found [@alert "-deprecated"]) -> Continue None )
          ~finish:(fun lmdb_state ->
            match lmdb_state with
            | None ->
                ()
            | Some (key , data) ->
                label () ;
                let rd = R.get r ~key in
                [%log fatal] "Validation error LMDB had extra data $key $data , $rd"
              ~metadata:[("key",log_bs key);("data",log_bs data);("rd",log_opt_bs rd)];
                exit 1 ) )
  *)

  let create conf =
    let l = L.create conf in
    let r = R.create conf in
    validate (l, r) "creation" ;
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
      List.iter
        (fun (key, (lv, rv)) ->
          match (lv, rv) with
          | None, None ->
              ()
          | Some _, None ->
              [%log fatal] "Rocksdb missing entry at $key"
                ~metadata:[ ("key", log_bs key) ]
          | None, Some _ ->
              [%log fatal] "LMDB missing entry at $key"
                ~metadata:[ ("key", log_bs key) ]
          | Some l, Some r ->
              if l <> r then
                [%log fatal] "Discrepency at $key of $l vs $r"
                  ~metadata:
                    [ ("key", log_bs key); ("l", log_bs l); ("r", log_bs r) ] )
        (List.combine keys (List.combine lvs rvs)) ;
      failwith "get_batch failed" )

  let set (l, r) ~key ~data =
    [%log info] "calling set $key $data"
      ~metadata:[ ("key", log_bs key); ("data", log_bs data) ] ;
    L.set l ~key ~data ;
    R.set r ~key ~data

  let set_batch (l, r) ?remove_keys ~key_data_pairs =
    [%log info] "calling set_batch" ;
    validate (l, r) "pre_set_batch" ;
    L.set_batch l ?remove_keys ~key_data_pairs ;
    R.set_batch r ?remove_keys ~key_data_pairs ;
    [%log info] "adding data $db" ~metadata:[ ("db", log_db key_data_pairs) ] ;
    validate (l, r) "set_batch"
  (* validate (l, r) "set_batch" *)

  let to_alist (l, r) =
    let lv = L.to_alist l in
    let rv = R.to_alist r in
    if lv = rv then lv else failwith "to_alist"

  let remove (l, r) ~key = L.remove l ~key ; R.remove r ~key

  let create_checkpoint (l, r) name =
    let lr = L.create_checkpoint l name in
    let rr = R.create_checkpoint r name in
    validate (lr, rr) "checkpoint" ;
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
