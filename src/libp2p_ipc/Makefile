.PHONY: get-go-capnp clean

GO_CAPNP_VERSION=v3@v3.0.0-alpha.1
GO_CAPNP_STD=$(shell go env GOPATH)/pkg/mod/capnproto.org/go/capnp/${GO_CAPNP_VERSION}/std

get-go-capnp:
	go get capnproto.org/go/capnp/$(GO_CAPNP_VERSION)

build/capnpc-go: get-go-capnp
	mkdir -p build && go build -o build/capnpc-go capnproto.org/go/capnp/v3/capnpc-go

libp2p_ipc.capnp.go: libp2p_ipc.capnp build/capnpc-go
	PATH="build:${PATH}" capnp compile -ogo -I${GO_CAPNP_STD} libp2p_ipc.capnp

libp2p_ipc.ml libp2p_ipc.mli: libp2p_ipc.capnp
	capnp compile -oocaml -I${GO_CAPNP_STD} $<

clean:
	rm -Rf libp2p_ipc.ml libp2p_ipc.mli libp2p_ipc.capnp.go build
