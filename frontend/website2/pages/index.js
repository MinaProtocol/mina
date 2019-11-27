export {make as default} from '@reason/pages/Index'

// getInitialProps example:
// import fetch from 'isomorphic-unfetch'
// import Index from '@reason/pages/Index'
// Index.getInitialProps = async ({ req }) => {
//   const res = await fetch('https://api.github.com/repos/zeit/next.js')
//   const json = await res.json()
//   return { stars: json.stargazers_count }
// }
