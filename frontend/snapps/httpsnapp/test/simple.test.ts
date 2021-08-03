import * as HttpSnapps from '../src';
const verify = HttpSnapps.verify('http://localhost:3000');

describe('verify', () => {
  describe('GET', () => {
    it('should return a public key', async () => {
      const res = await verify(
        'GET',
        'https://jsonplaceholder.typicode.com/posts/1',
        {},
        ''
      );
      expect(res.ok.publicKey).toBeDefined();
    });
    it('should return a signature', async () => {
      const res = await verify(
        'GET',
        'https://jsonplaceholder.typicode.com/posts/1',
        {},
        ''
      );
      expect(res.ok.signature).toBeDefined();
    });
    it('should return a payload', async () => {
      const res = await verify(
        'GET',
        'https://jsonplaceholder.typicode.com/posts/1',
        {},
        ''
      );
      expect(res.ok.payload).toBeDefined();
    });
    it('should fail with an invalid URL', async () => {
      const res = await verify(
        'GET',
        'https://jsonplaceholder.typicode.com/posts/0',
        {},
        ''
      );
      expect(res.error).toBeDefined();
    });
  });
  describe('POST', () => {
    it('should return a public key', async () => {
      const res = await verify(
        'POST',
        'https://jsonplaceholder.typicode.com/posts',
        {
          title: 'foo',
          body: 'bar',
          userId: 1,
        },
        ''
      );
      expect(res.ok.publicKey).toBeDefined();
    });
    it('should return a signature', async () => {
      const res = await verify(
        'POST',
        'https://jsonplaceholder.typicode.com/posts',
        {
          title: 'foo',
          body: 'bar',
          userId: 1,
        },
        ''
      );
      expect(res.ok.signature).toBeDefined();
    });
    it('should return a payload', async () => {
      const res = await verify(
        'POST',
        'https://jsonplaceholder.typicode.com/posts',
        {
          title: 'foo',
          body: 'bar',
          userId: 1,
        },
        ''
      );
      expect(res.ok.payload).toBeDefined();
    });
    it('should fail with an invalid URL', async () => {
      const res = await verify(
        'POST',
        'https://jsonplaceholder.typicode.com/post',
        {
          title: 'foo',
          body: 'bar',
          userId: 1,
        },
        ''
      );
      expect(res.error).toBeDefined();
    });
  });
});
