"""Score registry.  Each module defines build() -> engine.Song.

The value is the approximate length in seconds (only used to schedule the longest
renders first when building in parallel).
"""
import importlib

TRACKS = {
    "title": 114,
    "spring": 120,
    "summer": 117,
    "autumn": 115,
    "winter": 120,
    "night": 91,
    "town": 101,
    "shop": 60,
    "ruins_explore": 120,
    "ruins_deep": 120,
    "combat": 69,
    "festival": 88,
    "sad": 80,
    "stinger_victory": 3,
    "stinger_death": 3,
    "stinger_new_day": 2.5,
}


def load(name: str):
    return importlib.import_module(f"scores.{name}")
