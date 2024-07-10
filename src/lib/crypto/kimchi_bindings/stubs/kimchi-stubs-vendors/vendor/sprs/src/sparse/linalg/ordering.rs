use crate::indexing::SpIndex;
use crate::sparse::permutation::PermOwnedI;
use crate::sparse::symmetric::is_symmetric;
use crate::sparse::CsMatViewI;
use std::collections::vec_deque::VecDeque;

pub struct Ordering<I> {
    /// The computed permutation
    pub perm: PermOwnedI<I>,
    /// Indices inside the permutation delimiting connected components
    pub connected_parts: Vec<usize>,
}

pub mod start {
    use crate::indexing::SpIndex;
    use crate::sparse::CsMatViewI;

    /// This trait abstracts over possible strategies to choose a starting
    /// vertex for the Cutihll-McKee algorithm. Common strategies are provided.
    ///
    /// You can implement this trait yourself to enable custom strategies,
    /// e.g. for predetermined starting vertices.
    /// If you do that, please let us now by filing an issue in the repo,
    /// since we would like to know which strategies are common in the wild,
    /// so we can consider implementing them in the library.
    pub trait Strategy<N, I, Iptr>
    where
        N: PartialEq,
        I: SpIndex,
        Iptr: SpIndex,
    {
        /// **Contract:** This function must always be called with at least one
        /// unvisited vertex left.
        fn find_start_vertex(
            &mut self,
            visited: &[bool],
            degrees: &[usize],
            mat: &CsMatViewI<N, I, Iptr>,
        ) -> usize;
    }

    /// This strategy chooses some next available vertex as starting vertex.
    pub struct Next();

    impl<N, I, Iptr> Strategy<N, I, Iptr> for Next
    where
        N: PartialEq,
        I: SpIndex,
        Iptr: SpIndex,
    {
        fn find_start_vertex(
            &mut self,
            visited: &[bool],
            _degrees: &[usize],
            _mat: &CsMatViewI<N, I, Iptr>,
        ) -> usize {
            visited
                .iter()
                .enumerate()
                .find_map(|(i, &a)| if a { None } else { Some(i) })
                .expect(
                    "There should always be a unvisited vertex left to choose",
                )
        }
    }

    /// This strategy chooses a vertex of minimum degree as starting vertex.
    pub struct MinimumDegree();

    impl<N, I, Iptr> Strategy<N, I, Iptr> for MinimumDegree
    where
        N: PartialEq,
        I: SpIndex,
        Iptr: SpIndex,
    {
        fn find_start_vertex(
            &mut self,
            visited: &[bool],
            degrees: &[usize],
            _mat: &CsMatViewI<N, I, Iptr>,
        ) -> usize {
            visited
                .iter()
                .enumerate()
                .filter(|(_i, &a)| !a)
                .min_by_key(|(i, _a)| degrees[*i])
                .map(|(i, _a)| i)
                .expect(
                    "There should always be a unvisited vertex left to choose",
                )
        }
    }

    /// This strategy employs an pseudoperipheral vertex finder as described by
    /// George and Liu.  It is the most expensive strategy to compute, but
    /// typically results in the narrowest bandwidth.
    #[derive(Default)]
    pub struct PseudoPeripheral();

    impl PseudoPeripheral {
        #[inline]
        pub fn new() -> Self {
            Self::default()
        }

