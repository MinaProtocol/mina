open Network_peer

type t [@@deriving compare, bin_io]

val to_string : t -> string

val of_string : string -> t

val of_libp2p_ipc : Libp2p_ipc.Reader.Multiaddr.t -> t

val to_libp2p_ipc : t -> Libp2p_ipc.multiaddr

val to_peer : t -> Peer.t option

val valid_as_peer : t -> bool

val of_file_contents : string -> t list
