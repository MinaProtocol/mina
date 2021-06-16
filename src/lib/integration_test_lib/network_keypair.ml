open Signature_lib
open Core

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { keypair: Keypair.Stable.V1.t
      ; public_key_file: string
      ; private_key_file: string }
    [@@deriving to_yojson, bin_io, version]

    let to_latest = Fn.id
  end
end]

(* We use the same password for all the network keypairs (we don't care about
 * the security of these given this is just for tests).
 *)
let password = "naughty blue worm"

let of_keypair keypair =
  let open Keypair in
  let public_key_file =
    Public_key.Compressed.to_base58_check
      (Public_key.compress keypair.public_key)
    ^ "\n"
  in
  let private_key_file =
    let plaintext =
      Bigstring.to_bytes (Private_key.to_bigstring keypair.private_key)
    in
    Secrets.Secret_box.encrypt ~plaintext ~password:(Bytes.of_string password)
    |> Secrets.Secret_box.to_yojson |> Yojson.Safe.to_string
  in
  {keypair; public_key_file; private_key_file}

let create () = of_keypair (Keypair.create ())

module Pool = struct
  module Chunk = struct
    let max_size = 500

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Stable.V1.t list [@@deriving bin_io, version]

        let to_latest = Fn.id
      end
    end]

    let size = List.length

    let filename ~pool_filepath ~index =
      pool_filepath ^/ "keypool.chunk." ^ Int.to_string index

    let write chunk ~pool_filepath ~index =
      let data =
        let len = Stable.Latest.bin_size_t chunk in
        let buf = Bin_prot.Common.create_buf len in
        ignore (Stable.Latest.bin_write_t buf ~pos:0 chunk) ;
        Bigstring.to_string ~pos:0 ~len buf
      in
      Out_channel.write_all (filename ~pool_filepath ~index) ~data

    let extend chunk ~pool_filepath ~index ~count =
      if List.length chunk + count > max_size then
        failwith "invalid keypool chunk extension size" ;
      let chunk' = chunk @ List.init count ~f:(fun _ -> create ()) in
      write chunk' ~pool_filepath ~index ;
      chunk'

    let create ~pool_filepath ~index ~size =
      if size > max_size then failwith "invalid keypool chunk size" ;
      let chunk = List.init size ~f:(fun _ -> create ()) in
      write chunk ~pool_filepath ~index ;
      chunk

    let load ~pool_filepath ~index =
      Unix.with_file ~mode:[Unix.O_RDONLY] (filename ~pool_filepath ~index)
        ~f:(fun fd ->
          let len = Int64.to_int_exn (Unix.fstat fd).st_size in
          let buf = Bigstring.map_file ~shared:false fd len in
          Option.value_exn (Stable.bin_read_to_latest_opt buf ~pos_ref:(ref 0))
      )
  end

  (** Extends the on-disk network keypair pool by to a specified size. *)
  let extend ~logger ~pool_filepath ~chunks ~count =
    (* first, we extend any non-filled chunks *)
    let remaining_count, filled_chunks =
      List.fold_mapi chunks ~init:count ~f:(fun index count chunk ->
          if Chunk.size chunk < Chunk.max_size then (
            let space = Chunk.max_size - Chunk.size chunk in
            let amount_to_add = min space count in
            [%log spam] "Extending chunk from size $size to $new_size"
              ~metadata:
                [ ("size", `Int (Chunk.size chunk))
                ; ("new_size", `Int (Chunk.size chunk + amount_to_add)) ] ;
            let chunk' =
              Chunk.extend chunk ~count:amount_to_add ~pool_filepath ~index
            in
            (count - amount_to_add, chunk') )
          else (count, chunk) )
    in
    (* second, we generate additional chunks for any remaining keys *)
    let rec add_new_chunks remaining index =
      let chunk_size = min remaining Chunk.max_size in
      [%log spam] "Creating new chunk of size $size"
        ~metadata:[("size", `Int chunk_size)] ;
      let chunk = Chunk.create ~pool_filepath ~index ~size:chunk_size in
      let remaining' = remaining - chunk_size in
      if remaining' > 0 then chunk :: add_new_chunks remaining' (index + 1)
      else [chunk]
    in
    filled_chunks @ add_new_chunks remaining_count (List.length filled_chunks)

  (** Loads the network keypair pool from disk, returning the specified number
   *  of keypairs. If there are not enough keypairs in the pool, more will be
   *  generated and saved back to the filesystem for later re-use.
   *)
  let load ~logger ~pool_filepath ~size =
    let minimum_chunks_required =
      (size / Chunk.max_size) + if size mod Chunk.max_size > 0 then 1 else 0
    in
    Unix.mkdir_p ~perm:0o776 pool_filepath ;
    (* This does not attempt to align chunks or deal with missing chunks in the
     * sequence; I believe this is ok and won't cause any issues.
     *
     * I suppose the issue with this could be that, if we don't do this and
     * corrupt the keypool, we could end up loading duplicat keypairs, which
     * would be bad.
     *)
    let chunk_indices =
      let chunk_regexp =
        Re.(
          compile @@ whole_string
          @@ seq [str "keypool.chunk."; group (rep1 digit)])
      in
      let rec read_contents dir =
        match Unix.readdir_opt dir with
        | None ->
            []
        | Some item ->
            item :: read_contents dir
      in
      Unix.opendir pool_filepath |> read_contents
      |> List.filter_map ~f:(fun item ->
             Re.exec_opt chunk_regexp item
             |> Option.map ~f:(fun g ->
                    let index = Int.of_string (Re.Group.get g 1) in
                    index ) )
      |> List.sort ~compare:Int.compare
    in
    let chunks =
      List.take chunk_indices minimum_chunks_required
      |> List.map ~f:(fun index -> Chunk.load ~pool_filepath ~index)
    in
    let available_keypair_count =
      List.fold chunks ~init:0 ~f:(fun acc chunk -> acc + Chunk.size chunk)
    in
    let chunks' =
      if available_keypair_count < size then (
        let missing_count = size - available_keypair_count in
        [%log info]
          "Not enough keypairs in keypool (available keys = \
           $available_count); generating $missing_count keypairs"
          ~metadata:
            [ ("available_count", `Int available_keypair_count)
            ; ("missing_count", `Int missing_count) ] ;
        extend ~logger ~pool_filepath ~chunks ~count:missing_count )
      else chunks
    in
    let keypairs = List.concat (List.take chunks' minimum_chunks_required) in
    List.take keypairs size
end
