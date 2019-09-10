[%%import
"../../config.mlh"]

open Util
open Core_kernel
open Snark_params
open Tick
open Unsigned_extended
open Snark_bits
open Fold_lib
open Module_version

module Time = struct
  (* Milliseconds since epoch *)
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = UInt64.t
        [@@deriving bin_io, sexp, compare, eq, hash, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "block_time"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  module Controller = struct
    [%%if
    time_offsets]

    type t = Time.Span.t Lazy.t

    let create offset = offset

    let basic ~logger =
      lazy
        (let offset =
           match Core.Sys.getenv "CODA_TIME_OFFSET" with
           | Some tm ->
               Int.of_string tm
           | None ->
               Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
                 "Environment variable CODA_TIME_OFFSET not found, using \
                  default of 0" ;
               0
         in
         Core_kernel.Time.Span.of_int_sec offset)

    [%%else]

    type t = unit

    let create () = ()

    let basic ~logger:_ = ()

    [%%endif]
  end

  (* DO NOT add bin_io the deriving list *)
  type t = Stable.Latest.t [@@deriving sexp, compare, eq, hash, yojson]

  type t0 = t

  module B = Bits

  let bit_length = 64

  let length_in_triples = bit_length_to_triple_length bit_length

  module Bits = Bits.UInt64
  include B.Snarkable.UInt64 (Tick)

  let fold t = Fold.group3 ~default:false (Bits.fold t)

  module Span = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = UInt64.t [@@deriving bin_io, sexp, compare, version]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "block_time_span"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    include Stable.Latest
    module Bits = B.UInt64
    include B.Snarkable.UInt64 (Tick)

    let of_time_span s = UInt64.of_int64 (Int64.of_float (Time.Span.to_ms s))

    let to_time_ns_span s =
      Time_ns.Span.of_ms (Int64.to_float (UInt64.to_int64 s))

    let to_ms = UInt64.to_int64

    let of_ms = UInt64.of_int64

    let ( + ) = UInt64.Infix.( + )

    let ( - ) = UInt64.Infix.( - )

    let ( * ) = UInt64.Infix.( * )

    let ( < ) = UInt64.( < )

    let ( > ) = UInt64.( > )

    let ( = ) = UInt64.( = )

    let ( <= ) = UInt64.( <= )

    let ( >= ) = UInt64.( >= )

    let min = UInt64.min
  end

  let ( < ) = UInt64.( < )

  let ( > ) = UInt64.( > )

  let ( = ) = UInt64.( = )

  let ( <= ) = UInt64.( <= )

  let ( >= ) = UInt64.( >= )

  let of_time t =
    UInt64.of_int64
      (Int64.of_float (Time.Span.to_ms (Time.to_span_since_epoch t)))

  let to_time t =
    Time.of_span_since_epoch
      (Time.Span.of_ms (Int64.to_float (UInt64.to_int64 t)))

  [%%if
  time_offsets]

  let now offset = of_time (Time.sub (Time.now ()) (Lazy.force offset))

  [%%else]

  let now _ = of_time (Time.now ())

  [%%endif]

  let field_var_to_unpacked (x : Tick.Field.Var.t) =
    Tick.Field.Checked.unpack ~length:64 x

  let epoch = of_time Time.epoch

  let add x y = UInt64.add x y

  let diff x y = UInt64.sub x y

  let sub x y = UInt64.sub x y

  let to_span_since_epoch t = diff t epoch

  let of_span_since_epoch s = UInt64.add s epoch

  let diff_checked x y =
    let pack = Tick.Field.Var.project in
    Span.unpack_var Tick.Field.Checked.(pack x - pack y)

  let modulus t span = UInt64.rem t span

  let unpacked_to_number var =
    let bits = Span.Unpacked.var_to_bits var in
    Number.of_bits (bits :> Boolean.var list)

  let to_string time =
    to_span_since_epoch time |> Span.to_ms |> Int64.to_string

  let of_string_exn string =
    Int64.of_string string |> Span.of_ms |> of_span_since_epoch
end

include Time
module Timeout = Timeout.Make (Time)
