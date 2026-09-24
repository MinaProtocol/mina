(* Wall-clock and peak-RSS harness for pickles proving.

   Reports key generation and proving separately, and resets the kernel's
   peak-RSS watermark (/proc/self/clear_refs) before each proof so the
   proving figure is not masked by the larger key-generation footprint.

   Usage: bench_ipa.exe [rows_log2] [iterations] *)

open Core
open Pickles_types
open Pickles.Impls.Step

let vm_hwm_kb () =
  In_channel.read_lines "/proc/self/status"
  |> List.find_map ~f:(fun line ->
         match String.chop_prefix line ~prefix:"VmHWM:" with
         | None ->
             None
         | Some rest ->
             String.split_on_chars rest ~on:[ ' '; '\t' ]
             |> List.filter ~f:(fun s -> not (String.is_empty s))
             |> List.hd
             |> Option.map ~f:Int.of_string )
  |> Option.value ~default:0

let reset_peak_rss () =
  try Out_channel.write_all "/proc/self/clear_refs" ~data:"5" with _ -> ()

let time_it name f =
  let t0 = Caml_unix.gettimeofday () in
  let r = f () in
  let dt = Caml_unix.gettimeofday () -. t0 in
  printf "%s\ttime_s=%.3f\tpeak_rss_MiB=%.1f\n%!" name dt
    (Float.of_int (vm_hwm_kb ()) /. 1024.) ;
  r

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let argv = Stdlib.Sys.argv

let arg i default =
  if Array.length argv > i then Int.of_string argv.(i) else default

let rows_log2 = arg 1 15

let iterations = arg 2 3

module Requests = struct
  type _ Snarky_backendless.Request.t +=
    | Proof : Nat.N0.n Pickles.Proof.t Snarky_backendless.Request.t

  let handler (proof : _ Pickles.Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled
end

let () =
  let compiled_base = lazy (
        Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N0)
          ~name:"bench_ipa"
          ~choices:(fun ~self:_ ->
            [ { identifier = "fill"
              ; prevs = []
              ; main =
                  (fun _ ->
                    let fresh_zero () =
                      exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                    in
                    (* Two multiplications fill one row. *)
                    for _ = 0 to (1 lsl rows_log2) * 2 do
                      ignore
                        (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
                    done ;
                    { previous_proof_statements = []
                    ; public_output = ()
                    ; auxiliary_output = ()
                    } )
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              }
            ] )
          () )
  in
  let tag, _cache_handle, _proof, Pickles.Provers.[ prove ] =
    time_it "keygen/base" (fun () ->
        let (tag, _, _, _) as compiled = Lazy.force compiled_base in
        let _vk =
          Async.Thread_safe.block_on_async_exn (fun () ->
              Pickles.Side_loaded.Verification_key.of_compiled tag )
        in
        compiled )
  in
  let compiled_recursive = lazy (
        Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N1)
          ~name:"bench_ipa_recursive"
          ~choices:(fun ~self:_ ->
            [ { identifier = "recurse"
              ; prevs = [ tag ]
              ; main =
                  (fun _ ->
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Requests.Proof )
                    in
                    { previous_proof_statements =
                        [ { public_input = ()
                          ; proof
                          ; proof_must_verify = Boolean.true_
                          }
                        ]
                    ; public_output = ()
                    ; auxiliary_output = ()
                    } )
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              }
            ] )
          () )
  in
  let _tag2, _cache_handle2, _recursive_proof, Pickles.Provers.[ recursive_prove ]
      =
    time_it "keygen/recursive" (fun () ->
        let (tag2, _, _, _) as compiled = Lazy.force compiled_recursive in
        let _vk =
          Async.Thread_safe.block_on_async_exn (fun () ->
              Pickles.Side_loaded.Verification_key.of_compiled tag2 )
        in
        compiled )
  in
  let base_proof = ref None in
  for i = 1 to iterations do
    reset_peak_rss () ;
    let _, (), proof =
      time_it
        (sprintf "prove/base/%d" i)
        (fun () -> Async.Thread_safe.block_on_async_exn (fun () -> prove ()))
    in
    base_proof := Some proof
  done ;
  let proof = Option.value_exn !base_proof in
  for i = 1 to iterations do
    reset_peak_rss () ;
    let _, (), _ =
      time_it
        (sprintf "prove/recursive/%d" i)
        (fun () ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              recursive_prove ~handler:(Requests.handler proof) () ) )
    in
    ()
  done
