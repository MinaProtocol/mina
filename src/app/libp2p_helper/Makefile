ifeq ($(GO),)
GO := go
endif

libp2p_helper:
	$(WRAPAPP) bash -c "set -e && rm -rf result && mkdir -p result/bin && cd src && $(GO) mod download && cd .. && for f in generate_methodidx libp2p_helper; do cd src/\$$f && $(GO) build; mv \$$f ../../result/bin/\$$f; cd ../../; done"

clean:
	rm -rf result
