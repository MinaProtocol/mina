open Core
open Async

(* Bumped whenever the layout below changes, so that a daemon refuses to read a
   blob it does not understand instead of deserialising garbage. *)
let magic = "MINAVK\001"

type t =
  { constraint_constants : Genesis_constants.Constraint_constants.t
  ; signature_kind : Mina_signature_kind.t
  ; blockchain : Pickles.Verification_key.Stable.Latest.t
  ; transaction : Pickles.Verification_key.Stable.Latest.t
  }
[@@deriving bin_io_unversioned]

type keys =
  { blockchain : Pickles.Verification_key.t
  ; transaction : Pickles.Verification_key.t
  }

let serialize t =
  magic
  ^ Bigstring.to_string (Bin_prot.Utils.bin_dump ~header:true bin_writer_t t)

let deserialize s =
  if not (String.is_prefix s ~prefix:magic) then
    Or_error.error_string
      "verification keys do not start with the expected header; they were \
       written by an incompatible version of mina"
  else
    Or_error.try_with (fun () ->
        let buf =
          Bigstring.of_string (String.drop_prefix s (String.length magic))
        in
        let pos_ref = ref 0 in
        let (_ : int) = Bin_prot.Utils.bin_read_size_header buf ~pos_ref in
        bin_read_t buf ~pos_ref )

(* Applies the two SNARK functors, which is what makes this expensive: it peaks
   at ~2.6GB of resident memory for ~30s. The compaction afterwards is load
   bearing. The circuits do become unreachable when this returns, but without an
   explicit compaction the runtime keeps the pages and the daemon carries them
   for the rest of its life. *)
let compute ~signature_kind ~constraint_constants ~proof_level =
  let%map `Blockchain blockchain, `Transaction transaction =
    Verifier.get_verification_keys_eagerly ~signature_kind ~constraint_constants
      ~proof_level
  in
  Gc.compact () ;
  { blockchain; transaction }

(* A verification key is determined by the constraint constants, the signature
   kind and the proof level, so a file that disagrees about any of them holds
   the wrong key, and a node using it would reject every block. What to do about
   that depends on where the file came from; see [load]. *)
let of_file ~signature_kind ~constraint_constants path =
  let open Or_error.Let_syntax in
  let mismatch what ~file ~node =
    Or_error.errorf
      "verification keys in %s were generated for a different %s than this \
       node is running with: file has %s, node has %s"
      path what file node
  in
  let%bind t = deserialize (In_channel.read_all path) in
  let%bind () =
    if
      Genesis_constants.Constraint_constants.equal t.constraint_constants
        constraint_constants
    then Ok ()
    else
      let to_string cc =
        Genesis_constants.Constraint_constants.to_yojson cc
        |> Yojson.Safe.to_string
      in
      mismatch "set of constraint constants"
        ~file:(to_string t.constraint_constants)
        ~node:(to_string constraint_constants)
  in
  let%map () =
    if Mina_signature_kind.equal t.signature_kind signature_kind then Ok ()
    else
      let to_string sk =
        Mina_signature_kind.to_yojson sk |> Yojson.Safe.to_string
      in
      mismatch "signature kind"
        ~file:(to_string t.signature_kind)
        ~node:(to_string signature_kind)
  in
  { blockchain = t.blockchain; transaction = t.transaction }

let compute_and_save ~signature_kind ~constraint_constants ~proof_level path =
  let%map { blockchain; transaction } =
    compute ~signature_kind ~constraint_constants ~proof_level
  in
  Out_channel.write_all path
    ~data:
      (serialize
         { constraint_constants; signature_kind; blockchain; transaction } )

(* Where a package installs the keys: under the compiled profile, named after
   the runtime config they were generated from, [config_<commit>.json], which is
   the config a packaged daemon picks up on its own. Both parts are needed: one
   commit is built under several profiles, and mesa and devnet share a profile
   but not a config. The network name would not do, since a daemon does not know
   it.

   They get their own directory because [Cache_dir.manual_install_path] is also
   one of the places the Pickles key cache looks, and these are not cache
   entries, deliberately:
   - The cache is addressed by constraint system digest, and without shipping
     those digests too, finding the digest means building the constraint
     system, which is the compile this file exists to avoid.
   - A cache miss falls through to generating the proving key, silently; a
     missing or stale file here is logged, and refused when named on the
     command line.
   - The cache is filled by a prover having run, and the nodes this serves run
     no prover. *)
let default_path =
  Cache_dir.manual_install_path ^/ "verification_keys" ^/ Node_config.profile
  ^/ sprintf "config_%s.bin" Mina_version.commit_id_short

(* Which keys to use, or [None] when they have to be computed. Kept separate
   from [load] so that the choice can be tested without paying for a compute. *)
