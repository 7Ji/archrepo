use std::collections::{HashMap, BTreeMap};

struct PKGBUILD {
    name: String,
    url: String
}

fn read_config() -> Vec<PKGBUILD> {
    let file = std::env::args().nth(1).expect("Config not given");
    let config: BTreeMap<String, Vec<HashMap<String, String>>> = 
        serde_yaml::from_reader(
        std::fs::File::open(file)
            .expect("Failed to open config file"))
            .expect("Failed to parse config file, make sure it's valid YAML");
    let v =
        config.get_key_value("PKGBUILDs")
            .expect("YAML not contain one and only PKGBUILDs list");
    let mut pkgs = Vec::new();
    for item in v.1 {
        if item.len() != 1 {
            panic!("Length not 1")
        }
        let kv = item.iter().next().expect("Not found");
        pkgs.push(PKGBUILD{name: kv.0.clone(), url: kv.1.clone()})
    }
    return pkgs;
}

fn main() {
    let pkgs = read_config();
    println!("Lazily building the following packages:");
    for pkg in pkgs.iter() {
        println!("Name: '{}', url '{}'", pkg.name, pkg.url);
    }
}
