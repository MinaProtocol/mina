package itn_orchestrator

import "testing"

func TestParseMina(t *testing.T) {
	if _, err := parseMina("12.1234567890"); err == nil {
		t.Fatal("parsing too long a number")
	}
	if _, err := parseMina("a"); err == nil {
		t.Fatal("not a number")
	}
	if _, err := parseMina(".23"); err == nil {
		t.Fatal("no leading zero parsed")
	}
	if v, err := parseMina("0.23"); err != nil || v != 23e7 {
		t.Fatal("leading zero not parsed")
	}
	if v, err := parseMina("00.002300"); err != nil || v != 23e5 {
		t.Fatal("double leading zero not parsed")
	}
	if v, err := parseMina("123.456789"); err != nil || v != 123456789e3 {
		t.Fatal("double leading zero not parsed")
	}
	if v, err := parseMina("123.456789001"); err != nil || v != 123456789001 {
		t.Fatal("double leading zero not parsed")
	}
	if v, err := parseMina("123"); err != nil || v != 123e9 {
		t.Fatal("no dot not parsed")
	}
}
