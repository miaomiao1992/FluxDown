//! Chrome Native Messaging Host (NMH) manifest generation and registry registration.
//!
//! Registers `com.fluxdown.nmh` for Chrome, Edge, and Firefox so that the
//! browser extension can use `chrome.runtime.connectNative("com.fluxdown.nmh")`
//! to communicate with the FluxDown desktop app via the NMH relay binary.
//!
//! Registry keys (all HKCU — no admin required):
//!   Chrome:  `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.fluxdown.nmh`
//!   Edge:    `HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.fluxdown.nmh`
//!   Firefox: `HKCU\Software\Mozilla\NativeMessagingHosts\com.fluxdown.nmh`
//!
//! Each key's default value points to a JSON manifest file that describes the NMH.

#[cfg(target_os = "windows")]
mod inner {
    use serde::Serialize;
    use std::io;
    use std::path::{Path, PathBuf};
    use winreg::enums::{HKEY_CURRENT_USER, KEY_READ, KEY_WRITE};
    use winreg::RegKey;

    const NMH_NAME: &str = "com.fluxdown.nmh";
    const NMH_DESCRIPTION: &str = "FluxDown Native Messaging Host";
    const NMH_EXE_NAME: &str = "fluxdown_nmh.exe";

    /// Manifest filename for Chrome/Edge (contains `allowed_origins`).
    const MANIFEST_FILENAME_CHROMIUM: &str = "com.fluxdown.nmh.json";
    /// Manifest filename for Firefox (contains `allowed_extensions`, NO `allowed_origins`).
    /// Firefox schema validation (NativeManifests.sys.mjs via Schemas.normalize) rejects any
    /// field not in its native_manifest.json schema. `allowed_origins` is Chrome-only and
    /// causes Firefox to report "No such native application" (Bugzilla #1361459).
    const MANIFEST_FILENAME_FIREFOX: &str = "com.fluxdown.nmh.firefox.json";

    /// Chrome extension ID — pinned via `key` in wxt.config.ts manifest.
    const CHROME_EXTENSION_ID: &str = "chrome-extension://cmkcgfjpfcjfadecjdecbdfncmligjde/";

    /// Firefox extension ID (matches `browser_specific_settings.gecko.id` in manifest).
    const FIREFOX_EXTENSION_ID: &str = "fluxdown@fluxdown.app";

    /// Chromium (Chrome/Edge) NMH manifest — uses `allowed_origins`.
    #[derive(Serialize)]
    struct NmhManifestChromium {
        name: String,
        description: String,
        path: String,
        #[serde(rename = "type")]
        host_type: String,
        allowed_origins: Vec<String>,
    }

    /// Firefox NMH manifest — uses `allowed_extensions` ONLY.
    /// Firefox schema (native_manifest.json) does not define `allowed_origins`;
    /// including it causes schema validation to fail with "No such native application".
    #[derive(Serialize)]
    struct NmhManifestFirefox {
        name: String,
        description: String,
        path: String,
        #[serde(rename = "type")]
        host_type: String,
        allowed_extensions: Vec<String>,
    }

