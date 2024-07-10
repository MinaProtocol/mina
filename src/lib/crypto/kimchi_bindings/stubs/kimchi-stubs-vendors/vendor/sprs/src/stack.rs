/// Stack implementations tuned for the graph traversal algorithms
/// encountered in sparse matrix solves/factorizations
use std::default::Default;
use std::slice;

/// A double stack of fixed capacity, growing from the left to the right
/// or conversely.
///
/// Used in sparse triangular / sparse vector solves, where it is guaranteed
/// that the two parts of the stack cannot overlap.
#[derive(Debug, Clone)]
pub struct DStack<I> {
    stacks: Vec<I>,
    left_head: Option<usize>,
    right_head: usize,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum StackVal<I> {
    Enter(I),
    Exit(I),
}

impl<I: Default> Default for StackVal<I> {
    fn default() -> Self {
        Self::Enter(I::default())
    }
}

impl<I> DStack<I>
where
    I: Clone,
{
    /// Create a new double stacked suited for containing at most n elements
    pub fn with_capacity(n: usize) -> Self
    where
        I: Default,
    {
        assert!(n > 1);
        Self {
            stacks: vec![I::default(); n],
            left_head: None,
            right_head: n,
        }
    }

    /// Capacity of the dstack
    pub fn capacity(&self) -> usize {
        self.stacks.len()
    }

    /// Test whether the left stack is empty
    pub fn is_left_empty(&self) -> bool {
        self.left_head.is_none()
    }

    /// Test whether the right stack is empty
    pub fn is_right_empty(&self) -> bool {
        self.right_head == self.capacity()
    }

    /// Push a value on the left stack
    pub fn push_left(&mut self, value: I) {
        let head = self.left_head.map_or(0, |x| x + 1);
        assert!(head < self.right_head);
        self.stacks[head] = value;
        self.left_head = Some(head);
    }

    /// Push a value on the right stack
    pub fn push_right(&mut self, value: I) {
        self.right_head -= 1;
        if let Some(left_head) = self.left_head {
            assert!(self.right_head > left_head);
        }
        self.stacks[self.right_head] = value;
    }

    /// Pop a value from the left stack
    pub fn pop_left(&mut self) -> Option<I> {
        match self.left_head {
            Some(left_head) => {
                let res = self.stacks[left_head].clone();
                self.left_head = if left_head > 0 {
                    Some(left_head - 1)
                } else {
                    None
                };
                Some(res)
            }
            None => None,
        }
    }

    /// Pop a value from the right stack
    pub fn pop_right(&mut self) -> Option<I> {
        if self.right_head >= self.stacks.len() {
            None
        } else {
            let res = self.stacks[self.right_head].clone();
            self.right_head += 1;
            Some(res)
        }
    }

    /// Number of right elements this double stack contains
    pub fn len_right(&self) -> usize {
        let n = self.stacks.len();
        n - self.right_head
    }

    /// Clear the right stack
    pub fn clear_right(&mut self) {
        self.right_head = self.stacks.len();
    }

    /// Clear the left stack
    pub fn clear_left(&mut self) {
        self.left_head = None;
    }

    /// Iterates along the right stack without removing items
    pub fn iter_right(&self) -> slice::Iter<I> {
        self.stacks[self.right_head..].iter()
    }

    /// Push the values of the left stack onto the right stack.
    pub fn push_left_on_right(&mut self) {
        while let Some(val) = self.pop_left() {
            self.push_right(val);
        }
    }

    /// Push the values of the right stack onto the left stack.
    pub fn push_right_on_left(&mut self) {
        while let Some(val) = self.pop_right() {
            self.push_left(val);
        }
    }
}

/// Enable extraction of stack val from iterators
pub fn extract_stack_val<I>(stack_val: &StackVal<I>) -> &I {
    match stack_val {
        StackVal::Enter(i) | StackVal::Exit(i) => i,
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_stack_val_default() {
        let val = StackVal::<usize>::default();
        assert_eq!(val, StackVal::<usize>::Enter(0));
    }

    // Testing with_capacity function
    #[test]
    #[should_panic]
    fn test_create_stack_with_not_enough_capacity() {
        let _stack = DStack::<i32>::with_capacity(1);
    }

    #[test]
    fn test_create_empty_stack() {
        const CAPACITY: usize = 10;
        let stack = DStack::<i32>::with_capacity(CAPACITY);
        assert_eq!(stack.stacks.len(), CAPACITY);
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, CAPACITY);
    }

    // Testing capacity function
    #[test]
    fn test_capacity() {
        const CAPACITY: usize = 10;
        let stack = DStack::<i32>::with_capacity(CAPACITY);
        assert_eq!(stack.capacity(), CAPACITY);
    }

    // Testing is_left_empty function
    #[test]
    fn test_is_left_empty_with_empty_stack() {
        let stack = DStack::<i32>::with_capacity(10);
        assert!(stack.is_left_empty());
    }

    #[test]
    fn test_is_left_empty_with_non_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.push_left(3);
        assert!(!stack.is_left_empty());
    }

