import * as Src from '../src';
import * as SchnorrSign from '../src/examples/schnorr_sign';

const timeout = (ms: number) => {
  return new Promise((resolve, _) => {
    let wait = setTimeout(() => {
      clearTimeout(wait);
      resolve('');
    }, ms);
  });
};

describe('five', () => {
  console.log(SchnorrSign.Main);
  it('is five', async () => {
    await timeout(1000);
    SchnorrSign.main();
    expect(Src.five).toEqual(5);
  });
});
