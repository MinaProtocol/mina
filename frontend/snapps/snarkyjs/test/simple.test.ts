import { five } from '../src';
import { Main, main } from '../src/examples/schnorr_sign';

const timeout = (ms : number) => {
  return new Promise((resolve, _) => {
    let wait = setTimeout(() => {
      clearTimeout(wait);
      resolve('');
    }, ms)
  })
};

describe('five', () => {
  console.log(Main);
  it('is five', async () => {
    await timeout(1000);
    main();
    expect(five).toEqual(5);
  });
});
