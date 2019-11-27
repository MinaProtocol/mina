export { make as default} from '@reason/pages/BlogPost'

// TODO: try shallow routing?


// const { createClient } = require('contentful');
// const SPACE = process.env.CONTENTFUL_SPACE || '37811siqosrn';
// const TOKEN = process.env.CONTENTFUL_TOKEN || 'gONaARVCc0G5FLIkoJ2m4qi9yTpT8oi7u-C6VYxQ6UQ';

// let contentResponse = await client.getEntries({
//   include: 0,
//   content_type: test, // This is a blog
// });

// Required to avoid flash of missing content
// as described in https://github.com/zeit/next.js/issues/8863
// make.getInitialProps = async ({query}) => {
// };

// export default withContentful({
//   accessToken: TOKEN,
//   space: SPACE,
// })(make);
