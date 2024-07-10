#[test]
fn outer_iterator() {
    use sprs::{CsMat, CsVec};
    // | 1 0 0 3 1 |
    // | 0 2 0 0 0 |
    // | 0 0 0 1 0 |
    // | 3 0 1 1 0 |
    // | 1 0 0 0 1 |
    let mut mat = CsMat::new_csc(
        (5, 5),
        vec![0, 3, 4, 5, 8, 10],
        vec![0, 3, 4, 1, 3, 0, 2, 3, 0, 4],
        vec![1, 3, 1, 2, 1, 3, 1, 1, 1, 1],
    );

    let mut iter = mat.outer_iterator_mut();

    let first = iter.next().unwrap();
    assert_eq!(
        first.view(),
        CsVec::new(5, vec![0, 3, 4], vec![1, 3, 1]).view()
    );

    let fifth = iter.next_back().unwrap();
    assert_eq!(fifth.view(), CsVec::new(5, vec![0, 4], vec![1, 1]).view());
    let second = iter.next().unwrap();
    assert_eq!(second.view(), CsVec::new(5, vec![1], vec![2]).view());
    let fourth = iter.next_back().unwrap();
    assert_eq!(
        fourth.view(),
        CsVec::new(5, vec![0, 2, 3], vec![3, 1, 1]).view()
    );
    let third = iter.next_back().unwrap();
    assert_eq!(third.view(), CsVec::new(5, vec![3], vec![1]).view());

    assert_eq!(iter.next(), None);
}
