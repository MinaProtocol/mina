import MinaSDK from '@o1labs/client-sdk';
import polka from 'polka';
import fetch from 'node-fetch';
import send from '@polka/send-type';
import cors from 'cors';

const PORT = process.env | 3000;
const keys = MinaSDK.genKeys();

polka()
  .use(cors())
  .get('/', async (req, res) => {
    // Bad encoding of query
    if (!'url' in req.query) {
      send(res, 401);
    }

    // Parse out URL and format query string
    const { url, ...params } = req.query;
    const qs = new URLSearchParams(params).toString();

    try {
      const fetchUrl = qs.length === 0 ? url : `${url}?${qs}`;
      const data = await fetch(fetchUrl, { method: 'GET' });
      const jsonData = await data.json();
      const signedData = MinaSDK.signMessage(JSON.stringify(jsonData), keys);
      send(res, data.status, signedData);
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

    const { url, ...params } = req.query;

    try {
      const data = await fetch(url, {
        method: 'POST',
        body: JSON.stringify(params),
      });
      const jsonData = await data.json();
      const signedData = MinaSDK.signMessage(JSON.stringify(jsonData), keys);
      send(res, data.status, signedData);
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