        /// Computes the rooted level structure rooted at `root`, returning the
        /// index of vertex of the last level with minimum degree, called
        /// "contender", and the height of the rls.
        fn rls_contender_and_height<N, I, Iptr>(
            &mut self,
            root: usize,
            degrees: &[usize],
            mat: &CsMatViewI<N, I, Iptr>,
        ) -> (usize, usize)
        where
            N: PartialEq,
            I: SpIndex,
            Iptr: SpIndex,
        {
            // One might wonder: "Why are we not reusing the rooted level
            // structure (rls) we build here, isn't it basically the same thing
            // we build in the rcm again, afterwards?""
            // The answer: Yes, but, No.
            //
            // The rooted level structure here differs from the one built
            // afterwards by its order.  The required order is very nasty
            // indeed: the position of a vertex in its level depends primarily
            // on the position of its neighboring vertex in the previous level,
            // and secondarily on its degree.
            //
            // Still, one may think: "Well, then just keep the rls around, and
            // sort it if its root is choosen as starting vertex".  This is
            // easier said than done, let's consider some strategies to do that:
            // 1. Sort it without any additionally stored information. That
            //    would require going through the entire vec again, one by one.
            //    This would erase the overhead of allocating and then
            //    deallocating the rls, but making this pass performant requires
            //    non-trivial, error-prone code. Overall, this strategies
            //    perfomance gains can at most be minimal.
            // 2. Store additional information, like the delimeters of levels,
            //    neighbouring vertex delimeters, etc.  That would require doing
            //    additional work (computing and storing the information) while
            //    building the rls, and does not speed up sorting afterwards
            //    significantly, as the levels still need to be sorted serially.
            //    Overall, this strategy comes at a significant cost in memory,
            //    and it's performance improvements are debatable at best.
            // 3. Maybe just build any rls in a way that makes it a valid rcm
            //    odering?  That would be optimal if we always find a
            //    pseudoperipheral vertex on first try. Unfortunately, we rarely
            //    do, typical are a few swaps, meaning this strategy, overall,
            //    comes with a loss of performance.
            //
            // So, thats why we discard the rls. One may feel free to try on his
            // own.

            let nb_vertices = degrees.len();

            // This is ok, if we are given a valid root we can never reach an
            // invalid vertex.
            let mut visited = vec![false; nb_vertices];

            let mut rls = Vec::with_capacity(nb_vertices);

            // Start out by pushing the root.
            visited[root] = true;
            rls.push(root);

            let mut rls_index = 0;

            // For calculating the height.
            let mut height = 0;
            let mut current_level_countdown = 1;
            let mut next_level_countup = 0;

            // The last levels len is used to compute the contender in the end.
            let mut last_level_len = 1;

            while rls_index < rls.len() {
                let parent = rls[rls_index];
                current_level_countdown -= 1;

                let outer = mat.outer_view(parent.index()).unwrap();
                for &neighbor in outer.indices() {
                    if !visited[neighbor.index()] {
                        visited[neighbor.index()] = true;
                        next_level_countup += 1;
                        rls.push(neighbor.index());
                    }
                }

                if current_level_countdown == 0 {
                    if next_level_countup > 0 {
                        last_level_len = next_level_countup;
                    }

                    current_level_countdown = next_level_countup;
                    next_level_countup = 0;
                    height += 1;
                }

                rls_index += 1;
            }

            // Choose the contender.
            let rls_len = rls.len();
            let last_level_start_index = rls_len - last_level_len;
            let contender = rls[last_level_start_index..rls_len]
                .iter()
                .min_by_key(|i| degrees[i.index()])
                .copied()
                .unwrap();

            // Return the node of the last level with minimal degree along with
            // the rls's height.
            (contender, height)
        }
    }

    impl<N, I, Iptr> Strategy<N, I, Iptr> for PseudoPeripheral
    where
        N: PartialEq,
        I: SpIndex,
        Iptr: SpIndex,
    {
        fn find_start_vertex(
            &mut self,
            visited: &[bool],
            degrees: &[usize],
            mat: &CsMatViewI<N, I, Iptr>,
        ) -> usize {
            // Choose the next available vertex as currrent starting vertex.
            let mut current = visited
                .iter()
                .enumerate()
                .find_map(|(i, &a)| if a { None } else { Some(i) })
                .expect(
                    "There should always be a unvisited vertex left to choose",
                );

            // Isolated vertices are by definition pseudoperipheral.
            if degrees[current] == 0 {
                return current;
            }

            let (mut contender, mut current_height) =
                self.rls_contender_and_height(current, degrees, mat);

            // This loop always terminates, typically within very few
            // iterations.
            // This essentially comes from the fact that no same vertex can be
            // choosen as `current` twice, as the height of the rls of `current`
            // must always strictly increase for the loop to continue.
            loop {
                let (contender_contender, contender_height) =
                    self.rls_contender_and_height(contender, degrees, mat);

                if contender_height > current_height {
                    current_height = contender_height;
                    current = contender;
                    contender = contender_contender;
                } else {
                    return current;
                }
            }
        }
    }
}

pub mod order {

    use super::Ordering;
    use crate::indexing::SpIndex;
    use crate::sparse::permutation::PermOwnedI;

