module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let addrs_and_ports () : (_, Node_addrs_and_ports.Display.t option) typ =
  obj "AddrsAndPorts" ~fields:(fun _ ->
      let open Graphql_basic_scalars.Shorthand in
      List.rev
      @@ Node_addrs_and_ports.Display.Fields.fold ~init:[]
           ~external_ip:nn_string ~bind_ip:nn_string ~client_port:nn_int
           ~libp2p_port:nn_int ~peer:(id ~typ:(Network_peer_unix.Graphql_objects.peer ())) )
