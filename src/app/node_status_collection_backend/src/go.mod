module node_status_collection_backend

go 1.16

require (
	cloud.google.com/go/storage v1.17.0 // indirect
	github.com/gogo/protobuf v1.2.1 // indirect
	github.com/ipfs/go-log/v2 v2.3.0 // indirect
	github.com/opentracing/opentracing-go v1.1.0 // indirect
	backend_utilities v0.0.0
)

replace backend_utilities => ../../../backend_utilities