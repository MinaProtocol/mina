module delegation_backend

go 1.16

require (
	backend_utilities/misc v0.0.0
	backend_utilities/counter v0.0.0
	cloud.google.com/go/storage v1.17.0
	github.com/btcsuite/btcutil v1.0.2
	github.com/ipfs/go-log/v2 v2.3.0
	golang.org/x/crypto v0.0.0-20200622213623-75b288015ac9
	google.golang.org/api v0.57.0
)

replace backend_utilities/misc => ../../../backend_utilities/misc
replace backend_utilities/counter => ../../../backend_utilities/counter