import fetch from 'node-fetch';

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
 * Currently, WIP. Sends either a GET or POST request to the HTTPSnapps Oracle API which will
 * returned a signed response from an official oracle key.
 *
 * @param _method
 * @param _url
 * @param _params
 * @param _postData
 * @returns
 */
export const verify = async (
  method: Method,
  url: string,
  params: QueryParams,
  _postData: string
): Promise<Response> => {
  // Convert QueryParams to query string
  const qs = new URLSearchParams(params).toString();
  // Temporary URL, Oracle API runs on localhost for now
  const minaOracle =
    qs.length === 0
      ? `http://localhost:3000?url=${url}`
      : `http://localhost:3000?url=${url}&${qs}`;

  let response;
  if (method === 'GET') {
    response = await fetch(minaOracle, { method: 'GET' }).catch((err) => {
      return {
        error: err,
      };
    });
  } else if (method === 'POST') {
    response = await fetch(minaOracle, { method: 'POST' }).catch((err) => {
      return {
        error: err,
      };
    });
  }

  if (!response.ok) {
    const message = `An error has occured: ${response.status}`;
    return {
      error: Error(message),
    };
  }
  const resJson = await response.json();
  return {
    ok: resJson,
  };
};
