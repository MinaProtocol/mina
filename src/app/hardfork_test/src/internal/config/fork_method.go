package config

import (
	"fmt"
	"sort"
	"strings"
)

type ForkMethod int

const (
	Legacy ForkMethod = iota
	Advanced
)

var forkMethodToString = map[ForkMethod]string{
	Legacy:   "legacy",
	Advanced: "advanced",
}

var stringToForkMethod = map[string]ForkMethod{
	"legacy":   Legacy,
	"advanced": Advanced,
}

func (m *ForkMethod) String() string {
	if s, ok := forkMethodToString[*m]; ok {
		return s
	}
	panic(fmt.Sprintf("Can't convert fork method %d to string", int(*m)))
}

func validKeys(m map[string]ForkMethod) string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return strings.Join(keys, "|")
}

func (m *ForkMethod) Set(s string) error {
	v, ok := stringToForkMethod[s]
	if !ok {
		return fmt.Errorf("invalid mode %q (valid: %s)", s, validKeys(stringToForkMethod))
	}
	*m = v
	return nil
}

func (m *ForkMethod) Type() string { return "fork method" }
