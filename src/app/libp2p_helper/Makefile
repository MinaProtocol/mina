.PHONY: libp2p_helper clean test
.DEFAULT_GOAL := libp2p_helper

../../libp2p_ipc/libp2p_ipc.capnp.go:
	make -C ../../libp2p_ipc libp2p_ipc.capnp.go

libp2p_helper: ../../libp2p_ipc/libp2p_ipc.capnp.go
	$(WRAPAPP) ../../../scripts/build-go-helper.sh libp2p_helper

test: ../../libp2p_ipc/libp2p_ipc.capnp.go
	$(WRAPAPP) ../../../scripts/build-go-helper.sh --test libp2p_helper

clean:
	rm -rf result ../../libp2p_ipc/libp2p_ipc.capnp.go
