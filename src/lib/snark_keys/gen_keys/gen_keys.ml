[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

module Blockchain_snark_keys = struct
  module Proving = struct
    let key_location ~loc bc_location =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      estring
        (Blockchain_snark.Blockchain_transition.Keys.Proving.Location.to_string
           bc_location)

    let load_expr ~loc bc_location bc_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Blockchain_snark.Blockchain_transition.Keys.Proving.load
          (Blockchain_snark.Blockchain_transition.Keys.Proving.Location
           .of_string
             [%e key_location ~loc bc_location])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex bc_checksum)] ) ;
        keys]
  end

  module Verification = struct
    let key_location ~loc bc_location =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      estring
        (Blockchain_snark.Blockchain_transition.Keys.Verification.Location
         .to_string bc_location)

    let load_expr ~loc bc_location bc_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Blockchain_snark.Blockchain_transition.Keys.Verification.load
          (Blockchain_snark.Blockchain_transition.Keys.Verification.Location
           .of_string
             [%e key_location ~loc bc_location])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex bc_checksum)] ) ;
        keys]
  end
end

module Transaction_snark_keys = struct
  module Proving = struct
    let key_location ~loc t_location =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      estring (Transaction_snark.Keys.Proving.Location.to_string t_location)

    let load_expr ~loc t_location t_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Transaction_snark.Keys.Proving.load
          (Transaction_snark.Keys.Proving.Location.of_string
             [%e key_location ~loc t_location])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex t_checksum)] ) ;
        keys]
  end

  module Verification = struct
    let key_location ~loc t_location =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      estring
        (Transaction_snark.Keys.Verification.Location.to_string t_location)

    let load_expr ~loc t_location t_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Transaction_snark.Keys.Verification.load
          (Transaction_snark.Keys.Verification.Location.of_string
             [%e key_location ~loc t_location])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex t_checksum)] ) ;
        keys]
  end
end

let ok_or_fail_expr ~loc =
  [%expr function Ok x -> x | Error _ -> failwith "Gen_keys error"]

module Dummy = struct
  module Transaction_keys = struct
    module Proving = struct
      let expr ~loc = [%expr Async.return Transaction_snark.Keys.Proving.dummy]
    end

    module Verification = struct
      let expr ~loc =
        [%expr Async.return Transaction_snark.Keys.Verification.dummy]
    end
  end

  module Blockchain_keys = struct
    module Proving = struct
      let expr ~loc =
        [%expr
          Async.return
            Blockchain_snark.Blockchain_transition.Keys.Proving.dummy]
    end

    module Verification = struct
      let expr ~loc =
        [%expr
          Async.return
            Blockchain_snark.Blockchain_transition.Keys.Verification.dummy]
    end
  end
end

open Async

let loc = Ppxlib.Location.none

[%%if
proof_level = "full"]

let location_expr key_location =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%expr
    let open Async.Deferred in
    Transaction_snark.Keys.Verification.load
      (Transaction_snark.Keys.Verification.Location.of_string
         [%e
           estring
             (Transaction_snark.Keys.Verification.Location.to_string
                key_location)])]

