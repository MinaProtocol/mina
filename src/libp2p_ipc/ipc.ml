include Libp2p_ipc_capnp.Make (Capnp.BytesMessage)

type libp2p_config = Reader.Libp2pConfig.t

type gating_config = Reader.GatingConfig.t

type multiaddr = Builder.Multiaddr.t

type sequence_number = Reader.SequenceNumber.t

type validation_id = Reader.ValidationId.t

type subscription_id = Reader.SubscriptionId.t

type peer_id = Reader.PeerId.t

type peer_info = Reader.PeerInfo.t

type stream_id = Reader.StreamId.t

type validation_result = Builder.ValidationResult.t

type rpc_request_body = Builder.Libp2pHelperInterface.RpcRequest.unnamed_union_t

type rpc_request = Builder.Libp2pHelperInterface.RpcRequest.t

type rpc_response_body =
  Reader.Libp2pHelperInterface.RpcResponseSuccess.unnamed_union_t

type rpc_response = Reader.Libp2pHelperInterface.RpcResponse.t

type push_message = Builder.Libp2pHelperInterface.PushMessage.t

type incoming_message = Reader.DaemonInterface.Message.t

type outgoing_message = Builder.Libp2pHelperInterface.Message.t

type topic_level = Builder.TopicLevel.t
