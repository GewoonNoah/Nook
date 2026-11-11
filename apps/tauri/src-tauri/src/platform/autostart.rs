//! Start Nook when you sign in (Settings › General › Start with Windows). Windows: a value under the current user's
//! `Run` key; Linux: a `.desktop` file in `~/.config/autostart`. Applied at every launch, so a moved or updated
//! install still points at the right program. Development builds never register themselves.

use std::path::Path;

/// The argument the login entry starts Nook with: only the bar and the tray, no main window.
pub const ARG: &str = "--autostart";

/// Brings the login entry in line with the setting. Returns what went wrong, if anything.
pub fn apply(enabled: bool) -> Result<(), String> {
    if cfg!(debug_assertions) {
        return Ok(());
    }
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    set(&exe, enabled)
}

#[cfg(target_os = "windows")]
const RUN_KEY: &str = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";

#[cfg(target_os = "windows")]
fn set(exe: &Path, enabled: bool) -> Result<(), String> {
    use std::time::Duration;
    let reg = |args: &[&str]| super::process::run("reg", args, None, Duration::from_secs(5));
    if enabled {
        let command = command_line(exe);
        reg(&["add", RUN_KEY, "/v", "Nook", "/t", "REG_SZ", "/d", &command, "/f"]).map(|_| ())
    } else {
        // Deleting a value that is not there is fine: nothing to undo.
        let _ = reg(&["delete", RUN_KEY, "/v", "Nook", "/f"]);
        Ok(())
    }
}

#[cfg(target_os = "linux")]
fn set(exe: &Path, enabled: bool) -> Result<(), String> {
    let Some(dir) = dirs::config_dir().map(|d| d.join("autostart")) else { return Ok(()) };
    let file = dir.join("nook.desktop");
    if !enabled {
        let _ = std::fs::remove_file(&file);
        return Ok(());
    }
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let entry = desktop_entry(exe);
    if std::fs::read_to_string(&file).ok().as_deref() == Some(entry.as_str()) {
        return Ok(());
    }
    std::fs::write(&file, entry).map_err(|e| e.to_string())
}

#[cfg(not(any(target_os = "windows", target_os = "linux")))]
fn set(_exe: &Path, _enabled: bool) -> Result<(), String> {
    Ok(())
}

/// The command Windows runs at sign-in: the program in quotes (its path may have spaces) and [`ARG`].
#[cfg_attr(not(any(target_os = "windows", test)), allow(dead_code))]
pub fn command_line(exe: &Path) -> String {
    format!("\"{}\" {ARG}", exe.display())
}

/// The XDG autostart entry for Linux desktops.
#[cfg_attr(not(any(target_os = "linux", test)), allow(dead_code))]
pub fn desktop_entry(exe: &Path) -> String {
    let path = exe.display().to_string().replace('\\', "\\\\").replace('"', "\\\"");
    format!(
        "[Desktop Entry]\nType=Application\nName=Nook\nComment=Your personal assistant\nExec=\"{path}\" {ARG}\nTerminal=false\nX-GNOME-Autostart-enabled=true\n"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn quotes_a_path_with_spaces() {
        let exe = PathBuf::from(r"C:\Program Files\Nook\nook.exe");
        assert_eq!(command_line(&exe), r#""C:\Program Files\Nook\nook.exe" --autostart"#);
    }

    #[test]
    fn writes_a_desktop_entry_that_starts_in_the_background() {
        let entry = desktop_entry(&PathBuf::from("/opt/Nook App/nook"));
        assert!(entry.starts_with("[Desktop Entry]\n"));
        assert!(entry.contains("Exec=\"/opt/Nook App/nook\" --autostart\n"));
    }
}
