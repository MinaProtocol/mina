open Core_kernel
open Mina_base
open Mina_transaction

type key = Transaction_hash.User_command_with_valid_signature.t

type value = Time.t * [ `Batch of int ]

type t =
  (Time.t * [ `Batch of int ] * User_command.Valid.t) Transaction_hash.Map.t ref

let find_and_remove (t : t) cmd =
  let hash =
    Transaction_hash.User_command_with_valid_signature.transaction_hash cmd
  in
  let%map.Option time, batch, _ = Transaction_hash.Map.find !t hash in
  t := Transaction_hash.Map.remove !t hash ;
  (time, batch)

let add_exn (t : t) ~key:cmd ~data:(time, batch) =
  let hash =
    Transaction_hash.User_command_with_valid_signature.transaction_hash cmd
  in
  let cmd_ = Transaction_hash.User_command_with_valid_signature.data cmd in
  t := Transaction_hash.Map.add_exn !t ~key:hash ~data:(time, batch, cmd_)

let mem (t : t) cmd =
  let hash =
    Transaction_hash.User_command_with_valid_signature.transaction_hash cmd
  in
  Transaction_hash.Map.mem !t hash

let create () = ref Transaction_hash.Map.empty

let update (t : t) cmd
    ~(f : (Time.t * [ `Batch of int ]) option -> Time.t * [ `Batch of int ]) =
  let hash =
    Transaction_hash.User_command_with_valid_signature.transaction_hash cmd
  in
  let cmd_ = Transaction_hash.User_command_with_valid_signature.data cmd in
  t :=
    Transaction_hash.Map.update !t hash ~f:(fun found ->
        let found' = Option.map ~f:(fun (t, b, _) -> (t, b)) found in
        let t', b' = f found' in
        (t', b', cmd_) )

let filteri_inplace (t : t) ~f =
  t :=
    Transaction_hash.Map.filteri !t ~f:(fun ~key ~data:(time, batch, cmd) ->
        f
          ~key:(Transaction_hash.User_command_with_valid_signature.make cmd key)
          ~data:(time, batch) )

let to_alist (t : t) =
  Transaction_hash.Map.to_alist !t
  |> List.map ~f:(fun (hash, (time, batch, cmd)) ->
         ( Transaction_hash.User_command_with_valid_signature.make cmd hash
         , (time, batch) ) )

let iter_intersection (a : t) (b : t) ~f =
  Transaction_hash.Map.iteri !a ~f:(fun ~key ~data:(time1, batch1, cmd) ->
      Transaction_hash.Map.find !b key
      |> Option.iter ~f:(fun (time2, batch2, _) ->
             f
               ~key:
                 (Transaction_hash.User_command_with_valid_signature.make cmd
                    key )
               (time1, batch1) (time2, batch2) ) )

let iteri (t : t) ~f =
  Transaction_hash.Map.iteri !t ~f:(fun ~key ~data:(time, batch, cmd) ->
      f
        ~key:(Transaction_hash.User_command_with_valid_signature.make cmd key)
        ~data:(time, batch) )
