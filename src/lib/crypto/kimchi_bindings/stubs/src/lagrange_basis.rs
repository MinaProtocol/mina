use ark_ec::AffineRepr;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as D};
use cache::LagrangeCache;
use mina_curves::pasta::{Pallas, Vesta};
use poly_commitment::{commitment::CommitmentCurve, srs::SRS};
use std::env;

pub trait WithLagrangeBasis<G: AffineRepr> {
    fn with_lagrange_basis(&mut self, domain: D<G::ScalarField>);
}

impl WithLagrangeBasis<Vesta> for SRS<Vesta> {
    fn with_lagrange_basis(&mut self, domain: D<<Vesta as AffineRepr>::ScalarField>) {
        match env::var("LAGRANGE_CACHE_DIR") {
            Ok(_) => add_lagrange_basis_with_cache(self, domain, cache::get_vesta_file_cache()),
            Err(_) => self.add_lagrange_basis(domain),
        }
    }
}

impl WithLagrangeBasis<Pallas> for SRS<Pallas> {
    fn with_lagrange_basis(&mut self, domain: D<<Pallas as AffineRepr>::ScalarField>) {
        match env::var("LAGRANGE_CACHE_DIR") {
            Ok(_) => add_lagrange_basis_with_cache(self, domain, cache::get_pallas_file_cache()),
            Err(_) => self.add_lagrange_basis(domain),
        }
    }
}

fn add_lagrange_basis_with_cache<G: CommitmentCurve, C: LagrangeCache<G>>(
    srs: &mut SRS<G>,
    domain: D<G::ScalarField>,
    cache: &C,
) {
    let n = domain.size();
    if srs.lagrange_bases.contains_key(&n) {
        return;
    }
    if let Some(basis) = cache.load_lagrange_basis_from_cache(srs.g.len(), &domain) {
        srs.lagrange_bases.insert(n, basis);
        return;
    } else {
        srs.add_lagrange_basis(domain);
        let basis = srs.lagrange_bases.get(&domain.size()).unwrap();
        cache.cache_lagrange_basis(srs.g.len(), &domain, basis);
    }
}

mod cache {
    use ark_ec::AffineRepr;
    use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as D};
    use mina_curves::pasta::{Pallas, Vesta};
    use once_cell::sync::Lazy;
    use poly_commitment::PolyComm;
    use std::{
        env, fs,
        fs::File,
        marker::PhantomData,
        path::{Path, PathBuf},
    };

    pub trait LagrangeCache<G: AffineRepr> {
        type CacheKey;

        fn lagrange_basis_cache_key(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
        ) -> Self::CacheKey;

        fn load_lagrange_basis_from_cache(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
        ) -> Option<Vec<PolyComm<G>>>;

        fn cache_lagrange_basis(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
            basis: &Vec<PolyComm<G>>,
        );
    }

    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct FileCache<G> {
        cache_dir: PathBuf,
        point_type: PhantomData<G>,
    }

    impl<G> FileCache<G> {
        fn new(cache_dir: PathBuf) -> Self {
            FileCache {
                cache_dir,
                point_type: PhantomData,
            }
        }
    }

    /*
    The FileCache implementation uses a directory as a cache for the Lagrange basis hash map --
    i.e every file corresponds to a Lagrange basis for a given G-basis and domain size.
    */
    impl<G: AffineRepr> LagrangeCache<G> for FileCache<G> {
        type CacheKey = PathBuf;

        fn lagrange_basis_cache_key(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
        ) -> Self::CacheKey {
            self.cache_dir.clone().join(format!(
                "lagrange_basis_{:}-{:}",
                srs_length,
                domain.size().to_string()
            ))
        }

        fn load_lagrange_basis_from_cache(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
        ) -> Option<Vec<PolyComm<G>>> {
            let cache_key = self.lagrange_basis_cache_key(srs_length, domain);
            if Path::exists(&cache_key) {
                let f = File::open(cache_key.clone()).expect(&format!(
                    "Missing lagrange basis cache file {:?}",
                    cache_key
                ));
                let basis: Vec<PolyComm<G>> = rmp_serde::decode::from_read(f).expect(&format!(
                    "Error decoding lagrange cache file {:?}",
                    cache_key
                ));
                Some(basis)
            } else {
                None
            }
        }

        fn cache_lagrange_basis(
            &self,
            srs_length: usize,
            domain: &D<G::ScalarField>,
            basis: &Vec<PolyComm<G>>,
        ) {
            let cache_key = self.lagrange_basis_cache_key(srs_length, domain);
            if Path::exists(&cache_key) {
                return;
            } else {
                let mut f = File::create(cache_key.clone()).expect(&format!(
                    "Error creating lagrabnge basis cache file {:?}",
                    cache_key
                ));
                rmp_serde::encode::write(&mut f, basis).expect(&format!(
                    "Error encoding lagrange basis to file {:?}",
                    cache_key
                ));
            }
        }
    }

    // The following two caches are all that we need for mina tests. These will not be initialized unless they are
    // explicitly called.
    static VESTA_FILE_CACHE: Lazy<FileCache<Vesta>> = Lazy::new(|| {
        let cache_base_dir: String =
            env::var("LAGRANGE_CACHE_DIR").expect("LAGRANGE_CACHE_DIR missing in env");
        let cache_dir = PathBuf::from(format!("{}/vesta", cache_base_dir));
        if !cache_dir.exists() {
            fs::create_dir_all(&cache_dir).unwrap();
        }
        FileCache::new(cache_dir)
    });

    pub fn get_vesta_file_cache() -> &'static FileCache<Vesta> {
        &*VESTA_FILE_CACHE
    }

    static PALLAS_FILE_CACHE: Lazy<FileCache<Pallas>> = Lazy::new(|| {
        let cache_base_dir: String =
            env::var("LAGRANGE_CACHE_DIR").expect("LAGRANGE_CACHE_DIR missing in env");
        let cache_dir = PathBuf::from(format!("{}/pallas", cache_base_dir));
        if !cache_dir.exists() {
            fs::create_dir_all(&cache_dir).unwrap();
        }
        FileCache::new(cache_dir)
    });

    pub fn get_pallas_file_cache() -> &'static FileCache<Pallas> {
        &*PALLAS_FILE_CACHE
    }
}
