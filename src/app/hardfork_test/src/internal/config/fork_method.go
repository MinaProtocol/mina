package config

import (
	"fmt"
	"math/rand"
	"strings"
)

type ForkMethod int

const (
	Legacy ForkMethod = iota
	Advanced
	Auto
)

func (m ForkMethod) String() string {
	names := [...]string{"legacy", "advanced", "auto"}
	if m < 0 || int(m) > len(names)-1 {
		panic(fmt.Errorf("Can't convert fork method %d to string", int(m)))
	}
	return names[m]
}

var stringToForkMethod = map[string]ForkMethod{
	"legacy":   Legacy,
	"advanced": Advanced,
	"auto":     Auto,
}

func validForkMethods() string {
	keys := make([]string, 0, len(stringToForkMethod))
	for k := range stringToForkMethod {
		keys = append(keys, k)
	}
	return strings.Join(keys, "|")
}

type ForkMethodSet map[ForkMethod]struct{}

func (s *ForkMethodSet) Set(val string) error {
	method, ok := stringToForkMethod[val]
	if !ok {
		return fmt.Errorf("invalid fork method: %q (valid: %s)", val, validForkMethods())
	}
	(*s)[method] = struct{}{}
	return nil
}

func (s *ForkMethodSet) Type() string {
	return "forkMethodList"
}

func (s *ForkMethodSet) String() string {
	result := ""
	if s != nil {
		var res []string
		for m := range *s {
			res = append(res, m.String())
		}
		result = strings.Join(res, ", ")
	}
	return fmt.Sprintf("[%s]", result)
}

func (s *ForkMethodSet) RandomChoose() ForkMethod {
	if s == nil || len(*s) == 0 {
		panic("choosing fork method from empty set")
	}

	keys := make([]ForkMethod, 0, len(*s))
	for k := range *s {
		keys = append(keys, k)
	}

	randomIndex := rand.Intn(len(keys))

	return keys[randomIndex]
}
