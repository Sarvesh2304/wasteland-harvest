"""The Wasteland Harvest leitmotif ("the settlement theme").

An 8-bar period in D major.  Antecedent (bars 1-4) ends on a half cadence (a 4-3
suspension over A); the consequent repeats the opening, leaps a major sixth to the climax
(B5) over G -> Gm (modal mixture: the bittersweet iv), and turns home through the leading
tone.  Rhythmic identity: "short-short-long-short-long | long-short-loooong".

    | D        | G        | Bm        | Asus4  A  |
    | A D F#. E D | G. F# E-- | B D F#. G F# | E. D C#-- |
    | D/F#     | G   Gm   | Em7  A7   | D        |
    | A D F#. E D | B. A G-- | F#. G E C# | D--- |
"""

LEITMOTIF = """
A4:8 D5 F#5:4. E5:8 D5:4 | G5:4. F#5:8 E5:2 | B4:8 D5 F#5:4. G5:8 F#5:4 | E5:4. D5:8 C#5:2 |
A4:8 D5 F#5:4. E5:8 D5:4 | B5:4. A5:8 G5:2 | F#5:4. G5:8 E5:4 C#5:4 | D5:2. r:4 |
"""

LEITMOTIF_CHORDS = "D | G | Bm | Asus4 A | D/F# | G Gm | Em7 A7 | D"

# opening gesture only (used as a quote / stinger motif)
HEAD = "A4:8 D5 F#5:4. E5:8 D5:4"
