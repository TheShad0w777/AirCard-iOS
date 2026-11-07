
//! Airlift FFI — C-callable surface for the iOS on-device exploit.
//!
//! Exports:
//!   al_log_init
//!   al_pairing_run_host
//!   al_pairing_result_free
//!   al_exploit_run
//!   al_afc_list_directory
//!   al_string_free

use std::ffi::{c_char, c_void};

pub mod exploit;
pub mod ffi_util;
pub mod grappa;
pub mod logging;
pub mod pairing;

// Re-export idevice-ffi's symbols into our staticlib.
#[allow(unused_imports)]
extern crate idevice_ffi;

pub use pairing::{ALPairPinCb, ALPairReadyCb, ALPairResult};

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn al_log_init(
    cb: logging::LogCallback,
    ctx: *mut c_void,
) -> i32 {
    logging::init(cb, ctx)
}

// ---------------------------------------------------------------------------
// Pairing
// ---------------------------------------------------------------------------

#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn al_pairing_run_host(
    bind_addr: *const c_char,
    port: u16,
    name: *const c_char,
    model: *const c_char,
    out_path: *const c_char,
    host_alt_irk_hex: *const c_char,
    ready_cb: ALPairReadyCb,
    pin_cb: ALPairPinCb,
    ctx: *mut c_void,
    out: *mut ALPairResult,
) -> i32 {
    pairing::run_host(
        bind_addr,
        port,
        name,
        model,
        out_path,
        host_alt_irk_hex,
        ready_cb,
        pin_cb,
        ctx,
        out,
    )
}

#[no_mangle]
pub unsafe extern "C" fn al_pairing_result_free(
    r: *mut ALPairResult,
) {
    pairing::result_free(r)
}

// ---------------------------------------------------------------------------
// Exploit
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_exploit_run(
    pairing_path: *const c_char,
    target: *const c_char,
    log_cb: exploit::ALLogCallback,
    ctx: *mut c_void,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::run(
                pairing_path,
                target,
                log_cb,
                ctx,
                out_json,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_exploit_run: {e:?}"
                ));
            }
            1
        }
    }
}

// ---------------------------------------------------------------------------
// AFC File Manager
// ---------------------------------------------------------------------------

/// List directory entries exposed by the paired AFC service.
///
/// Returns 0 on success, 1 on error.
#[no_mangle]
pub unsafe extern "C" fn al_afc_list_directory(
    pairing_path: *const c_char,
    remote_path: *const c_char,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::afc_list_directory(
                pairing_path,
                remote_path,
                out_json,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_afc_list_directory: {e:?}"
                ));
            }
            1
        }
    }
}

// ---------------------------------------------------------------------------
// Exploit file operations
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_exploit_write_dir(
    pairing_path: *const c_char,
    source_dir: *const c_char,
    target_dir: *const c_char,
    log_cb: exploit::ALLogCallback,
    ctx: *mut c_void,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::write_dir(
                pairing_path,
                source_dir,
                target_dir,
                log_cb,
                ctx,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_exploit_write_dir: {e:?}"
                ));
            }
            1
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn al_exploit_inject_folder(
    pairing_path: *const c_char,
    folder_path: *const c_char,
    target_parent_dir: *const c_char,
    dest_name: *const c_char,
    log_cb: exploit::ALLogCallback,
    ctx: *mut c_void,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::inject_folder(
                pairing_path,
                folder_path,
                target_parent_dir,
                dest_name,
                log_cb,
                ctx,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_exploit_inject_folder: {e:?}"
                ));
            }
            1
        }
    }
}

// ---------------------------------------------------------------------------
// String memory management
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_string_free(
    p: *mut c_char,
) {
    let _ = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            ffi_util::string_free(p);
        }),
    );
}

// ---------------------------------------------------------------------------
// Live Card Scanner / Syslog Stream
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_syslog_stream_start(
    pairing_path: *const c_char,
    line_cb: exploit::ALSyslogLineCallback,
    ctx: *mut c_void,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::run_syslog_stream(
                pairing_path,
                line_cb,
                ctx,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_syslog_stream_start: {e:?}"
                ));
            }
            1
        }
    }
}

#[no_mangle]
pub extern "C" fn al_syslog_stream_stop() {
    let _ = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::stop_syslog_stream();
        }),
    );
}

