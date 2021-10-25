GO_CAPNP_VERSION=v3@v3.0.0-alpha.1
GO_CAPNP_STD=$(shell go env GOPATH)/pkg/mod/capnproto.org/go/capnp/${GO_CAPNP_VERSION}/std

libp2p_ipc.capnp.go: libp2p_ipc.capnp
	capnp compile -ogo -I${GO_CAPNP_STD} $<

libp2p_ipc.ml libp2p_ipc.mli: libp2p_ipc.capnp
	capnp compile -oocaml -I${GO_CAPNP_STD} $<