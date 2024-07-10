//! Error type for sprs

#[derive(PartialEq, Eq, Debug, Copy, Clone)]
pub enum StructureError {
    Unsorted(&'static str),
    SizeMismatch(&'static str),
    OutOfRange(&'static str),
}

#[derive(PartialEq, Eq, Debug, Copy, Clone)]
#[non_exhaustive]
pub enum StructureErrorKind {
    Unsorted,
    SizeMismatch,
    OutOfRange,
}

impl StructureError {
    pub fn kind(&self) -> StructureErrorKind {
        match self {
            StructureError::Unsorted(_) => StructureErrorKind::Unsorted,
            StructureError::SizeMismatch(_) => StructureErrorKind::SizeMismatch,
            StructureError::OutOfRange(_) => StructureErrorKind::OutOfRange,
        }
    }

    fn kind_str(&self) -> &str {
        match self {
            StructureError::Unsorted(_) => "unsorted",
            StructureError::SizeMismatch(_) => "size mismatch",
            StructureError::OutOfRange(_) => "out of range",
        }
    }

    fn msg(&self) -> &str {
        match self {
            StructureError::Unsorted(s)
            | StructureError::SizeMismatch(s)
            | StructureError::OutOfRange(s) => s,
        }
    }
}

impl std::fmt::Display for StructureError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "Structure Error ({}): {}", self.kind_str(), self.msg())
    }
}

impl std::error::Error for StructureError {}

#[derive(PartialEq, Eq, Debug, Copy, Clone)]
pub struct ShapeMismatchInfo {
    pub expected: (usize, usize),
    pub received: (usize, usize),
}

#[derive(PartialEq, Eq, Debug, Copy, Clone)]
pub struct SingularMatrixInfo {
    pub index: usize,
    pub reason: &'static str,
}

#[derive(PartialEq, Eq, Debug, Clone)]
#[non_exhaustive]
pub enum LinalgError {
    ShapeMismatch(ShapeMismatchInfo),
    NonSquareMatrix,
    SingularMatrix(SingularMatrixInfo),
    ThirdPartyError(isize, &'static str),
}

impl std::fmt::Display for LinalgError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            LinalgError::ShapeMismatch(shapes) => {
                write!(
                    f,
                    "Shape mismatch: expected ({}, {}), got ({}, {})",
                    shapes.expected.0,
                    shapes.expected.1,
                    shapes.received.0,
                    shapes.received.1,
                )
            }
            LinalgError::NonSquareMatrix => write!(f, "Non square matrix"),
            LinalgError::SingularMatrix(info) => {
                write!(
                    f,
                    "Singular matrix at index {} ({})",
                    info.index, info.reason,
                )
            }
            LinalgError::ThirdPartyError(code, msg) => {
                write!(f, "Third party error: {msg} (code {code})",)
            }
        }
    }
}

impl std::error::Error for LinalgError {}

/// Convenience wrapper around more precise error types. Not returned by
/// functions in this crate, but can be easily obtained from any error
/// returned in this crate using `Into` and `From`.
#[derive(PartialEq, Eq, Debug, Clone)]
#[non_exhaustive]
pub enum SprsError {
    Structure(StructureError),
    Linalg(LinalgError),
}

impl From<StructureError> for SprsError {
    fn from(e: StructureError) -> Self {
        Self::Structure(e)
    }
}

impl From<LinalgError> for SprsError {
    fn from(e: LinalgError) -> Self {
        Self::Linalg(e)
    }
}

impl std::fmt::Display for SprsError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Self::Structure(e) => write!(f, "Structure error: {e}"),
            Self::Linalg(e) => write!(f, "Linalg error: {e}"),
        }
    }
}

impl std::error::Error for SprsError {}
