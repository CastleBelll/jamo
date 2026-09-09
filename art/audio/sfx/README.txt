Audio assets are not in the repository yet.

Every path below is already wired up and will start playing the moment the file
is dropped in; until then AudioManager resolves the path to nothing and stays
silent, without raising a load error. Doc v0.3 section 25.

Step sounds, referenced from res://resources/motion_profiles/*.tres
(MotionProfile.step_sfx_path):

  step_heavy.ogg   HEAVY  - low 톡/툭     (heavy_step)
  step_light.ogg   LIGHT  - 틱/탭         (light_step, upright)
  step_bounce.ogg  BOUNCE - 뽁/통         (bounce, heavy_bounce)
  step_roll.ogg    ROLL   - light rolling (roll, roll_fast)
  step_glide.ogg   GLIDE  - 스윽          (glide, sway)

Click and UI cues, referenced from res://resources/audio/sfx_library.tres
(AudioLibrary): click / click_critical / click_golden / kill / word_complete,
plus the looping bgm track. Those slots are empty; set them in the Inspector.