let choose ~logger ~path:override_path ~default_path ~signature_kind
    ~constraint_constants ~proof_level =
  let read path = of_file ~signature_kind ~constraint_constants path in
  match (proof_level : Genesis_constants.Proof_level.t) with
  | Check | No_check ->
      (* These levels never verify a real proof, so the keys are unused and
         computing them would cost 30s and 2.6GB for nothing. This is the same
         key the prover subprocess returned at these levels. *)
      let dummy = Lazy.force Pickles.Verification_key.dummy in
      Some { blockchain = dummy; transaction = dummy }
  | Full -> (
      match override_path with
      (* An operator who names a file is claiming it belongs to this node, so a
         file that is missing or does not fit is a mistake to report rather than
         something to quietly work around. *)
      | Some path -> (
          [%log info] "Reading verification keys from $path"
            ~metadata:[ ("path", `String path) ] ;
          match read path with
          | Ok keys ->
              Some keys
          | Error err ->
              Mina_stdlib.Mina_user_error.raise
                ~where:"reading its verification keys" (Error.to_string_hum err)
          )
      | None -> (
          match Sys_unix.file_exists default_path with
          | `No | `Unknown ->
              [%log info]
                "No verification keys found at $path, computing them instead. \
                 This takes around 30 seconds and several gigabytes of memory."
                ~metadata:[ ("path", `String default_path) ] ;
              None
          | `Yes -> (
              match read default_path with
              | Ok keys ->
                  [%log info] "Read verification keys from $path"
                    ~metadata:[ ("path", `String default_path) ] ;
                  Some keys
              | Error err ->
                  (* The installed keys describe the config this package ships,
                     and this node is running a different one -- an override of
                     a proof constant, or a config from somewhere else. That is
                     a fair thing to do, so compute the right keys rather than
                     refuse to start on keys that merely happen to be
                     installed. *)
                  [%log warn]
                    "Ignoring the verification keys at $path and computing \
                     them instead, which takes around 30 seconds and several \
                     gigabytes of memory: $error"
                    ~metadata:
                      [ ("path", `String default_path)
                      ; ("error", Error_json.error_to_yojson err)
                      ] ;
                  None ) ) )

let load ~logger ?(default_path = default_path) ~path ~signature_kind
    ~constraint_constants ~proof_level () =
  match
    choose ~logger ~path ~default_path ~signature_kind ~constraint_constants
      ~proof_level
  with
  | Some keys ->
      Deferred.return keys
  | None ->
      compute ~signature_kind ~constraint_constants ~proof_level

let%test_module "verification key files" =
  ( module struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let signature_kind = Mina_signature_kind.Testnet

    (* The keys themselves are opaque to everything here, so a dummy pair
       exercises the same paths without compiling a circuit. *)
    let sample =
      let dummy = Lazy.force Pickles.Verification_key.dummy in
      { constraint_constants
      ; signature_kind
      ; blockchain = dummy
      ; transaction = dummy
      }

    let write t =
      let path = Filename_unix.temp_file "verification_keys" ".bin" in
      Out_channel.write_all path ~data:(serialize t) ;
      path

    let%test_unit "a written file reads back as the keys that went into it" =
      let path = write sample in
      let { blockchain; transaction } =
        of_file ~signature_kind ~constraint_constants path |> Or_error.ok_exn
      in
      Sys_unix.remove path ;
      [%test_eq: string]
        (Pickles.Verification_key.to_yojson blockchain |> Yojson.Safe.to_string)
        ( Pickles.Verification_key.to_yojson sample.blockchain
        |> Yojson.Safe.to_string ) ;
      [%test_eq: string]
        (Pickles.Verification_key.to_yojson transaction |> Yojson.Safe.to_string)
        ( Pickles.Verification_key.to_yojson sample.transaction
        |> Yojson.Safe.to_string )

    let%test "keys for other constraint constants are rejected" =
      let path =
        write
          { sample with
            constraint_constants =
              { constraint_constants with
                ledger_depth = constraint_constants.ledger_depth + 1
              }
          }
      in
      let result = of_file ~signature_kind ~constraint_constants path in
      Sys_unix.remove path ; Or_error.is_error result

    let%test "keys for another signature kind are rejected" =
      let path =
        write { sample with signature_kind = Mina_signature_kind.Mainnet }
      in
      let result = of_file ~signature_kind ~constraint_constants path in
      Sys_unix.remove path ; Or_error.is_error result

    let choose ?path ~default_path () =
      choose ~logger:(Logger.null ()) ~path ~default_path ~signature_kind
        ~constraint_constants ~proof_level:Genesis_constants.Proof_level.Full

    let%test "installed keys that fit are used" =
      let path = write sample in
      let chosen = choose ~default_path:path () in
      Sys_unix.remove path ; Option.is_some chosen

    let%test "installed keys that do not fit are computed instead" =
      (* An operator may legitimately override a proof constant, which changes
         the keys. That must still start, not refuse to. *)
      let path =
        write { sample with signature_kind = Mina_signature_kind.Mainnet }
      in
      let chosen = choose ~default_path:path () in
      Sys_unix.remove path ; Option.is_none chosen

    let%test "no installed keys means computing them" =
      Option.is_none
        (choose ~default_path:"/nonexistent/verification_keys.bin" ())

    let%test "a named file that does not fit is refused" =
      let path =
        write { sample with signature_kind = Mina_signature_kind.Mainnet }
      in
      let refused =
        match choose ~path ~default_path:"/nonexistent" () with
        | (_ : keys option) ->
            false
        | exception Mina_stdlib.Mina_user_error.Mina_user_error _ ->
            true
      in
      Sys_unix.remove path ; refused

    let%test "a named file that is missing is refused" =
      match
        choose ~path:"/nonexistent/verification_keys.bin"
          ~default_path:"/nonexistent" ()
      with
      | (_ : keys option) ->
          false
      | exception _ ->
          true

    let%test "a file without the header is rejected rather than misread" =
      let path = Filename_unix.temp_file "verification_keys" ".bin" in
      Out_channel.write_all path
        ~data:(String.drop_prefix (serialize sample) (String.length magic)) ;
      let result = of_file ~signature_kind ~constraint_constants path in
      Sys_unix.remove path ; Or_error.is_error result
  end )
