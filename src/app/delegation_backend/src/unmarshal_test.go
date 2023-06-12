package delegation_backend

import (
	"testing"
)

func TestUnmarshalSuccess(t *testing.T) {
	testNames := []string{"req-no-snark", "req-with-snark"}
	for _, f := range testNames {
		body := readTestFile(f, t)

		req, err := unmarshalPayload(body)
		if err != nil {
			t.Logf("failed decoding test file %s", f)
			t.Logf(err.Error())
			t.FailNow()
		}
		if req.GetPayloadVersion() != 0 {
			t.Logf("wrong payload version. expected 0 but got %d", req.GetPayloadVersion())
			t.FailNow()
		}
		if req == nil {
			t.Log("unmarshal returned empty payload")
			t.FailNow()
		}
	}
}
