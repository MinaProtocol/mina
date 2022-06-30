(** scalars.ml -- Define GraphQL scalar types alongside decoders and encoders for use with graphql-ppx.*)

open Graphql_async
open Schema
open Base

module type S_JSON = sig
  type t

  val parse : Yojson.Basic.t -> t

  val serialize : t -> Yojson.Basic.t

  val typ : unit -> ('a, t option) Graphql_async.Schema.typ
end

let unsigned_scalar_scalar ~to_string typ_name =
  scalar typ_name
    ~doc:
      (Core.sprintf
         !"String representing a %s number in base 10"
         (Stdlib.String.lowercase_ascii typ_name) )
    ~coerce:(fun num -> `String (to_string num))

module UInt32 : S_JSON with type t = Unsigned.UInt32.t = struct
  type t = Unsigned.UInt32.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt32.of_string

  let serialize value = `String (Unsigned.UInt32.to_string value)

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt32.to_string "UInt32"
end

module UInt64 : S_JSON with type t = Unsigned.UInt64.t = struct
  type t = Unsigned.UInt64.t

  let parse json = Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

  let serialize = Encoders.uint64

  let typ () =
    unsigned_scalar_scalar ~to_string:Unsigned.UInt64.to_string "UInt64"
end

module PublicKey : S_JSON with type t = Signature_lib.Public_key.Compressed.t =
struct
  open Signature_lib

  type t = Signature_lib.Public_key.Compressed.t

  let parse json =
    Yojson.Basic.Util.to_string json
    |> Signature_lib.Public_key.of_base58_check_decompress_exn

  let serialize key = `String (Public_key.Compressed.to_base58_check key)

  let typ () =
    scalar "PublicKey" ~doc:"Base58Check-encoded public key string"
      ~coerce:serialize
end

module Balance : S_JSON with type t = Currency.Balance.t = struct
  type t = Currency.Balance.t

  let parse json =
    Yojson.Basic.Util.to_string json |> Currency.Balance.of_string

  let serialize x = `String (Currency.Balance.to_string x)

  let typ () = scalar "Balance" ~coerce:serialize
end

module TokenId : S_JSON with type t = Mina_base.Token_id.t = struct
  type t = Mina_base.Token_id.t

  let parse json =
    Yojson.Basic.Util.to_string json |> Mina_base.Token_id.of_string

  let serialize tid = `String (Mina_base.Token_id.to_string tid)

  let typ () =
    scalar "TokenId" ~doc:"String representation of a token's base58 identifier"
      ~coerce:serialize
end

module Amount : S_JSON with type t = Currency.Amount.t = struct
  type t = Currency.Amount.t

  let parse json = Yojson.Basic.Util.to_string json |> Currency.Amount.of_string

  let serialize x = `String (Currency.Amount.to_string x)

  let typ () = scalar "Amount" ~coerce:serialize
end

module Fee : S_JSON with type t = Currency.Fee.t = struct
  type t = Currency.Fee.t

  let parse json = Yojson.Basic.Util.to_string json |> Currency.Fee.of_string

  let serialize value = `String (Currency.Fee.to_string value)

  let typ () = scalar "Fee" ~coerce:serialize
end

module EpochSeed = struct
  type t = Mina_base.Epoch_seed.t

  let parse json =
    Yojson.Basic.Util.to_string json |> Mina_base.Epoch_seed.of_base58_check_exn

  let serialize seed = `String (Mina_base.Epoch_seed.to_base58_check seed)

  let typ () =
    scalar "EpochSeed" ~doc:"Base58Check-encoded epoch seed" ~coerce:serialize
end

module JSON = struct
  type t = Yojson.Basic.t

  let parse = Fn.id

  let serialize = Fn.id

  let typ () = scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:serialize
end

module BlockTime = struct
  type t = Block_time.t

  let parse json = Yojson.Basic.Util.to_string json |> Block_time.of_string_exn

  let serialize timestamp = `String (Block_time.to_string timestamp)

  let typ () = scalar "BlockTime" ~coerce:serialize
end

module Time = struct
  type t = Core_kernel.Time.t

  let parse json =
    let () =
      Stdlib.Format.printf "parsing %s\n" (Yojson.Basic.to_string json)
    in
    Yojson.Basic.Util.to_string json |> Core_kernel.Time.of_string

  let serialize t =
    (* let () = Stdlib.Format.printf "t=%a\nserializing: %s\n" (Core.Time.pp) t (Core_kernel.Time.to_string t) in *)
    (* `String (Core_kernel.Time.to_string t) *)
    `String (Stdlib.Format.asprintf "%a" Core_kernel.Time.pp t)

  let typ () = scalar "Time" ~coerce:serialize
end
