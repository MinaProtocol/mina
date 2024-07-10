#[cfg(feature = "serde")]
#[test]
fn serialize() {
    use sprs::{CsMat, CsVecI};
    let v = CsVecI::new(5, vec![0_i32, 2, 4], vec![1., 2., 3.]);
    let serialized = bincode::serialize(&v.view()).unwrap();
    let deserialized = bincode::deserialize(&serialized).unwrap();
    assert_eq!(v, deserialized);

    let m: CsMat<f32> = CsMat::<f32>::eye(3);
    let serialized = bincode::serialize(&m.view()).unwrap();
    let deserialized = bincode::deserialize::<CsMat<f32>>(&serialized).unwrap();
    assert_eq!(m, deserialized);
}
