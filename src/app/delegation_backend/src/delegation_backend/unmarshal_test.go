package delegation_backend

import (
	"testing"
)

func TestUnmarshalSuccess(t *testing.T) {
	testNames := []string{"req-no-snark", "req-with-snark", "req-v1-with-snark"}
	for _, f := range testNames {
		body := readTestFile(f, t)

		req, err := unmarshalPayload(body)
		if err != nil {
			t.Logf("failed decoding test file %s", f)
			t.Logf(err.Error())
			t.FailNow()
		}
		if req == nil {
			t.Logf("unmarshal returned empty payload %s", f)
			t.FailNow()
		}
		if !req.CheckRequiredFields() {
			t.Logf("missing required fields in payload %s", f)
			t.FailNow()
		}
	}
}
