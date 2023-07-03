package delegation_backend

import (
	"testing"

	"golang.org/x/crypto/blake2b"
)

func testVerifySig(pkStr string, sigStr string, data []byte, t *testing.T) {
	var pk Pk
	var sig Sig
	if err := StringToSig(&sig, sigStr); err != nil {
		t.Logf("Error parsing sig: %s", sigStr)
		t.FailNow()
	}
	if err := StringToPk(&pk, pkStr); err != nil {
		t.Logf("Error parsing pk: %s", pkStr)
		t.FailNow()
	}
	if !verifySig(&pk, &sig, data, 1) {
		t.FailNow()
	}
}

func testVerifyRequest(name string, networkId uint8, t *testing.T) {
	body := readTestFile(name, t)
	var req submitRequest
	var err error
	req, err = unmarshalPayload(body)
	if err != nil {
		t.Log("failed decoding test file")
		t.FailNow()
	}
	j, err := req.GetData().MakeSignPayload()
	if err != nil {
		t.Log("failed making sign test file")
		t.FailNow()
	}
	hash := blake2b.Sum256(j)
	t.Logf("sign payload:\n%s", j)
	submitter := req.GetSubmitter()
	sig := req.GetSig()
	if !verifySig(&submitter, &sig, hash[:], networkId) {
		t.Log("signature verification failed")
		t.FailNow()
	}
}

const PK1 = "B62qkaKV3BLvLTf7nYXRehSaZAd36NWijt3MEmy2QgHRavboeRGtBMN"
const SIG1 = "7mX7qCqaB8G5ry12EkqY9fcE6np8sdF1Kg3Hac77bRhwGq5PTBLEiNveEXn7oLgFs1dmxXyGwn5iCunBhamjNjrzNEdoJhwd"

func TestVerifySig1(t *testing.T) {
	testVerifySig(PK1, SIG1, []byte{0, 0}, t)
}

const PK2 = "B62qn4kByk45GFDMHwVf2smYEVTehGN638UBHMaQzyLJf52wtdtCjRA"
const SIG2 = "7mXTf2BWNYSPuKGa3LT4ywcNH4EAqY5YoaasShG4Dpm44oJZMu1BZmVuGGqeDbfxUhvt2UcPZgSSQcv567dFueK22JoHndk9"

func TestVerifySig2(t *testing.T) {
	testVerifySig(PK2, SIG2, []byte{0x80}, t)
}

const PK3 = "B62qkgvrx8WoDqTzXaUm2vqBRbkiqTts35Z9n4XcrFez1KG3MHKHTbn"
const SIG3 = "7mX6xdEWghp5vhuV33h1o4n8PQ8RYYMGNEwUXxk3rPm8inZ72Yxjw9zhvc3mtkFPnGAbqy3rxBYXdFrVBt9YbKzRKZ1RLLeC"

func TestVerifySig3(t *testing.T) {
	testVerifySig(PK3, SIG3, []byte{0xFF}, t)
}

const PK4 = "B62qoJC4KuLXgTEX2uwQGPNZSnqRTvJHzcEzkWTDFTXMsqdXPNKxJLs"
const SIG4 = "7mXHTjT2Rbt2L2u8uqdtXcLP4iKPLtDAQ1qhfGhuFAjCzc85T6yAuhVndh8pnuhdQqRrz2x2G6uFJUdfCYdJFUWNgEb6g9zH"

func TestVerifySig4(t *testing.T) {
	body := readTestFile("payload-no-snark", t)
	hash := blake2b.Sum256(body)
	testVerifySig(PK4, SIG4, hash[:], t)
}

const PK5 = "B62qoJC4KuLXgTEX2uwQGPNZSnqRTvJHzcEzkWTDFTXMsqdXPNKxJLs"
const SIG5 = "7mX9wQokYSpqabWdsD8neahB1DEHeeYwHdsw9d5ADTcLgwN6pjXCshM7p8pySiFF8epxk4mvxa8fmwTQu7tjjg3UUSzSBTwA"

func TestVerifySig5(t *testing.T) {
	body := readTestFile("payload-with-snark", t)
	hash := blake2b.Sum256(body)
	testVerifySig(PK5, SIG5, hash[:], t)
}

func TestVerifyRequest1(t *testing.T) {
	testVerifyRequest("req-with-snark", 1, t)
}

func TestVerifyRequest2(t *testing.T) {
	testVerifyRequest("req-no-snark", 1, t)
}

func TestVerifyRequestV1(t *testing.T) {
	testVerifyRequest("req-v1-with-snark", 0, t)
}
