import { verify } from '../src';

describe('verify', () => {
  it('should return a signable string', async () => {
    const res = await verify('GET', 'https://example.com', {}, '');
    expect(res.ok.payload).toBeDefined();
  });
});
