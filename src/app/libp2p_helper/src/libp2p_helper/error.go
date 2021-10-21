package main

import (
	"fmt"

	"github.com/go-errors/errors"
)

// TODO: wrap these in a new type, encode them differently in the rpc mainloop

type wrappedError struct {
	e   error
	tag string
}

func (w wrappedError) Error() string {
	return fmt.Sprintf("%s error: %s", w.tag, w.e.Error())
}

func (w wrappedError) Unwrap() error {
	return w.e
}

func wrapError(e error, tag string) error {
	return wrappedError{e: e, tag: tag}
}

func badRPC(e error) error {
	return wrapError(e, "internal RPC")
}

func badp2p(e error) error {
	return wrapError(e, "libp2p")
}

func badHelper(e error) error {
	return wrapError(e, "initializing helper")
}

func badAddr(e error) error {
	return wrapError(e, "initializing external addr")
}

func needsConfigure() error {
	return badRPC(errors.New("helper not yet configured"))
}

func needsDHT() error {
	return badRPC(errors.New("helper not yet joined to pubsub"))
}