    #[test]
    fn test_is_left_empty_with_right_non_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.push_right(3);
        assert!(stack.is_left_empty());
    }

    // Testing is_right_empty function
    #[test]
    fn test_is_right_empty_with_empty_stack() {
        let stack = DStack::<i32>::with_capacity(10);
        assert!(stack.is_right_empty());
    }

    #[test]
    fn test_is_right_empty_with_non_empty_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_right(3);
        assert!(!stack.is_right_empty());
    }

    #[test]
    fn test_is_right_empty_with_left_non_empty_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_left(3);
        assert!(stack.is_right_empty());
    }

    // Testing push_left function
    #[test]
    fn test_push_left_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_left(1);
        stack.push_left(2);
        stack.push_left(3);
        assert_eq!(stack.stacks[0], 1);
        assert_eq!(stack.stacks[1], 2);
        assert_eq!(stack.stacks[2], 3);
        assert_eq!(stack.left_head, Some(2));
        assert_eq!(stack.right_head, 3);
    }

    #[test]
    #[should_panic]
    fn test_push_left_more_item_that_capacity_stack() {
        let mut stack = DStack::with_capacity(2);
        stack.push_left(1);
        stack.push_left(2);
        stack.push_left(3);
    }

    // Testing push_right function
    #[test]
    fn test_push_right_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_right(1);
        stack.push_right(2);
        stack.push_right(3);
        assert_eq!(stack.stacks[0], 3);
        assert_eq!(stack.stacks[1], 2);
        assert_eq!(stack.stacks[2], 1);
        assert_eq!(stack.right_head, 0);
        assert_eq!(stack.left_head, None);
    }

    #[test]
    #[should_panic]
    fn test_push_right_more_item_that_capacity_stack() {
        let mut stack = DStack::with_capacity(2);
        stack.push_right(1);
        stack.push_right(2);
        stack.push_right(3);
    }

    // Testing push_left and push_right functions
    #[test]
    fn test_push_left_without_exceeding_right_head_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_left(1);
        stack.push_right(3);
        stack.push_left(2);
        assert_eq!(stack.stacks[0], 1);
        assert_eq!(stack.stacks[1], 2);
        assert_eq!(stack.stacks[2], 3);
        assert_eq!(stack.left_head, Some(1));
        assert_eq!(stack.right_head, 2);
    }

    #[test]
    #[should_panic]
    fn test_push_left_exceeding_right_head_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_right(3);
        stack.push_left(1);
        stack.push_right(2);
        stack.push_left(10);
    }

    #[test]
    fn test_push_right_without_exceeding_left_head_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_right(3);
        stack.push_left(1);
        stack.push_right(2);
        assert_eq!(stack.stacks[0], 1);
        assert_eq!(stack.stacks[1], 2);
        assert_eq!(stack.stacks[2], 3);
        assert_eq!(stack.left_head, Some(0));
        assert_eq!(stack.right_head, 1);
    }

    #[test]
    #[should_panic]
    fn test_push_right_exceeding_left_head_stack() {
        let mut stack = DStack::with_capacity(3);
        stack.push_left(3);
        stack.push_right(1);
        stack.push_left(2);
        stack.push_right(10);
    }

    // Testing pop_left
    #[test]
    fn test_pop_left_on_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        let res = stack.pop_left();
        assert!(matches!(res, None));
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    #[test]
    fn test_pop_left_on_non_empty_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_left(144);
        let res = stack.pop_left();
        assert_eq!(res, Some(144));
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    // Testing pop_right
    #[test]
    fn test_pop_right_on_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        let res = stack.pop_right();
        assert!(matches!(res, None));
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    #[test]
    fn test_pop_right_on_non_empty_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_right(144);
        let res = stack.pop_right();
        assert_eq!(res, Some(144));
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    // Testing len_right function
    #[test]
    fn test_len_right_on_empty_stack() {
        let stack = DStack::<i32>::with_capacity(10);
        assert_eq!(stack.len_right(), 0);
    }

    #[test]
    fn test_len_right_on_full_stack() {
        let mut stack = DStack::<i32>::with_capacity(3);
        stack.push_right(1);
        stack.push_right(2);
        stack.push_left(3);
        assert_eq!(stack.len_right(), 2);
    }

    // Testing clear_right function
    #[test]
    fn test_clear_right_on_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.clear_right();
        assert_eq!(stack.right_head, 10);
        assert_eq!(stack.left_head, None);
    }

    #[test]
    fn test_clear_right_on_full_stack() {
        let mut stack = DStack::<i32>::with_capacity(3);
        stack.push_right(1);
        stack.push_right(2);
        stack.push_left(3);
        stack.clear_right();
        assert_eq!(stack.right_head, 3);
        assert_eq!(stack.left_head, Some(0));
    }

    // Testing clear_left function
    #[test]
    fn test_clear_left_on_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.clear_left();
        assert_eq!(stack.right_head, 10);
        assert_eq!(stack.left_head, None);
    }

    #[test]
    fn test_clear_left_on_full_stack() {
        let mut stack = DStack::<i32>::with_capacity(3);
        stack.push_left(1);
        stack.push_left(2);
        stack.push_right(3);
        stack.clear_left();
        assert_eq!(stack.right_head, 2);
        assert_eq!(stack.left_head, None);
    }

    // Testing iter_right function
    #[test]
    fn test_iter_right_on_empty_stack() {
        let stack = DStack::<i32>::with_capacity(3);
        let mut it = stack.iter_right();
        assert_eq!(it.next(), None);
    }

    #[test]
    fn test_iter_right_on_full_stack() {
        let mut stack = DStack::<i32>::with_capacity(3);
        stack.push_left(1);
        stack.push_left(2);
        stack.push_right(3);
        let mut it = stack.iter_right();
        assert!(matches!(it.next(), Some(3)));
        assert_eq!(it.next(), None);
    }

    // Testing push_left_on_right function
    #[test]
    fn test_push_left_on_right_with_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.push_left_on_right();
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    #[test]
    fn test_push_left_on_right_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_left(1);
        stack.push_left(2);
        stack.push_left(3);
        stack.push_left_on_right();
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 7);
    }

    // Testing push_right_on_left function
    #[test]
    fn test_push_right_on_left_with_empty_stack() {
        let mut stack = DStack::<i32>::with_capacity(10);
        stack.push_right_on_left();
        assert_eq!(stack.left_head, None);
        assert_eq!(stack.right_head, 10);
    }

    #[test]
    fn test_push_right_on_left_stack() {
        let mut stack = DStack::with_capacity(10);
        stack.push_right(1);
        stack.push_right(2);
        stack.push_right(3);
        stack.push_right_on_left();
        assert_eq!(stack.left_head, Some(2));
        assert_eq!(stack.right_head, 10);
    }
}
