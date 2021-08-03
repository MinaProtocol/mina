import axios, { AxiosError } from 'axios';

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
export const verify =
  (oracle: string) =>
  async (
    method: Method,
    url: string,
    params: QueryParams,
    _postData: string
  ): Promise<Response> => {
    // Convert QueryParams to query string
    const qs = new URLSearchParams(params).toString();
    // Temporary URL, Oracle API runs on localhost for now
    const minaOracle =
      qs.length === 0 ? `${oracle}?url=${url}` : `${oracle}?url=${url}&${qs}`;

    let response;
    if (method === 'GET') {
      response = await axios
        .get(minaOracle, { params })
        .catch((error: AxiosError) => {
          return {
            error,
          };
        });
    } else if (method === 'POST') {
      response = await axios.post(minaOracle).catch((error: AxiosError) => {
        return {
          error,
        };
      });
    }
    if (!response.status) {
      const message = JSON.stringify(response);
      return {
        error: Error(message),
      };
    }
    return {
      ok: response.data,
    };
  };