    /// This trait is very deeply integrated with the inner workings of the
    /// Cuthill-McKee algorithm implemented here.  It is conceptually only an
    /// enum, specifying if the Cuthill-McKee ordering should be built in
    /// reverse order.
    ///
    /// No method on this trait should ever be called by the consumer.
    //
    // This is a trait, not an enum, because monomorphization is absolutely
    // critical for performance.  Also having the directions manage their state
    // themselves enables some optimizations.
    pub trait DirectedOrdering<I: SpIndex> {
        /// Prepares this directed ordering for working with the specified
        /// number of vertices.
        // Seperated from `fn new`, as it requires `nb_vertices` as parameter,
        // which the consumer would have to supply otherwise, which he can't be
        // trusted to do corretly.
        fn prepare(&mut self, nb_vertices: usize);

        /// Adds a new `vertex_index` as computed in the algorithms main loop.
        fn add_transposition(&mut self, vertex_index: usize);

        /// Adds an index indicating the start of a new connected component.
        fn add_component_delimeter(&mut self, index: usize);

        /// Transforms this directed ordering into an ordering to return from
        /// the algorithm.
        // Actually implementing `From` or `Into` results in coherence errors.
        fn into_ordering(self) -> Ordering<I>;
    }

    /// Indicates the Cuthill-McKee ordering should be built in forward order.
    #[derive(Default)]
    pub struct Forward<I: SpIndex> {
        /// The permutation computed by the algorithm.
        perm: Vec<I>,
        /// Delimeting connected components inside `perm`.
        connected_parts: Vec<usize>,
    }

    impl<I: SpIndex> Forward<I> {
        /// Creates a new instance of this conceptual enum variant.
        #[inline]
        pub fn new() -> Self {
            Self::default()
        }
    }

    impl<I: SpIndex> DirectedOrdering<I> for Forward<I> {
        #[inline]
        fn prepare(&mut self, nb_vertices: usize) {
            self.perm.reserve(nb_vertices);
            self.connected_parts.reserve(nb_vertices / 16 + 1);
        }

        #[inline]
        fn add_transposition(&mut self, vertex_index: usize) {
            self.perm.push(I::from_usize(vertex_index));
        }

        #[inline]
        fn add_component_delimeter(&mut self, index: usize) {
            self.connected_parts.push(index);
        }

        #[inline]
        fn into_ordering(self) -> Ordering<I> {
            debug_assert!(crate::perm_is_valid(&self.perm));
            Ordering {
                perm: PermOwnedI::new_trusted(self.perm),
                connected_parts: self.connected_parts,
            }
        }
    }

    /// Indicates the Cuthill-McKee ordering should be built in reverse order.
    #[derive(Default)]
    pub struct Reversed<I: SpIndex> {
        /// The permutation computed by the algorithm, written in reverse order.
        perm: Vec<I>,
        /// Will be transformed to contain indices delimeting componenets in
        /// `perm`.
        connected_parts: Vec<usize>,
        /// The total number of vertices in the matrix.
        nb_vertices: usize,
        /// Counting with the algorithms main loop, should always be in sync
        /// with `perm_index`.
        // Is a seperate variable to reduce unnecessary argument passing.
        count: usize,
    }

    impl<I: SpIndex> Reversed<I> {
        /// Creates a new instance of this conceptual enum variant.
        // This is not optimal, as it leads to close-to-invalid states if not
        // used correctly.  A solution using some kind of "uninitialized"
        // wrapper type however seems to be overkill, especially since all the
        // uglieness is under the hood and not triggerable unless explicitly
        // asked for.
        #[inline]
        pub fn new() -> Self {
            Self::default()
        }
    }

    impl<I: SpIndex> DirectedOrdering<I> for Reversed<I> {
        #[inline]
        fn prepare(&mut self, nb_vertices: usize) {
            // Missed optimization: Work with MaybeUninit here.
            self.perm = vec![I::default(); nb_vertices];
            self.connected_parts = Vec::with_capacity(nb_vertices / 16 + 1);
            self.nb_vertices = nb_vertices;
        }

        #[inline]
        fn add_transposition(&mut self, vertex_index: usize) {
            self.perm[self.nb_vertices - self.count - 1] =
                I::from_usize(vertex_index);
            self.count += 1;
        }

        #[inline]
        fn add_component_delimeter(&mut self, index: usize) {
            self.connected_parts.push(index);
        }

        #[inline]
        fn into_ordering(self) -> Ordering<I> {
            let nb_vertices = self.nb_vertices;
            let mut connected_parts = self.connected_parts;

            // Reverse-Inverse the connected parts, to fit with the reversed
            // order.
            connected_parts
                .iter_mut()
                .for_each(|i| *i = nb_vertices - *i);
            connected_parts.reverse();

            debug_assert!(crate::perm_is_valid(&self.perm));
            Ordering {
                perm: PermOwnedI::new_trusted(self.perm),
                connected_parts,
            }
        }
    }
}

