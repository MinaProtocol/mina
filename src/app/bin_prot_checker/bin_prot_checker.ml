(* generate_keypair.ml -- utility app that only generates keypairs *)

open Core_kernel
open Async

module type Test_intf = sig
  type t [@@deriving bin_io, equal]

  val name : string

  val v : t

  val generator : t Quickcheck.Generator.t

  val to_string : t -> string
end

module Tests = struct
  module Nat0 = struct
    (* NB: Nat0 is used internally to describe the length of variable-length
       objects like lists. Here, we use a list of 'unit' -- encoded as \x00 --
       so that we can have the code output a Nat0 in a genuine situation
       without our needing to 'hand-roll' one.
    *)
    type t = unit list [@@deriving bin_io, equal, show]

    let name = "nat0"

    let v = [()]

    let generator =
      (* Don't generate too long a list! *)
      Quickcheck.Generator.map
        ~f:(List.init ~f:(fun _ -> ()))
        (Int.gen_incl 0 (1024 * 1024))

    let to_string x = Int.to_string (List.length x)
  end

  module Bool = struct
    type t = bool [@@deriving bin_io, equal, show]

    let name = "bool"

    let v = true

    let generator = Bool.quickcheck_generator

    let to_string = Bool.to_string
  end

  module Int = struct
    type t = int [@@deriving bin_io, equal, show]

    let name = "int"

    let v = 12345

    let generator = Int.quickcheck_generator

    let to_string = Int.to_string
  end

  module Int32 = struct
    type t = int32 [@@deriving bin_io, equal, show]

    let name = "int32"

    let v = 12345l

    let generator = Int32.quickcheck_generator

    let to_string = Int32.to_string
  end

  module Int64 = struct
    type t = int64 [@@deriving bin_io, equal, show]

    let name = "int64"

    let v = 12345L

    let generator = Int64.quickcheck_generator

    let to_string = Int64.to_string
  end

  module Enum = struct
    type t = A | B | C [@@deriving bin_io, equal, show]

    let name = "enum"

    let v = A

    let generator = Quickcheck.Generator.of_list [A; B; C]

    let to_string = show
  end

  module Record = struct
    type t = {a: int; b: bool; c: Enum.t} [@@deriving bin_io, equal, show]

    let name = "record"

    let v = {a= 15; b= true; c= C}

    let generator =
      let open Quickcheck.Generator.Let_syntax in
      let%bind a = Int.generator in
      let%bind b = Bool.generator in
      let%map c = Enum.generator in
      {a; b; c}

    let to_string = show
  end

  module Variant = struct
    type t = A of int | B of bool | C of Enum.t | D of Record.t
    [@@deriving bin_io, equal, show]

    let name = "variant"

    let v = A 15

    let generator =
      Quickcheck.Generator.variant4 Int.generator Bool.generator Enum.generator
        Record.generator
      |> Quickcheck.Generator.map ~f:(function
           | `A x ->
               A x
           | `B x ->
               B x
           | `C x ->
               C x
           | `D x ->
               D x )

    let to_string = show
  end

  module Public_key = struct
    type t = Signature_lib.Public_key.Compressed.Stable.Latest.t
    [@@deriving bin_io, equal]

    let name = "public-key"

    let generator = Signature_lib.Public_key.Compressed.gen

    let v = Quickcheck.random_value ~seed:(`Deterministic "") generator

    let to_string = Signature_lib.Public_key.Compressed.to_base58_check

    let show = to_string

    let pp fmt x = Format.pp_print_string fmt (to_string x)
  end

  module All = struct
    type t =
      { nat0: Nat0.t
      ; bool: Bool.t
      ; int: Int.t
      ; int32: Int32.t
      ; int64: Int64.t
      ; enum: Enum.t
      ; record: Record.t
      ; variant: Variant.t
      ; public_key: Public_key.t }
    [@@deriving bin_io, equal, show, make]

    let name = "all"

    let v =
      make ~nat0:Nat0.v ~bool:Bool.v ~int:Int.v ~int32:Int32.v ~int64:Int64.v
        ~enum:Enum.v ~record:Record.v ~variant:Variant.v
        ~public_key:Public_key.v

    let generator =
      let open Quickcheck.Generator.Let_syntax in
      let%bind nat0 = Nat0.generator in
      let%bind bool = Bool.generator in
      let%bind int = Int.generator in
      let%bind int32 = Int32.generator in
      let%bind int64 = Int64.generator in
      let%bind enum = Enum.generator in
      let%bind record = Record.generator in
      let%bind variant = Variant.generator in
      let%map public_key = Public_key.generator in
      make ~nat0 ~bool ~int ~int32 ~int64 ~enum ~record ~variant ~public_key

    let to_string = show
  end

  let all_tests : (module Test_intf) list =
    [ (module Nat0)
    ; (module Bool)
    ; (module Int)
    ; (module Int32)
    ; (module Int64)
    ; (module Enum)
    ; (module Record)
    ; (module Variant)
    ; (module Public_key)
    ; (module All) ]
end

module Flags = struct
  open Command.Param

  let test =
    flag "--test" ~aliases:["test"]
      ~doc:
        (sprintf "NAME Name of the test to run. One of %s"
           ( List.map Tests.all_tests ~f:(fun (module Test : Test_intf) ->
                 Test.name )
           |> String.concat ~sep:" | " ))
      (required string)
    |> Command.Param.map ~f:(fun str ->
           List.find_exn Tests.all_tests ~f:(fun (module Test : Test_intf) ->
               String.(equal (lowercase str) Test.name) ) )

  let fixed_value =
    flag "--fixed-value" ~aliases:["fixed-value"]
      ~doc:"Use a fixed value for the given test (true by default)" no_arg
    |> Command.Param.map ~f:(function true -> Some `Fixed | false -> None)

  let random_value =
    flag "--random-value" ~aliases:["random-value"]
      ~doc:"SEED Use a random value determined by the given seed"
      (optional string)
    |> Command.Param.map ~f:(Option.map ~f:(fun seed -> `Random seed))

  let value =
    choose_one
      ~if_nothing_chosen:(`Default_to `Fixed)
      [fixed_value; random_value]

  let path =
    flag "--path" ~aliases:["path"] ~doc:"PATH Path to the file"
      (required string)
end

let serialize =
  Command.async ~summary:"Serialize bin_prot data to a file"
    (let open Command.Let_syntax in
    let%map_open (module Test_case) = Flags.test
    and path = Flags.path
    and value = Flags.value in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let value =
      match value with
      | `Fixed ->
          Test_case.v
      | `Random seed ->
          Quickcheck.random_value ~seed:(`Deterministic seed)
            Test_case.generator
    in
    printf "Writing %s to file %s\n" (Test_case.to_string value) path ;
    let size = Test_case.bin_size_t value in
    let outbuf = Bigstring.create size in
    let out_pos = Test_case.bin_write_t outbuf ~pos:0 value in
    Out_channel.with_file path ~binary:true ~f:(fun file ->
        for i = 0 to size - 1 do
          Out_channel.output_char file (Bigstring.get outbuf i)
        done ) ;
    printf "Wrote %i bytes to file %s\n" out_pos path ;
    exit 0)

let deserialize =
  Command.async ~summary:"Deserialize bin_prot data from a file"
    (let open Command.Let_syntax in
    let%map_open (module Test_case) = Flags.test
    and path = Flags.path
    and value = Flags.value in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let value =
      match value with
      | `Fixed ->
          Test_case.v
      | `Random seed ->
          Quickcheck.random_value ~seed:(`Deterministic seed)
            Test_case.generator
    in
    let inbuf =
      In_channel.with_file path ~binary:true ~f:(fun file ->
          let size = In_channel.length file |> Int64.to_int_exn in
          let inbuf = Bigstring.create size in
          for i = 0 to size - 1 do
            Bigstring.set inbuf i
              (Option.value_exn
                 ~message:
                   "Unexpected failure to read a character from the input file"
                 (In_channel.input_char file))
          done ;
          printf "Read %i bytes from file %s\n" size path ;
          inbuf )
    in
    let pos_ref = ref 0 in
    let read_value = Test_case.bin_read_t inbuf ~pos_ref in
    printf "Read %s from file %s\n" (Test_case.to_string read_value) path ;
    if Test_case.equal value read_value then (
      printf "Value matches expected\n" ;
      exit 0 )
    else (
      printf "Value does not match expected:\n%s\nvs\n%s\n"
        (Test_case.to_string read_value)
        (Test_case.to_string value) ;
      exit 1 ))

let () =
  Command.run
    (Command.group ~summary:"Bin-prot checker"
       [("serialize", serialize); ("deserialize", deserialize)])
