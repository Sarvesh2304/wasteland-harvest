"""Wasteland Harvest music engine: score model, synthesis, mixing and mastering."""
from . import patterns as P  # noqa: F401
from .drums import Kit  # noqa: F401
from .instruments import (Bass, Chip, EPiano, FMBell, Pad, Piano, Plucked, Reed,  # noqa: F401
                          ResoNoise, Slide, Struck, Swell)
from .song import Song  # noqa: F401
from .theory import transpose_text  # noqa: F401
