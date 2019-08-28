# libp2p_helper hints

If you are adding new `methodIdx` values, edit `generate_methodidx/main.go`
(search for `TypesAndValues`) with the names of the new values. Then, run `go
run generate_methodidx/main.go > libp2p_helper/methodidx_jsonenum.go`.
