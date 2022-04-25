package main

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestConvertOldPkToNew(t *testing.T) {
	pkOld := "X4pjnQmPXyvay6ohytRAMWQDAhLw15LYb8L3qNnvaZyhhWndcxwv"
	pk, err := readOldPk(pkOld)
	require.NoError(t, err)
	require.Equal(t, "B62qka4Xt1WGENxiv17rQpb4ryU6HhWdwdjukBowV7g5qKMzXrYoWB3", pk.String())
}
