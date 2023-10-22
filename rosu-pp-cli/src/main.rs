// TODO: handle all game modes.

use clap::Parser;
use rosu_pp::{Beatmap, BeatmapExt};
use serde_json::json;

/// Calculate pp for a beatmap
#[derive(Parser)]
struct Cli {
    /// The path to the .osu file to read
    #[arg(long)]
    path: String,
    /// Accuracy in percent
    #[arg(long)]
    accuracy: f64,
    /// Mods as an integer
    #[arg(long)]
    mods: u32,
    // /// Game mode as an integer
    // #[arg(long)]
    // mode: u8,
}

fn main() {
    let args = Cli::parse();
    let map = match Beatmap::from_path(args.path) {
        Ok(map) => map,
        Err(why) => panic!("Error parsing map: {}", why),
    };
    // TODO: can we get map length?
    let attrs = map.attributes().mods(args.mods).build();
    let stars = map.stars().mods(args.mods).calculate().stars();
    let pp = map.pp().mods(args.mods).accuracy(args.accuracy).calculate().pp();
    let result = json!({
        "ar": attrs.ar,
        "bpm": map.bpm() * attrs.clock_rate,
        "cs": attrs.cs,
        "hp": attrs.hp,
        "od": attrs.od,
        "pp": pp,
        "sr": stars,
    });
    println!("{}", result.to_string());
}
