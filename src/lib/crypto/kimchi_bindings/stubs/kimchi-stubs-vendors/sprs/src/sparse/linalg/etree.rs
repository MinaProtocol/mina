///! Data structures to work with elimination trees (etree).
///! etrees arise when considering cholesky factorization, QR factorization, ...
use std::ops::{Deref, DerefMut};

pub type Parent = Option<usize>;

/// Store an etree as the parent information of each node.
/// This reflects the fact that etrees can in fact have multiple roots.
#[derive(Debug, Clone)]
pub struct Parents<S>
where
    S: Deref<Target = [Parent]>,
{
    parents: S,
}

pub type ParentsView<'a> = Parents<&'a [Parent]>;
pub type ParentsViewMut<'a> = Parents<&'a mut [Parent]>;
pub type ParentsOwned = Parents<Vec<Parent>>;

impl<S: Deref<Target = [Parent]>> Parents<S> {
    /// Get the parent of a node. Returns None if the node is a root.
    ///
    /// # Panics
    ///
    /// * if node is out of bounds
    pub fn get_parent(&self, node: usize) -> Option<usize> {
        self.parents[node]
    }

    /// Test whether a node is a root.
    ///
    /// # Panics
    ///
    /// * if node is out of bounds
    pub fn is_root(&self, node: usize) -> bool {
        self.parents[node].is_none()
    }

    /// The number of nodes in this tree.
    pub fn nb_nodes(&self) -> usize {
        self.parents.len()
    }

    /// Get a view of this object
    pub fn view(&self) -> ParentsView {
        ParentsView {
            parents: &self.parents[..],
        }
    }
}

impl<S: DerefMut<Target = [Parent]>> Parents<S> {
    /// Set the parent of a node.
    ///
    /// # Panics
    ///
    /// * if node is out of bounds
    /// * if parent is out of bounds
    pub fn set_parent(&mut self, node: usize, parent: usize) {
        assert!(parent < self.nb_nodes(), "parent is out of bounds");
        self.parents[node] = Some(parent);
    }

    /// Set a node as a root.
    ///
    /// # Panics
    ///
    /// * if node is out of bounds
    pub fn set_root(&mut self, node: usize) {
        self.parents[node] = None;
    }

    /// Give a parent to a root of the tree. No-op if the node was not a parent.
    ///
    /// # Panics
    ///
    /// if either node or parent is out of bounds
    pub fn uproot(&mut self, node: usize, parent: usize) {
        assert!(parent < self.nb_nodes(), "parent is out of bounds");
        if self.is_root(node) {
            self.set_parent(node, parent);
        }
    }

    pub fn view_mut(&mut self) -> ParentsViewMut {
        ParentsViewMut {
            parents: &mut self.parents[..],
        }
    }
}

impl ParentsOwned {
    /// Create a new tree with all nodes set as root
    pub fn new(nb_nodes: usize) -> Self {
        Self {
            parents: vec![None; nb_nodes],
        }
    }
}
