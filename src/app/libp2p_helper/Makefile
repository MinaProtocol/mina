.PHONY: libp2p_helper clean test

libp2p_helper:
	$(WRAPAPP) ../../../scripts/build-go-helper.sh libp2p_helper

test:
	$(WRAPAPP) ../../../scripts/build-go-helper.sh --test libp2p_helper

clean:
	rm -rf result
