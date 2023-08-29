.PHONY: get-go-capnp clean

ifeq ($(GO),)
GO = go
endif

GO_CAPNP_VERSION = v3@v3.0.0-alpha.5

ifeq ($(GO_CAPNP_STD),)
GO_CAPNP_STD = $(shell $(GO) env GOPATH)/pkg/mod/capnproto.org/go/capnp/${GO_CAPNP_VERSION}/std
endif

get-go-capnp:
	$(GO) get capnproto.org/go/capnp/$(GO_CAPNP_VERSION)

build/capnpc-go: get-go-capnp
	mkdir -p build && $(GO) build -o build/capnpc-go capnproto.org/go/capnp/v3/capnpc-go

libp2p_ipc.capnp.go: libp2p_ipc.capnp build/capnpc-go
	PATH="build:${PATH}" capnp compile -ogo -I${GO_CAPNP_STD} libp2p_ipc.capnp

libp2p_ipc_capnp.ml libp2p_ipc_capnp.mli: libp2p_ipc.capnp
	mkdir -p _codegen
	capnp compile -oocaml:_codegen -I${GO_CAPNP_STD} $<
	for ext in ml mli; do mv _codegen/libp2p_ipc.$$ext libp2p_ipc_capnp.$$ext; done
	rm -rf _codegen

clean:
	rm -Rf libp2p_ipc.ml libp2p_ipc.mli libp2p_ipc.capnp.go build