/// A customized Cuthill-McKee algorithm.
///
/// Runs a customized Cuthill-McKee algorithm on the given matrix, returning a
/// permutation reducing its bandwidth.
///
/// The strategy employed to find starting vertices is critical for the quallity
/// of the reordering computed.  This library implements several common
/// strategies, like `PseudoPeripheral` and `MinimumDegree`, but also allows
/// users to implement custom strategies if needed.
///
/// # Arguments
///
/// - `mat` - The matrix to compute a permutation for.
///
/// - `starting_strategy` - The strategy to use for choosing a starting vertex.
///
/// - `directed_ordering` - The order of the computed ordering, should either be
/// `Forward` or `Reverse`.
pub fn cuthill_mckee_custom<N, I, Iptr, S, D>(
    mat: CsMatViewI<N, I, Iptr>,
    mut starting_strategy: S,
    mut directed_ordering: D,
) -> Ordering<I>
where
    N: PartialEq,
    I: SpIndex,
    Iptr: SpIndex,
    S: start::Strategy<N, I, Iptr>,
    D: order::DirectedOrdering<I>,
{
    debug_assert!(is_symmetric(&mat));
    assert_eq!(mat.cols(), mat.rows());

    let nb_vertices = mat.cols();
    let degrees = mat.degrees();
    let max_neighbors = degrees.iter().max().copied().unwrap_or(0);

    // This will be transformed into the actual `Ordering` in the end,
    // contains the permuntation and component delimeters.
    directed_ordering.prepare(nb_vertices);

    // This is the 'working data', into which new neighboring, sorted vertices
    // are inserted, the next vertex to process is popped from here.
    let mut deque = VecDeque::with_capacity(nb_vertices);

    // This are all new neighbors of the currently processed vertex, they are
    // collected here to be sorted prior to being appended to 'deque'.
    // The alternative of immediately pushing to deque and sorting there
    // surprisingly performs worse.
    let mut neighbors = Vec::with_capacity(max_neighbors);

    // Storing which vertices have already been visited.
    let mut visited = vec![false; nb_vertices];

    for perm_index in 0..nb_vertices {
        // Find the next index to process, choosing a new starting vertex if
        // necessary.
        let current_vertex = deque.pop_front().unwrap_or_else(|| {

            // We found a new connected component, starting at this iteration.
            directed_ordering.add_component_delimeter(perm_index);

            // Find a new starting vertex, using the given strategy.
            let new_start_vertex = starting_strategy.find_start_vertex(
                &visited, &degrees, &mat
            );
            assert!(
                !visited[new_start_vertex],
                "Vertex returned by starting strategy should always be unvisited"
            );

            new_start_vertex
        });

        // Add the next transposition to the ordering.
        directed_ordering.add_transposition(current_vertex);
        visited[current_vertex.index()] = true;

        // Find, sort, and push all new neighbors of the current vertex.
        let outer = mat.outer_view(current_vertex.index()).unwrap();
        neighbors.clear();
        for &neighbor in outer.indices() {
            if !visited[neighbor.index()] {
                neighbors.push((degrees[neighbor.index()], neighbor));
                visited[neighbor.index()] = true;
            }
        }

        // Missed optimization: match small sizes explicitly, sort using sorting
        // networks.  This especially makes sense if swaps are predictably
        // compiled into cmov instructions, which they aren't currently, see
        // https://github.com/rust-lang/rust/issues/53823.  For more information
        // on how to do sorting networks efficiently see
        // https://arxiv.org/pdf/1505.01962.pdf.
        neighbors.sort_unstable_by_key(|&(deg, _)| deg);

        for (_deg, neighbor) in &neighbors {
            deque.push_back(neighbor.index());
        }
    }

    directed_ordering.add_component_delimeter(nb_vertices);

    directed_ordering.into_ordering()
}

