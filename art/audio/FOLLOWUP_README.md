# JAMO audio follow-up

All six assets are project-original deterministic NumPy synthesis, encoded with
SoundFile/libsndfile to OGG Vorbis, mono 44.1kHz. No third-party samples, generated
provider jobs or music downloads. JAMO may use/modify these without third-party
attribution requirements; source is retained in `build_followup.py`.

Existing `bgm_combat.ogg` is exactly 705600 frames / 16 seconds. Inspection of its
source and FFT found the A/E pure-fifth stack 110/165/220/330Hz, but **no existing
percussive beat or BPM**. New boss layer uses a matching 55/110/165Hz low drone and
restrained membrane-drum pulses on a 120 BPM grid: 32 beats / eight 4-beat measures
per 16-second loop. This is a compatible rhythm choice, not a measured combat BPM.
Layer is intentionally thin solo (-17.83dBFS decoded peak), for synchronized overlay
at the same playback position as combat. No global fade/silence at the loop seam;
periodic pulses plus integer-cycle drone bridge the boundary. No engine wiring added.

Effects: 0.1s resonant wooden click; 0.3s bright 660/880Hz two-note brush confirmation;
0.25s low 220Hz cancellation; 0.05s quiet wooden hover (-24.14dBFS); 1s 440Hz harmonic
bell with upward cleansing shimmer and tail. Micro edge fades avoid abrupt SFX cuts.

`FOLLOWUP_VALIDATION.json` records SHA-256, codec, frames, decoded sample peaks,
edge silence at -60dBFS, and boss boundary continuity. All peaks below -3dBFS;
boss has no leading/trailing silence and boundary sample jump 0.00235. At unity gain,
combat+boss decoded mix peaks at -12.86dBFS. These are static waveform/codec checks,
not an in-game listening/volume acceptance claim; engine mix audition remains Claude's.

Rebuild: `python art/audio/build_followup.py` (NumPy, SoundFile).
Read-only verify: `python art/audio/build_followup.py --check`.