let gen_keys () =
  let open Async_kernel in
  let%bind {Cached.With_track_generated.data= acc; dirty} =
    let open Cached.Deferred_with_track_generated.Let_syntax in
    let%bind tx_keys_location, tx_keys, tx_keys_checksum =
      Transaction_snark.Keys.cached ()
    in
    let module M =
    (* TODO make toplevel library to encapsulate consensus params *)
    Blockchain_snark.Blockchain_transition.Make (Transaction_snark.Verification
                                                 .Make
                                                   (struct
      let keys = tx_keys
    end)) in
    let%map bc_keys_location, _bc_keys, bc_keys_checksum = M.Keys.cached () in
    ( Blockchain_snark_keys.Proving.load_expr ~loc bc_keys_location.proving
        bc_keys_checksum.proving
    , Blockchain_snark_keys.Proving.key_location ~loc bc_keys_location.proving
    , Blockchain_snark_keys.Verification.load_expr ~loc
        bc_keys_location.verification bc_keys_checksum.verification
    , Blockchain_snark_keys.Verification.key_location ~loc
        bc_keys_location.verification
    , Transaction_snark_keys.Proving.load_expr ~loc tx_keys_location.proving
        tx_keys_checksum.proving
    , Transaction_snark_keys.Proving.key_location ~loc tx_keys_location.proving
    , Transaction_snark_keys.Verification.load_expr ~loc
        tx_keys_location.verification tx_keys_checksum.verification
    , Transaction_snark_keys.Verification.key_location ~loc
        tx_keys_location.verification )
  in
  if Array.mem ~equal:String.equal Sys.argv "--generate-keys-only" then
    Stdlib.exit 0 ;
  match dirty with
  | `Generated_something | `Locally_generated -> (
    (* If we generated any keys, then we need to make sure to upload these keys
     * to some central store to keep our builds compatible with one-another.
     *
     * We used to have a process where we manually upload keys whenever we want
     * to persist a new change. This is an attempt to make that process
     * automatic.
     *
     * We don't want to force an upload on every change as during development
     * you could churn on changes. Instead, we force uploads on CI jobs that
     * build testnet artifacts (as these are the binaries we want to make sure
     * we can retrieve keys for).
     * Uploads occur out-of-process in CI.
     *
     * See the background section of https://bkase.dev/posts/ocaml-writer
     * for more info on how this system works.
     *
     * NOTE: This behaviour is overriden or external contributors, because they
     * cannot upload new keys if they have modified the snark. See branch
     * referencing "CIRCLE_PR_USERNAME" below.
     *)
    match (Sys.getenv "CI", Sys.getenv "DUNE_PROFILE") with
    | Some _, Some profile
      when Option.is_some (Sys.get_env "CIRCLE_PR_USERNAME") ->
        (* External contributors cannot upload new keys to AWS, but we would
           still like to run CI for their pull requests if they have modified the
           snark.
        *)
        ( match dirty with
        | `Generated_something ->
            Format.eprintf
              "No keys were found in the cache, but this pull-request is from \
               an external contributor.@ Generated fresh keys for this \
               build.@."
        | `Locally_generated ->
            Format.eprintf
              "Only locally-generated keys were found in the cache, but this \
               pull-request is from an external contributor.@ Using the local \
               keys@."
        | `Cache_hit ->
            (* Excluded above. *) assert false ) ;
        return acc
    | Some _, Some profile
      when String.is_substring ~substring:"testnet" profile ->
        (* We are intentionally aborting the build here with a special error code
        * because we do not want builds to succeed if keys are not uploaded.
        *
        * Exit code is 0xc1 for "CI" *)
        exit 0xc1
    | Some _, Some _ | _, None | None, _ ->
        return acc )
  | `Cache_hit ->
      return acc

[%%else]

let gen_keys () =
  let dummy_loc = [%expr "dummy-location"] in
  return
    ( Dummy.Blockchain_keys.Proving.expr ~loc
    , dummy_loc
    , Dummy.Blockchain_keys.Verification.expr ~loc
    , dummy_loc
    , Dummy.Transaction_keys.Proving.expr ~loc
    , dummy_loc
    , Dummy.Transaction_keys.Verification.expr ~loc
    , dummy_loc )

[%%endif]

let main () =
  (*   let%bind blockchain_expr, transaction_expr = *)
  let%bind ( bc_proving
           , bc_proving_loc
           , bc_verification
           , bc_verification_loc
           , tx_proving
           , tx_proving_loc
           , tx_verification
           , tx_verification_loc ) =
    gen_keys ()
  in
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "snark_keys.ml")
  in
  Pprintast.top_phrase fmt
    (Ptop_def
       [%str
         open Core_kernel

         let blockchain_proving () = [%e bc_proving]

         let blockchain_verification () = [%e bc_verification]

         let transaction_proving () = [%e tx_proving]

         let transaction_verification () = [%e tx_verification]

         type key_hashes = string list [@@deriving to_yojson]

         let key_locations =
           [ ("blockchain_proving", [%e bc_proving_loc])
           ; ("blockchain_verification", [%e bc_verification_loc])
           ; ("transaction_proving", [%e tx_proving_loc])
           ; ("transaction_verification", [%e tx_verification_loc]) ]

         let rec location_sexp_to_hashes = function
           | Sexp.Atom s
             when List.mem
                    ["base"; "merge"; "step"; "wrap"]
                    s ~equal:String.equal ->
               []
           | Sexp.Atom s -> (
               let fn = Filename.basename s in
               match String.split fn ~on:'_' with
               | hash :: _ ->
                   [hash]
               | _ ->
                   failwith "location_sexp_to_hashes: unexpected filename" )
           | Sexp.List sexps ->
               List.(concat (map sexps ~f:location_sexp_to_hashes))

         let location_to_hashes (loc : string) =
           match Sexp.parse loc with
           | Done (sexp, _) ->
               location_sexp_to_hashes sexp
           | _ ->
               []

         let key_hashes =
           let locations =
             List.map key_locations ~f:(fun (_name, loc) -> loc)
           in
           let hashes = List.(concat (map locations ~f:location_to_hashes)) in
           List.dedup_and_sort hashes ~compare:String.compare]) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
