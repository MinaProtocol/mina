open Core_kernel

module Metadata = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Yojson.Safe.t String.Map.t

      let to_latest = Fn.id

      let to_yojson t = `Assoc (String.Map.to_alist t)

      let of_yojson = function
        | `Assoc alist ->
            Ok (String.Map.of_alist_exn alist)
        | _ ->
            Error "Unexpected object"

      include Binable.Of_binable
                (Core_kernel.String.Stable.V1)
                (struct
                  type nonrec t = t

                  let to_binable t = to_yojson t |> Yojson.Safe.to_string

                  let of_binable (t : string) : t =
                    Yojson.Safe.from_string t |> of_yojson |> Result.ok
                    |> Option.value_exn
                end)
    end
  end]

  let empty = String.Map.empty

  let to_yojson = Stable.Latest.to_yojson

  let of_yojson = Stable.Latest.of_yojson

  let of_alist_exn = String.Map.of_alist_exn

  let mem = String.Map.mem

  let extend (t : t) alist =
    List.fold_left alist ~init:t ~f:(fun acc (key, data) ->
        String.Map.set acc ~key ~data)

  let merge (a : t) (b : t) = extend a (String.Map.to_alist b)
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { null : bool; metadata : Metadata.Stable.V1.t; id : string }

    let to_latest = Fn.id
  end
end]
