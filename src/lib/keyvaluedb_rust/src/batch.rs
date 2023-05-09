use super::{Key, Value};

pub(super) enum Action {
    Set(Key, Value),
    Remove(Key),
}

pub struct Batch {
    actions: Vec<Action>,
}

impl Batch {
    pub fn new() -> Self {
        Self {
            actions: Vec::with_capacity(32),
        }
    }

    pub fn set(&mut self, key: Key, value: Value) {
        self.actions.push(Action::Set(key, value));
    }

    pub fn remove(&mut self, key: Key) {
        self.actions.push(Action::Remove(key));
    }

    pub(super) fn take(&mut self) -> Vec<Action> {
        std::mem::take(&mut self.actions)
    }
}
