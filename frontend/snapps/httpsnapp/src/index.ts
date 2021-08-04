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
 * Sends either a GET or POST request to the HTTPSnapps Oracle API which will
 * returned a signed response from an official oracle key.
 *
 * @param method    Either `GET` or `POST`
 * @param url       Destination URL to issue the `GET` or `POST` request to
 * @param params    Request Parameters
 * @param postData  Post Data
 * @returns
 */
export const verify =
  (oracle: string) =>
  async (
    method: Method,
    url: string,
    params: QueryParams,
    postData?: string
  ): Promise<Response> => {
    const qs = new URLSearchParams(params).toString();
    const minaOracle =
      qs.length === 0 ? `${oracle}?url=${url}` : `${oracle}?url=${url}&${qs}`;

    let response;
    if (method === 'GET') {
      response = await axios.get(minaOracle).catch((error: AxiosError) => {
        return {
          error,
        };
      });
    } else if (method === 'POST') {
      // TODO: This check is in place as we do not use 'postData' at the moment so we simply return an Error for now.
      if (postData === null) {
        return {
          error: Error('postData is disabled and must be nully for now.'),
        };
      }
      response = await axios
        .post(minaOracle, { params })
        .catch((error: AxiosError) => {
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