    /// Strip `\\?\` UNC prefix from a path string (if present).
    fn strip_unc_prefix(s: &str) -> String {
        s.strip_prefix(r"\\?\").unwrap_or(s).to_string()
    }

    /// Find the NMH executable, searching multiple locations.
    ///
    /// Search order:
    /// 1. Same directory as the current app exe (production deployment)
    /// 2. Cargo workspace `target/debug/` (development — `flutter run`)
    /// 3. Cargo workspace `target/release/` (development — release build)
    fn find_nmh_exe() -> Result<PathBuf, io::Error> {
        // 1. Next to current exe (production: NMH ships alongside the app)
        if let Ok(exe) = std::env::current_exe() {
            let canonical = std::fs::canonicalize(&exe).unwrap_or(exe);
            if let Some(dir) = canonical.parent() {
                let candidate = dir.join(NMH_EXE_NAME);
                if candidate.exists() {
                    rinf::debug_print!(
                        "[nmh_registry] found NMH exe next to app: {}",
                        candidate.display()
                    );
                    return Ok(candidate);
                }
            }
        }

        // 2+3. Cargo workspace target directory (development)
        // CARGO_MANIFEST_DIR is baked in at compile time for the hub crate.
        // hub crate is at <workspace>/native/hub, so workspace root is 2 levels up.
        let manifest_dir = env!("CARGO_MANIFEST_DIR");
        let workspace_root = Path::new(manifest_dir)
            .parent()
            .and_then(|p| p.parent());

        if let Some(ws) = workspace_root {
            for profile in &["debug", "release"] {
                let candidate = ws.join("target").join(profile).join(NMH_EXE_NAME);
                if candidate.exists() {
                    rinf::debug_print!(
                        "[nmh_registry] found NMH exe in cargo target: {}",
                        candidate.display()
                    );
                    return Ok(candidate);
                }
            }
        }

        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!(
                "{} not found. Build it with: cargo build -p fluxdown_nmh",
                NMH_EXE_NAME
            ),
        ))
    }

    /// Write two NMH manifest JSON files next to the NMH executable:
    /// - Chromium manifest (Chrome/Edge): contains `allowed_origins`
    /// - Firefox manifest: contains `allowed_extensions` ONLY (no `allowed_origins`)
    ///
    /// Returns `(chromium_manifest_path, firefox_manifest_path)`.
    fn write_manifests(nmh_exe: &Path) -> Result<(PathBuf, PathBuf), io::Error> {
        let nmh_path_str = strip_unc_prefix(&nmh_exe.to_string_lossy());
        let dir = nmh_exe
            .parent()
            .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no parent dir"))?;

        // Chromium manifest (Chrome + Edge)
        let chromium = NmhManifestChromium {
            name: NMH_NAME.to_string(),
            description: NMH_DESCRIPTION.to_string(),
            path: nmh_path_str.clone(),
            host_type: "stdio".to_string(),
            allowed_origins: vec![CHROME_EXTENSION_ID.to_string()],
        };
        let chromium_json = serde_json::to_string_pretty(&chromium)
            .map_err(|e| io::Error::other(format!("JSON serialize error: {}", e)))?;
        let chromium_path = dir.join(MANIFEST_FILENAME_CHROMIUM);
        std::fs::write(&chromium_path, chromium_json)?;

        // Firefox manifest — NO `allowed_origins` field (Bugzilla #1361459)
        let firefox = NmhManifestFirefox {
            name: NMH_NAME.to_string(),
            description: NMH_DESCRIPTION.to_string(),
            path: nmh_path_str,
            host_type: "stdio".to_string(),
            allowed_extensions: vec![FIREFOX_EXTENSION_ID.to_string()],
        };
        let firefox_json = serde_json::to_string_pretty(&firefox)
            .map_err(|e| io::Error::other(format!("JSON serialize error: {}", e)))?;
        let firefox_path = dir.join(MANIFEST_FILENAME_FIREFOX);
        std::fs::write(&firefox_path, firefox_json)?;

        Ok((chromium_path, firefox_path))
    }

    /// Register each browser's registry key pointing to its dedicated manifest.
    /// Chrome and Edge use the Chromium manifest; Firefox uses the Firefox-only manifest.
    fn register_registry(chromium_manifest: &str, firefox_manifest: &str) -> Result<(), io::Error> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);

        let chromium_paths = &[
            r"Software\Google\Chrome\NativeMessagingHosts",
            r"Software\Microsoft\Edge\NativeMessagingHosts",
        ];
        for reg_path in chromium_paths {
            let full_path = format!("{}\\{}", reg_path, NMH_NAME);
            let (key, _) = hkcu.create_subkey_with_flags(&full_path, KEY_WRITE)?;
            key.set_value("", &chromium_manifest)?;
            rinf::debug_print!("[nmh_registry] registered at HKCU\\{}", full_path);
        }

        let firefox_reg = format!("{}\\{}", r"Software\Mozilla\NativeMessagingHosts", NMH_NAME);
        let (key, _) = hkcu.create_subkey_with_flags(&firefox_reg, KEY_WRITE)?;
        key.set_value("", &firefox_manifest)?;
        rinf::debug_print!("[nmh_registry] registered at HKCU\\{}", firefox_reg);

        Ok(())
    }

    /// Returns `true` if NMH registration is missing or stale and needs to be (re)written.
    ///
    /// Checks that:
    ///   1. All browser registry keys exist under HKCU.
    ///   2. Each manifest file exists at the registered path.
    ///   3. Each manifest's exe path matches the currently located NMH executable.
    ///   4. Chrome/Edge point to the Chromium manifest; Firefox points to its own manifest.
    ///
    /// If the NMH exe cannot be found, returns `true` so that `register()` can
    /// report the proper "exe not found" error.
    pub fn needs_update() -> bool {
        let Ok(nmh_exe) = find_nmh_exe() else {
            return true;
        };
        let expected_exe = strip_unc_prefix(&nmh_exe.to_string_lossy());
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);

        // Check Chrome and Edge point to the Chromium manifest
        let chromium_reg_paths = &[
            r"Software\Google\Chrome\NativeMessagingHosts",
            r"Software\Microsoft\Edge\NativeMessagingHosts",
        ];
        for reg_path in chromium_reg_paths {
            let full_path = format!("{}\\{}", reg_path, NMH_NAME);
            let Ok(key) = hkcu.open_subkey_with_flags(&full_path, KEY_READ) else {
                return true;
            };
            let Ok(manifest_str): Result<String, _> = key.get_value("") else {
                return true;
            };
            if !manifest_str.ends_with(MANIFEST_FILENAME_CHROMIUM) {
                return true; // pointing to wrong manifest
            }
            if !Path::new(&manifest_str).exists() {
                return true;
            }
            let Ok(content) = std::fs::read_to_string(&manifest_str) else {
                return true;
            };
            if !content.contains(&expected_exe) {
                return true;
            }
        }

        // Check Firefox points to the Firefox-only manifest
        let firefox_reg = format!(
            "{}\\{}",
            r"Software\Mozilla\NativeMessagingHosts",
            NMH_NAME
        );
        let Ok(key) = hkcu.open_subkey_with_flags(&firefox_reg, KEY_READ) else {
            return true;
        };
        let Ok(manifest_str): Result<String, _> = key.get_value("") else {
            return true;
        };
        if !manifest_str.ends_with(MANIFEST_FILENAME_FIREFOX) {
            return true; // still pointing to old shared manifest
        }
        if !Path::new(&manifest_str).exists() {
            return true;
        }
        let Ok(content) = std::fs::read_to_string(&manifest_str) else {
            return true;
        };
        if !content.contains(&expected_exe) {
            return true;
        }

        false
    }

    /// Register the NMH for all supported browsers.
    ///
    /// Writes two separate manifest files:
    /// - Chromium manifest (Chrome/Edge): contains `allowed_origins`
    /// - Firefox manifest: contains `allowed_extensions` ONLY
    ///
    /// This is idempotent — safe to call on every startup.
    pub fn register() -> Result<(), io::Error> {
        let nmh_exe = find_nmh_exe()?;
        let (chromium_path, firefox_path) = write_manifests(&nmh_exe)?;
        let chromium_str = strip_unc_prefix(&chromium_path.to_string_lossy());
        let firefox_str = strip_unc_prefix(&firefox_path.to_string_lossy());
        let nmh_str = strip_unc_prefix(&nmh_exe.to_string_lossy());
        register_registry(&chromium_str, &firefox_str)?;
        rinf::debug_print!(
            "[nmh_registry] NMH registered: exe={}, chromium_manifest={}, firefox_manifest={}",
            nmh_str,
            chromium_str,
            firefox_str,
        );
        Ok(())
    }

    /// Remove NMH registration for all browsers and delete manifest files.
    #[allow(dead_code)]
    pub fn unregister() -> Result<(), io::Error> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);

        let all_reg_paths = &[
            r"Software\Google\Chrome\NativeMessagingHosts",
            r"Software\Microsoft\Edge\NativeMessagingHosts",
            r"Software\Mozilla\NativeMessagingHosts",
        ];
        for reg_path in all_reg_paths {
            match hkcu.open_subkey_with_flags(reg_path, KEY_WRITE) {
                Ok(parent) => {
                    let _ = parent.delete_subkey(NMH_NAME);
                }
                Err(_) => continue,
            }
        }

        // Remove both manifest files if NMH exe is found.
        if let Ok(nmh_exe) = find_nmh_exe()
            && let Some(dir) = nmh_exe.parent()
        {
            let _ = std::fs::remove_file(dir.join(MANIFEST_FILENAME_CHROMIUM));
            let _ = std::fs::remove_file(dir.join(MANIFEST_FILENAME_FIREFOX));
        }

        rinf::debug_print!("[nmh_registry] NMH registration removed");
        Ok(())
    }
}

#[cfg(not(target_os = "windows"))]
mod inner {
    use std::io;

    pub fn needs_update() -> bool {
        false
    }

    pub fn register() -> Result<(), io::Error> {
        Ok(())
    }

    pub fn unregister() -> Result<(), io::Error> {
        Ok(())
    }
}

#[allow(unused_imports)]
pub use inner::{needs_update, register, unregister};
