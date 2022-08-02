module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let peer () : (_, Network_peer.Peer.Display.t option) typ =
  obj "Peer" ~fields:(fun _ ->
      let open Graphql_basic_scalars.Shorthand in
      List.rev
      @@ Network_peer.Peer.Display.Fields.fold ~init:[] ~host:nn_string
           ~libp2p_port:nn_int ~peer_id:nn_string )
