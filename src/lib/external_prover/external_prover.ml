open Core
open Snarky

module M = Snarky.Snark0.Make(Backends.Mnt4.Default)

module Curve = struct
  type t =
    | MNT4753
    | MNT6753

  let to_string = function
    | MNT4753 -> "MNT4753"
    | MNT6753 -> "MNT6753"
end

module Make
    (C : sig val t : Curve.t end)
    (Impl : 
       Snark_intf.S )
    (Other_impl : 
       Snark_intf.S )
    (Backend : sig
       module Field : sig
         type t = Impl.Field.t

         val one : t

         val random : unit -> t

         module Vector : sig
           include Vector.S with type elt = t
           val iter : t -> f:(elt -> unit) -> unit
         end

         val montgomery_representation : t -> char Ctypes_static.ptr
       end

       module R1CS_constraint_system : sig
         type t = Impl.R1CS_constraint_system.t
         val evaluations
           : t -> degree:int -> full_assignment:Field.Vector.t
           -> Field.Vector.t * Field.Vector.t * Field.Vector.t
        end

       module Fq : sig
         type t = Other_impl.Field.t

         module Vector : sig
           include Vector.S with type elt = t
           val iter : t -> f:(elt -> unit) -> unit
         end

         val montgomery_representation : t -> char Ctypes_static.ptr
       end

       module Fqe : sig
         type t
         val to_vector : t -> Fq.Vector.t
         val of_vector : Fq.Vector.t -> t
       end

       module G1 : sig
         type t
         val to_affine_exn : t -> Fq.t * Fq.t
         val of_affine : Fq.t * Fq.t -> t
         module Vector : Vector.S with type elt = t
       end

       module G2 : sig
         type t
         val to_affine_exn : t -> Fqe.t * Fqe.t
         val of_affine : Fqe.t * Fqe.t -> t
         module Vector : Vector.S with type elt = t
       end

       module Proving_key : sig
         type t = Impl.Proving_key.t
         val r1cs_constraint_system : t -> R1CS_constraint_system.t

         val write : t -> string -> unit

         val a : t -> G1.Vector.t
         val b : t -> G2.Vector.t
         val l : t -> G1.Vector.t
         val t : t -> G1.Vector.t
       end

     end)
     = struct

       let curve = C.t

  open Backend
  open Async

  let field_length = (Impl.Field.size_in_bits + 7) / 8

  let write_field out x =
    let r =
      Ctypes.bigarray_of_ptr Ctypes.array1 field_length Bigarray.Char
        (Backend.Field.montgomery_representation x)
    in
    Writer.write_bigstring out ~len:field_length r

  let write_field_vector out =
    Field.Vector.iter ~f:(write_field out)

  let buf = Bytes.create field_length

  (* I think we only need read_fq actually *)
  let read_field
      (type field)
      ((module Impl) : (module Snark_intf.S with type field = field))
      (inc : Reader.t) : field Deferred.Or_error.t
    =
      match%map Reader.read ~len:field_length inc buf with
      | `Eof -> Or_error.error_string "read_field: Got eof"
      | `Ok n ->
        if n = field_length
        then Ok Impl.Bigint.(to_field (of_numeral ~base:255 buf))
        else Or_error.error_string "read_field: Didn't read enough bytes"

  let read_fq = read_field (module Other_impl)

  let read_pair of_affine read_one =
    let open Deferred.Or_error.Let_syntax in
    let%map x = read_one ()
    and y = read_one ()
    in
    of_affine (x, y)

  let read_g1 r =
    read_pair G1.of_affine
      (fun () -> read_fq r)

  let read_fqe
      r 
    =
    let open Deferred.Or_error.Let_syntax in
    let rec do_n_times n f =
      if n = 0
      then return ()
      else 
        let%bind () = f () in
        do_n_times (n - 1) f
    in
    let extension_degree = 
      match curve with
      | MNT4753 -> 2
      | MNT6753 -> 3
    in
    let v = Fq.Vector.create () in
    let%map () =
      do_n_times extension_degree (fun () -> 
        read_fq r >>| Fq.Vector.emplace_back v)
    in
    Fqe.of_vector v

  let read_g2 r =
    read_pair G2.of_affine
      (fun () -> read_fqe r)

  let write_inputs
      out
      proving_key
      prover_state
      k
      input
    =
    let full_assignment =
      let auxiliary_input : Field.Vector.t =
        Impl.generate_auxiliary_input
          [ Impl.Field.typ ] 
          prover_state
          k
          input
      in
      let open Field.Vector in
      let v = create () in
      emplace_back v input;
      for i = 0 to length auxiliary_input do
        emplace_back v (get auxiliary_input i)
      done;
      v
    in
    let a, b, c =
      let system = Proving_key.r1cs_constraint_system proving_key in
      let d = failwith "" in
      R1CS_constraint_system.evaluations
        system
        ~degree:d
        ~full_assignment
    in
    write_field out Field.one;
    List.iter ~f:(write_field_vector out)
      [ full_assignment
      ; a
      ; b
      ; c
      ];
    let r = Field.random () in
    write_field out r

  type config =
    { preprocess_parameters : string
    ; prove : string
    }

  open Async

  type t =
    { preprocessed_parameters : string
    ; temp_dir : string
    ; process : Process.t
    }

  let exec prog args =
    let open Async in
    Process.run_exn ~prog ~args ()
    >>| ignore

  let cleanup (t:t) =
    exec "rm"[ "-r"; t.temp_dir ]

  let create
      { preprocess_parameters
      ; prove
      }
      pk
    =
    let open Async in
    let temp_dir =
      Filename.temp_dir ~in_dir:(Sys.getenv_exn "HOME") "external_prover" ""
    in
    let parameters = temp_dir ^/ "parameters" in
    let preprocessed_parameters = temp_dir ^/ "preprocessed" in
    Proving_key.write pk parameters;
    let%bind () =
      exec preprocess_parameters
        [ parameters; preprocessed_parameters ]
    in
    let%bind process =
      Process.create_exn
        ~prog:prove
        ~args:[
          "compute";
          Curve.to_string curve;
          parameters; preprocessed_parameters 
        ]
        ()
    in
    return
      { preprocessed_parameters
      ; temp_dir
      ; process
      }

  let prove (t : t) proving_key prover_state k public_input =
    write_inputs
      input proving_key prover_state
      k public_input;

    let dir = Filename.temp_dir ~in_dir:(Sys.getenv_exn "HOME") "external_prover" "" in
    let input_path = dir ^/ "input" in
    let input = Out_channel.create input_path in

    Async.Process.create ~prog:t.prove
      ~args:
        [ 
          Curve.to_string curve
        ; "compute"
        ; params_path
        ; input_path
        ]
  ;;

    Unix.rem

    let temp_dir = U
    Filename.temp_dir ~in_dir:
    Async.Unix.remove
    let path = Unix.mkstemp 
  ;;
end


