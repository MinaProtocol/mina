type PublicKey = string;

type Signature = { field: string; scalar: string };

type Signed<Signable> = {
  publicKey: PublicKey;
  signature: Signature;
  payload: Signable;
};

type Method = 'GET' | 'POST';

type QueryParams = {};

type Response = {
  ok?: Signed<string>;
  error?: Error;
};

/**
 * Mocks a response from "HTTPSnapps Oracle API". A successful response will return
 * a code of 200 and a signed payload from an official HTTPSnapps oracle key.
 *
 * @param _method
 * @param _url
 * @param _params
 * @param _postData
 * @returns
 */
export const verify = async (
  _method: Method,
  _url: string,
  _params: QueryParams,
  _postData: string
): Promise<Response> => {
  return {
    ok: {
      publicKey: 'B62qp64aNJnFbUEyPMr8sPC7hBzDELjK7XT7yACMcbGYCfMtZWReJvx',
      signature: {
        field:
          '20431175305150367946844734992985266806108713008193415136916739672441430210571',
        scalar:
          '3134263265420328630089767456663187715829233682017110700619102488905565329549',
      },
      payload: 'hello',
    },
  };
};