/// The reverse Cuthill-McKee algorithm.
///
/// Runs the reverse Cuthill-McKee algorithm on the given matrix, returning a
/// permutation reducing its bandwidth.
///
/// This version of the algorithm chooses pseudoperipheral vertices as starting
/// vertices, and builds a reversed ordering. This is the most common
/// configuration of the algorithm.
///
/// This library also exposes a costomizable version of the algorithm,
/// [`cuthill_mckee_custom`](cuthill_mckee_custom).
///
/// Implemented as:
/// ```text
/// cuthill_mckee_custom(
///     mat, start::PseudoPeripheral::new(), order::Reversed::new()
/// )
/// ```
pub fn reverse_cuthill_mckee<N, I, Iptr>(
    mat: CsMatViewI<N, I, Iptr>,
) -> Ordering<I>
where
    N: PartialEq,
    I: SpIndex,
    Iptr: SpIndex,
{
    cuthill_mckee_custom(
        mat,
        start::PseudoPeripheral::default(),
        order::Reversed::new(),
    )
}

#[cfg(test)]
mod test {
    use super::{cuthill_mckee_custom, order, reverse_cuthill_mckee, start};
    use crate::sparse::permutation::Permutation;
    use crate::sparse::CsMat;

    fn unconnected_graph_lap() -> CsMat<f64> {
        // Take the laplacian matrix of the following graph
        // (no border conditions):
        //
        // 0 - 4 - 2   6
        // | \ | / |   |
        // 8 - 5 - 3   9
        // | / | \ |   |
        // 1 - A - B   7
        //
        // The laplacian matrix structure is (with x = -1)
        //       0 1 2 3 4 5 6 7 8 9 A B
        //     | 3       x x     x       | 0
        //     |   3       x     x   x   | 1
        //     |     3 x x x             | 2
        // L = |     x 3   x           x | 3
        //     | x   x   3 x             | 4
        //     | x x x x x 8     x   x x | 5
        //     |             1     x     | 6
        //     |               1   x     | 7
        //     | x x       x     3       | 8
        //     |             x x   2     | 9
        //     |   x       x         3 x | A
        //     |       x   x         x 3 | B
        let x = -1.;
        #[rustfmt::skip]
        let lap_mat = CsMat::new(
            (12, 12),
            vec![0, 4, 8, 12, 16, 20, 29, 31, 33, 37, 40, 44, 48],
            vec![0, 4, 5, 8,
                 1, 5, 8, 10,
                 2, 3, 4, 5,
                 2, 3, 5, 11,
                 0, 2, 4, 5,
                 0, 1, 2, 3, 4, 5, 8, 10, 11,
                 6, 9,
                 7, 9,
                 0, 1, 5, 8,
                 6, 7, 9,
                 1, 5, 10, 11,
                 3, 5, 10, 11],
            vec![3., x, x, x,
                 3., x, x, x,
                 3., x, x, x,
                 x, 3., x, x,
                 x, x, 3., x,
                 x, x, x, x, x, 8., x, x, x,
                 1., x,
                 1., x,
                 x, x, x, 3.,
                 x, x, 2.,
                 x, x, 3., x,
                 x, x, x, 3.],
        );
        lap_mat
    }

    #[test]
    fn reverse_cuthill_mckee_unconnected_graph_lap_components() {
        let lap_mat = unconnected_graph_lap();
        let ordering = reverse_cuthill_mckee(lap_mat.view());
        assert_eq!(&ordering.connected_parts, &[0, 3, 12],);
    }

    #[test]
    fn reverse_cuthill_mckee_unconnected_graph_lap_perm() {
        let lap_mat = unconnected_graph_lap();
        let ordering = reverse_cuthill_mckee(lap_mat.view());
        // This is just one posible permutation. Might be silently broken, e. g.
        // through changes in unstable sorting.
        let correct_perm =
            Permutation::new(vec![7, 9, 6, 11, 10, 3, 1, 2, 5, 8, 4, 0]);
        assert_eq!(&ordering.perm.vec(), &correct_perm.vec());
    }

    #[test]
    fn reverse_cuthill_mckee_eye() {
        let mat = CsMat::<f64>::eye(3);
        let ordering = reverse_cuthill_mckee(mat.view());
        let correct_perm = Permutation::new(vec![2, 1, 0]);
        assert_eq!(&ordering.perm.vec(), &correct_perm.vec());
    }

    #[test]
    fn cuthill_mckee_eye() {
        let mat = CsMat::<f64>::eye(3);
        let ordering = cuthill_mckee_custom(
            mat.view(),
            start::PseudoPeripheral::new(),
            order::Forward::new(),
        );
        let correct_perm = Permutation::new(vec![0, 1, 2]);
        assert_eq!(&ordering.perm.vec(), &correct_perm.vec());
    }
}
