open Core_kernel

module type Inputs_intf = sig
  open Intf

  val name : string

  val public_inputs : Unsigned.Size_t.t Lazy.t

  val size : Unsigned.Size_t.t Lazy.t

  module Rounds : Pickles_types.Nat.Intf

  module Urs : sig
    type t

    val read : string -> t

    val write : t -> string -> unit

    val create :
      Unsigned.Size_t.t -> Unsigned.Size_t.t -> Unsigned.Size_t.t -> t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let name =
    sprintf "%s_%d_%s_v2" name
      (Pickles_types.Nat.to_int Rounds.n)
      Version.marlin_repo_sha

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let degree = 1 lsl Pickles_types.Nat.to_int Rounds.n in
    let public_inputs = Inputs.public_inputs in
    let size = Inputs.size in
    let set_urs_info specs =
      Set_once.set_exn urs_info Lexing.dummy_pos specs
    in
    let load () =
      match !urs with
      | Some urs ->
          urs
      | None ->
          let specs =
            match Set_once.get urs_info with
            | None ->
                failwith "Dlog_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Sync.Disk_storable.simple
              (fun () -> name)
              (fun () ~path -> Urs.read path)
              Urs.write
          in
          let u =
            match Key_cache.Sync.read specs store () with
            | Ok (u, _) ->
                u
            | Error _e ->
                let urs =
                  Urs.create
                    (Unsigned.Size_t.of_int degree)
                    (Lazy.force public_inputs) (Lazy.force size)
                in
                let _ =
                  Key_cache.Sync.write
                    (List.filter specs ~f:(function
                      | On_disk _ ->
                          true
                      | S3 _ ->
                          false ))
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)
end
