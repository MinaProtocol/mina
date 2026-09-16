use nix::sys::signal;
use nix::unistd::Pid;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    io,
    path::{Path, PathBuf},
};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ProcessRecord {
    pub pid: u32,
    pub service_name: String,
    pub started_at: String,
    pub log_file: PathBuf,
    pub config_dir: PathBuf,
}

pub struct ProcessTracker {
    path: PathBuf,
}

#[allow(dead_code)]
impl ProcessTracker {
    pub fn new(network_path: &Path) -> Self {
        ProcessTracker {
            path: network_path.join("processes.json"),
        }
    }

    pub fn load(&self) -> io::Result<HashMap<String, ProcessRecord>> {
        if !self.path.exists() {
            return Ok(HashMap::new());
        }
        let data = std::fs::read_to_string(&self.path)?;
        let records: HashMap<String, ProcessRecord> = serde_json::from_str(&data)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        Ok(records)
    }

    pub fn save(&self, records: &HashMap<String, ProcessRecord>) -> io::Result<()> {
        let data = serde_json::to_string_pretty(records).map_err(io::Error::other)?;
        std::fs::write(&self.path, data)
    }

    pub fn add(&self, record: ProcessRecord) -> io::Result<()> {
        let mut records = self.load()?;
        records.insert(record.service_name.clone(), record);
        self.save(&records)
    }

    pub fn remove(&self, service_name: &str) -> io::Result<()> {
        let mut records = self.load()?;
        records.remove(service_name);
        self.save(&records)
    }

    pub fn get(&self, service_name: &str) -> io::Result<Option<ProcessRecord>> {
        let records = self.load()?;
        Ok(records.get(service_name).cloned())
    }

    pub fn list(&self) -> io::Result<HashMap<String, ProcessRecord>> {
        self.load()
    }

    pub fn is_alive(pid: u32) -> bool {
        signal::kill(Pid::from_raw(pid as i32), None).is_ok()
    }
}
