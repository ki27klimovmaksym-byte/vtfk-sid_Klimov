use sha2::{Digest, Sha256};
use std::fs;
use std::io;
use std::path::PathBuf;

fn generate_key(seed: &str) -> String {
    format!("{:x}", Sha256::digest(seed.as_bytes()))
}

trait DataSource {
    fn fetch(&self) -> io::Result<String>;
}

struct FileDataSource {
    path: PathBuf,
}

impl FileDataSource {
    fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }
}

impl DataSource for FileDataSource {
    fn fetch(&self) -> io::Result<String> {
        fs::read_to_string(&self.path)
    }
}

fn generate_key_from_source(source: &impl DataSource) -> io::Result<String> {
    let seed = source.fetch()?;
    Ok(generate_key(&seed))
}

fn main() -> io::Result<()> {
    let mut args = std::env::args_os().skip(1);
    match (args.next(), args.next()) {
        (None, None) => println!("{}", generate_key("sidkit test seed")),
        (Some(path), None) => println!("{}", generate_key_from_source(&FileDataSource::new(path))?),
        _ => {
            eprintln!("Usage: sid-core [seed-file]");
            std::process::exit(2);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    struct MockDataSource(&'static str);

    impl DataSource for MockDataSource {
        fn fetch(&self) -> io::Result<String> {
            Ok(self.0.to_owned())
        }
    }

    #[test]
    fn generate_key_is_deterministic() {
        assert_eq!(generate_key("same seed"), generate_key("same seed"));
        assert_ne!(generate_key("same seed"), generate_key("different seed"));
    }

    #[test]
    fn generate_key_returns_sha256_hex() {
        assert_eq!(
            generate_key("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn generate_key_from_source_uses_mock_data() {
        let source = MockDataSource("mock seed");
        assert_eq!(
            generate_key_from_source(&source).unwrap(),
            generate_key("mock seed")
        );
    }

    #[test]
    fn file_data_source_reads_seed() {
        let path = std::env::temp_dir().join(format!(
            "sid-core-test-{}-{}.txt",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::write(&path, "file seed").unwrap();

        let result = generate_key_from_source(&FileDataSource::new(&path));
        fs::remove_file(path).unwrap();

        assert_eq!(result.unwrap(), generate_key("file seed"));
    }
}
