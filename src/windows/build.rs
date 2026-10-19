use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn find_rc_exe() -> Option<PathBuf> {
    if let Ok(rc) = env::var("RC") {
        let p = PathBuf::from(rc);
        if p.exists() {
            return Some(p);
        }
    }

    if Command::new("rc.exe").arg("/?").output().is_ok() {
        return Some(PathBuf::from("rc.exe"));
    }

    let kits_root = Path::new(r"C:\Program Files (x86)\Windows Kits\10\bin");
    if let Ok(entries) = fs::read_dir(kits_root) {
        let mut versions: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.join(r"x64\rc.exe").exists())
            .collect();
        versions.sort();
        if let Some(latest) = versions.last() {
            return Some(latest.join(r"x64\rc.exe"));
        }
    }

    None
}

fn main() {
    println!("cargo:rerun-if-changed=../../packaging/windows/mdvu.ico");
    println!("cargo:rerun-if-changed=Cargo.toml");

    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let ico_path = manifest_dir.join("../../packaging/windows/mdvu.ico");
    if !ico_path.exists() {
        return;
    }

    let Some(rc_exe) = find_rc_exe() else {
        return;
    };

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let rc_path = out_dir.join("mdvu.rc");
    let res_path = out_dir.join("mdvu.res");

    let version = env::var("CARGO_PKG_VERSION").expect("Cargo provides the package version");
    let mut parts: Vec<u16> = version
        .split('.')
        .filter_map(|s| s.parse::<u16>().ok())
        .collect();
    while parts.len() < 4 {
        parts.push(0);
    }
    let ver_comma = format!("{},{},{},{}", parts[0], parts[1], parts[2], parts[3]);
    let ico_escaped = ico_path.to_string_lossy().replace('\\', "\\\\");

    let rc_content = format!(
        r#"1 ICON "{ico_escaped}"

1 VERSIONINFO
FILEVERSION {ver_comma}
PRODUCTVERSION {ver_comma}
FILEFLAGSMASK 0x3fL
FILEFLAGS 0x0L
FILEOS 0x40004L
FILETYPE 0x1L
FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904b0"
        BEGIN
            VALUE "CompanyName", "Finn de Bear"
            VALUE "FileDescription", "mdvu - Ultra-fast Markdown & Mermaid Viewer"
            VALUE "FileVersion", "{version}"
            VALUE "InternalName", "mdvu"
            VALUE "LegalCopyright", "Copyright (C) 2026 Finn de Bear"
            VALUE "OriginalFilename", "mdvu.exe"
            VALUE "ProductName", "mdvu"
            VALUE "ProductVersion", "{version}"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END
"#
    );

    if fs::write(&rc_path, rc_content).is_ok() {
        let status = Command::new(rc_exe)
            .args(["/nologo", "/fo"])
            .arg(&res_path)
            .arg(&rc_path)
            .status();

        if let Ok(s) = status {
            if s.success() && res_path.exists() {
                println!("cargo:rustc-link-arg-bins={}", res_path.display());
            }
        }
    }
}
