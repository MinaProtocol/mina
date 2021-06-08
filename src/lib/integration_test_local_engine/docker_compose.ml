open Core

module Compose = struct
  module DockerMap = struct
    type 'a t = (string, 'a, String.comparator_witness) Map.t

    let empty = Map.empty (module String)
  end

  module Service = struct
    module Volume = struct
      type t = {type_: string; source: string; target: string}
      [@@deriving to_yojson]

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

    type replicas = {replicas: int} [@@deriving to_yojson]

    type t =
      { image: string
      ; volumes: Volume.t list
      ; deploy: replicas
      ; command: string list
      ; environment: Environment.t }
    [@@deriving to_yojson]
  end

  type service_map = Service.t DockerMap.t

  let service_map_to_yojson m =
    `Assoc (m |> Map.map ~f:Service.to_yojson |> Map.to_alist)

  type t = {version: string; services: service_map} [@@deriving to_yojson]
end

type t = Compose.t [@@deriving to_yojson]

let to_string = Fn.compose Yojson.Safe.pretty_to_string to_yojson