// ---------------------------------------------------------------------------
// Passthm Archive Extractor
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_passthm_extract(
    archive_path: *const c_char,
    dest_dir: *const c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            let archive_path =
                match ffi_util::opt_str(archive_path, "").as_str() {
                    "" => return 1,
                    s => s.to_string(),
                };

            let dest_dir =
                match ffi_util::opt_str(dest_dir, "").as_str() {
                    "" => return 1,
                    s => s.to_string(),
                };

            let file = match std::fs::File::open(&archive_path) {
                Ok(f) => f,
                Err(_) => return 2,
            };

            let mut archive = match zip::ZipArchive::new(file) {
                Ok(a) => a,
                Err(_) => return 3,
            };

            let dest = std::path::Path::new(&dest_dir);

            if std::fs::create_dir_all(dest).is_err() {
                return 4;
            }

            for i in 0..archive.len() {
                let mut file = match archive.by_index(i) {
                    Ok(f) => f,
                    Err(_) => continue,
                };

                let name = match file.enclosed_name() {
                    Some(n) => n.to_owned(),
                    None => continue,
                };

                if file.is_file() {
                    let file_name =
                        name.file_name().unwrap_or(name.as_os_str());

                    let outpath = dest.join(file_name);

                    if let Ok(mut outfile) =
                        std::fs::File::create(&outpath)
                    {
                        let _ = std::io::copy(&mut file, &mut outfile);
                    }
                }
            }

            0
        }),
    );

    res.unwrap_or(1)
}

#[no_mangle]
pub unsafe extern "C" fn al_zip_extract_all(
    archive_path: *const c_char,
    dest_dir: *const c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            let archive_path =
                match ffi_util::opt_str(archive_path, "").as_str() {
                    "" => return 1,
                    s => s.to_string(),
                };

            let dest_dir =
                match ffi_util::opt_str(dest_dir, "").as_str() {
                    "" => return 1,
                    s => s.to_string(),
                };

            let file = match std::fs::File::open(&archive_path) {
                Ok(f) => f,
                Err(_) => return 2,
            };

            let mut archive = match zip::ZipArchive::new(file) {
                Ok(a) => a,
                Err(_) => return 3,
            };

            let dest = std::path::Path::new(&dest_dir);

            if std::fs::create_dir_all(dest).is_err() {
                return 4;
            }

            for i in 0..archive.len() {
                let mut file = match archive.by_index(i) {
                    Ok(f) => f,
                    Err(_) => continue,
                };

                let name = match file.enclosed_name() {
                    Some(n) => n.to_owned(),
                    None => continue,
                };

                let name_str = name.to_string_lossy();

                if name_str.contains("__MACOSX")
                    || name_str.ends_with(".DS_Store")
                {
                    continue;
                }

                let outpath = dest.join(&name);

                if file.is_dir() {
                    let _ = std::fs::create_dir_all(&outpath);
                } else {
                    if let Some(parent) = outpath.parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }

                    if let Ok(mut outfile) =
                        std::fs::File::create(&outpath)
                    {
                        let _ = std::io::copy(&mut file, &mut outfile);
                    }
                }
            }

            0
        }),
    );

    res.unwrap_or(1)
}

// ---------------------------------------------------------------------------
// App Container
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_find_app_container(
    pairing_path: *const c_char,
    bundle_id: *const c_char,
    log_cb: exploit::ALLogCallback,
    ctx: *mut c_void,
    out_container: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::find_container(
                pairing_path,
                bundle_id,
                log_cb,
                ctx,
                out_container,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_find_app_container: {e:?}"
                ));
            }
            1
        }
    }
}

// ---------------------------------------------------------------------------
// Device Respring
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_device_respring(
    pairing_path: *const c_char,
    log_cb: exploit::ALLogCallback,
    ctx: *mut c_void,
    out_error: *mut *mut c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::device_respring(
                pairing_path,
                log_cb,
                ctx,
                out_error,
            )
        }),
    );

    match res {
        Ok(rc) => rc,
        Err(e) => {
            if !out_error.is_null() {
                *out_error = ffi_util::cstr(format!(
                    "Rust panic in al_device_respring: {e:?}"
                ));
            }
            1
        }
    }
}

// ---------------------------------------------------------------------------
// Target Host Configuration
// ---------------------------------------------------------------------------

#[no_mangle]
pub unsafe extern "C" fn al_set_target_host(
    host: *const c_char,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            let host_str = if host.is_null() {
                None
            } else {
                let s = ffi_util::opt_str(host, "").trim().to_string();

                if s.is_empty() {
                    None
                } else {
                    Some(s)
                }
            };

            exploit::set_target_host(host_str);
            0
        }),
    );

    res.unwrap_or(1)
}

#[no_mangle]
pub unsafe extern "C" fn al_set_target_hosts(
    hosts: *const *const c_char,
    count: usize,
) -> i32 {
    let res = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            let mut list = Vec::new();

            if !hosts.is_null() {
                for i in 0..count {
                    let p = *hosts.add(i);

                    if !p.is_null() {
                        let s =
                            ffi_util::opt_str(p, "").trim().to_string();

                        if !s.is_empty() && !list.contains(&s) {
                            list.push(s);
                        }
                    }
                }
            }

            exploit::set_target_hosts(list);
            0
        }),
    );

    res.unwrap_or(1)
}

#[no_mangle]
pub extern "C" fn al_clear_target_hosts() {
    let _ = std::panic::catch_unwind(
        std::panic::AssertUnwindSafe(|| {
            exploit::clear_target_hosts();
        }),
    );
}
