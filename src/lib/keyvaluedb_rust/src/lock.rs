use std::{fs::File, path::Path};

pub struct LockedFile {
    file: File,
}

impl Drop for LockedFile {
    fn drop(&mut self) {
        let _ = sys::unlock(&self.file);
    }
}

impl std::ops::Deref for LockedFile {
    type Target = File;

    fn deref(&self) -> &Self::Target {
        &self.file
    }
}

impl std::ops::DerefMut for LockedFile {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.file
    }
}

impl std::io::Write for LockedFile {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.file.write(buf)
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.file.flush()
    }
}

impl std::io::Read for LockedFile {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.file.read(buf)
    }
}

impl std::io::Seek for LockedFile {
    fn seek(&mut self, to: std::io::SeekFrom) -> std::io::Result<u64> {
        self.file.seek(to)
    }
}

impl LockedFile {
    pub fn try_open_exclusively(
        filename: &Path,
        open_options: &std::fs::OpenOptions,
    ) -> std::io::Result<Self> {
        let file = open_options.open(filename)?;
        sys::try_lock_exclusive(&file)?;

        Ok(Self { file })
    }
}

#[cfg(unix)]
mod sys {
    use std::fs::File;
    use std::os::unix::io::AsRawFd;

    fn flock(file: &File, flag: libc::c_int) -> std::io::Result<()> {
        let ret = unsafe { libc::flock(file.as_raw_fd(), flag) };

        if ret < 0 {
            let error = std::io::Error::last_os_error();

            match error.kind() {
                std::io::ErrorKind::Unsupported => Ok(()), // Succeed when `flock` is not supported
                _ => Err(error),
            }
        } else {
            Ok(())
        }
    }

    pub(super) fn try_lock_exclusive(file: &File) -> std::io::Result<()> {
        flock(file, libc::LOCK_EX | libc::LOCK_NB).map_err(|e| {
            std::io::Error::new(
                std::io::ErrorKind::WouldBlock,
                format!("Unable to lock the file: {:?}", e),
            )
        })
    }

    pub(super) fn unlock(file: &File) -> std::io::Result<()> {
        flock(file, libc::LOCK_UN).map_err(|e| {
            std::io::Error::new(
                std::io::ErrorKind::WouldBlock,
                format!("Unable to unlock the file: {:?}", e),
            )
        })
    }
}

#[cfg(windows)]
mod sys {
    use std::fs::File;
    use std::mem;
    use std::os::windows::io::AsRawHandle;

    use windows_sys::Win32::Foundation::HANDLE;
    use windows_sys::Win32::Storage::FileSystem::{
        LockFileEx, UnlockFile, LOCKFILE_EXCLUSIVE_LOCK, LOCKFILE_FAIL_IMMEDIATELY,
    };

    pub(super) fn try_lock_exclusive(file: &File) -> std::io::Result<()> {
        let flags = LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY;

        let ret = unsafe {
            let mut overlapped = mem::zeroed();
            LockFileEx(
                file.as_raw_handle() as HANDLE,
                flags,
                0,
                !0,
                !0,
                &mut overlapped,
            )
        };

        if ret == 0 {
            let error = std::io::Error::last_os_error();

            match error.kind() {
                std::io::ErrorKind::Unsupported => Ok(()), // Succeed when `flock` is not supported
                _ => Err(error),
            }
        } else {
            Ok(())
        }
    }

    pub(super) fn unlock(file: &File) -> Result<()> {
        let ret = unsafe { UnlockFile(file.as_raw_handle() as HANDLE, 0, 0, !0, !0) };

        if ret == 0 {
            Err(std::io::Error::last_os_error())
        } else {
            Ok(())
        }
    }
}

#[cfg(not(any(unix, windows)))]
mod sys {
    pub(super) fn try_lock_exclusive(file: &File) -> std::io::Result<()> {
        Ok(())
    }

    pub(super) fn unlock(file: &File) -> std::io::Result<()> {
        OK(())
    }
}
