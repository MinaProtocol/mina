GO_CAPNP_VERSION=v3@v3.0.0-alpha.1
GO_CAPNP_STD=$(shell go env GOPATH)/pkg/mod/capnproto.org/go/capnp/${GO_CAPNP_VERSION}/std

libp2p_ipc.capnp.go: libp2p_ipc.capnp
	capnp compile -ogo -I${GO_CAPNP_STD} $<

libp2p_ipc_capnp.ml libp2p_ipc_capnp.mli: libp2p_ipc.capnp
	mkdir -p _codegen
	capnp compile -oocaml:_codegen -I${GO_CAPNP_STD} $<
	for ext in ml mli; do mv _codegen/libp2p_ipc.$$ext libp2p_ipc_capnp.$$ext; done
	rm -rf _codegen