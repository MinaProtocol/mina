open Core

module Compose = struct
  module DockerMap = struct
    type 'a t = (string, 'a, String.comparator_witness) Map.t

    let empty = Map.empty (module String)
  end

  module Service = struct
    module Volume = struct
      type t = {type_: string; source: string; target: string}

      let create name =
        {type_= "bind"; source= "." ^/ name; target= "/root" ^/ name}

      let to_yojson {type_; source; target} =
        let field k v = (k, `String v) in
        let fields =
          [ type_ |> field "type"
          ; source |> field "source"
          ; target |> field "target" ]
        in
        `Assoc fields
    end

    module Environment = struct
      type t = string DockerMap.t

      let create =
        List.fold ~init:DockerMap.empty ~f:(fun accum env ->
            let key, data = env in
            Map.set accum ~key ~data )

      let to_yojson m =
        `Assoc (m |> Map.map ~f:(fun x -> `String x) |> Map.to_alist)
    end

    type t =
      { image: string
      ; volumes: Volume.t list
      ; command: string list
      ; environment: Environment.t }
    [@@deriving to_yojson]
  end

  type service_map = Service.t DockerMap.t

  (* Used to combine different type of service maps. There is an assumption that these maps
  are disjoint and will not conflict *)
  let merge_maps (map_a : service_map) (map_b : service_map) =
    Map.fold map_b ~init:map_a ~f:(fun ~key ~data acc ->
        Map.update acc key ~f:(function None -> data | Some data' -> data') )

  let service_map_to_yojson m =
    `Assoc (m |> Map.map ~f:Service.to_yojson |> Map.to_alist)

  type t = {version: string; services: service_map} [@@deriving to_yojson]
end

type t = Compose.t [@@deriving to_yojson]

let to_string = Fn.compose Yojson.Safe.pretty_to_string to_yojson
