pub enum MaybeCompressed<'a> {
    Compressed(Box<[u8]>),
    No(&'a [u8]),
}

impl<'a> AsRef<[u8]> for MaybeCompressed<'a> {
    fn as_ref(&self) -> &[u8] {
        match self {
            MaybeCompressed::Compressed(c) => c,
            MaybeCompressed::No(b) => b,
        }
    }
}

impl MaybeCompressed<'_> {
    pub fn is_compressed(&self) -> bool {
        matches!(self, Self::Compressed(_))
    }
}

#[cfg(not(target_family = "wasm"))]
pub fn compress(bytes: &[u8]) -> std::io::Result<MaybeCompressed> {
    let compressed = {
        let mut result = Vec::<u8>::with_capacity(bytes.len());
        zstd::stream::copy_encode(bytes, &mut result, zstd::DEFAULT_COMPRESSION_LEVEL)?;
        result
    };

    if compressed.len() >= bytes.len() {
        Ok(MaybeCompressed::No(bytes))
    } else {
        Ok(MaybeCompressed::Compressed(compressed.into()))
    }
}

#[cfg(target_family = "wasm")]
pub fn compress(bytes: &[u8]) -> std::io::Result<MaybeCompressed> {
    Ok(MaybeCompressed::No(bytes))
}

#[cfg(not(target_family = "wasm"))]
pub fn decompress(bytes: &[u8], is_compressed: bool) -> std::io::Result<Box<[u8]>> {
    if is_compressed {
        let mut result = Vec::with_capacity(bytes.len() * 2);
        zstd::stream::copy_decode(bytes, &mut result)?;
        Ok(result.into())
    } else {
        Ok(bytes.into())
    }
}

#[cfg(target_family = "wasm")]
pub fn decompress(bytes: &[u8], is_compressed: bool) -> std::io::Result<Box<[u8]>> {
    Ok(bytes.into())
}
