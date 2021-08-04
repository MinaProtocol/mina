import MinaSDK from '@o1labs/client-sdk';
import polka from 'polka';
import fetch from 'node-fetch';
import send from '@polka/send-type';
import cors from 'cors';
import { serialize } from 'v8';
import { getCircularReplacer } from './helpers.js';

const PORT = process.env | 3000;
const keys = MinaSDK.genKeys();

polka()
  .use(cors())
  .get('/', async (req, res) => {
    // Bad encoding of query
    if (!'url' in req.query) {
      send(res, 401);
    }
    // Remove circular references so we can serialize the request object
    const requestBytes = serialize(JSON.stringify(req, getCircularReplacer()));

    // Parse out URL and format query string
    const { url, ...params } = req.query;
    const qs = new URLSearchParams(params).toString();

    try {
      const fetchUrl = qs.length === 0 ? url : `${url}?${qs}`;
      // Fetch data and sign response
      const response = await fetch(fetchUrl, { method: 'GET' });
      const jsonData = await response.json();
      const signedData = MinaSDK.signMessage(JSON.stringify(jsonData), keys);

      /* TODO: Currently there is an issue due to a call stack error on our client sdk on large inputs.
          For now, we simply mock the data we intend to send back.
      */
      const mockData = {
        requestBytes,
        publicKey: signedData.publicKey,
        signature: signedData.signature,
        payload: signedData.payload,
      };
      send(res, response.status, mockData);
    } catch (err) {
      const errorCode = 500;
      const error = {
        error: errorCode,
        payload: JSON.stringify(err, Object.getOwnPropertyNames(err)),
      };
      send(res, errorCode, error);
    }
  })
  .post('/', async (req, res) => {
    // Bad encoding of query
    if (!'url' in req.query) {
      send(res, 401);
    }
    // Remove circular references so we can serialize the request object
    const requestBytes = serialize(JSON.stringify(req, getCircularReplacer()));

    const { url, ...params } = req.query;
    try {
      // Fetch data and sign response
      const response = await fetch(url, {
        method: 'POST',
        body: JSON.stringify(params),
      });
      const jsonData = await response.json();
      const signedData = MinaSDK.signMessage(JSON.stringify(jsonData), keys);

      const mockData = {
        requestBytes,
        publicKey: signedData.publicKey,
        signature: signedData.signature,
        payload: signedData.payload,
      };
      send(res, response.status, mockData);
    } catch (err) {
      const errorCode = 500;
      const error = {
        error: errorCode,
        payload: JSON.stringify(err, Object.getOwnPropertyNames(err)),
      };
      send(res, errorCode, error);
    }
  })
  .listen(PORT, () => {
    console.log(`> Running on localhost:${PORT}`);
  });
