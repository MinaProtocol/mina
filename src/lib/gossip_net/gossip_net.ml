include Intf
module Any = Any
module Libp2p = Libp2p
module Fake = Fake

module type S = sig
  type sinks

  module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

  include module type of Intf

  module Message : module type of Message

  module Any : Any.S with module Rpc_intf := Rpc_intf with type sinks := sinks

  module Libp2p :
    Libp2p.S with module Rpc_intf := Rpc_intf with type sinks := sinks

  module Fake : Fake.S with module Rpc_intf := Rpc_intf with type sinks := sinks
end

module type Sinks = Message.Sinks

module Wrapped_sinks = Message.Wrapped_sinks

module Make
    (SinksImpl : Message.Sinks)
    (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf with type sinks := SinksImpl.sinks = struct
  include Intf
  module Message = Message
  module Any = Any.Make (SinksImpl) (Rpc_intf)
  module Fake = Fake.Make (SinksImpl) (Rpc_intf)
  module Libp2p = Libp2p.Make (SinksImpl) (Rpc_intf)
end
