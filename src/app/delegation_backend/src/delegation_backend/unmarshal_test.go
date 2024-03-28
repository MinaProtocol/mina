package delegation_backend

import (
	"encoding/json"
	"testing"
)

func TestUnmarshalSuccess(t *testing.T) {
	testNames := []string{"req-no-snark", "req-with-snark", "req-v1-with-snark"}
	for _, f := range testNames {
		body := readTestFile(f, t)

		var req submitRequest

		if err := json.Unmarshal(body, &req); err != nil {
			t.Logf("failed decoding test file %s", f)
			t.Logf(err.Error())
			t.FailNow()
		}
		if !req.CheckRequiredFields() {
			t.Logf("missing required fields in payload %s", f)
			t.FailNow()
		}
	}
}
