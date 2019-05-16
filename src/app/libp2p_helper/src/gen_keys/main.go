package main
import (
        pnet "github.com/libp2p/go-libp2p-pnet"
        "log"
        "io"
        "os"
    )

func main() {
    key, err := pnet.GenerateV1PSK()
    if err != nil {
        log.Fatal("sad %s", err);
    }
    io.Copy(os.Stdout, key)
}
