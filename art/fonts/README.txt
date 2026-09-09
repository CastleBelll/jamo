Korean UI font
==============

Drop an OFL-licensed Korean font here and the whole UI picks it up:

    art/fonts/NotoSansKR-Regular.ttf

That exact path is already wired into Project Settings > GUI > Theme >
Custom Font (project.godot, [gui] theme/custom_font). Until the file exists
Godot logs one harmless warning and falls back to a system font, so Korean
still renders locally but the build is not self-contained.

Suggested fonts (both SIL Open Font License 1.1, redistributable):
  - Noto Sans KR   https://fonts.google.com/noto/specimen/Noto+Sans+KR
  - Pretendard     https://github.com/orioncactus/pretendard

To use a different filename, change the path in Project Settings instead of
renaming the file, so the setting stays the single source of truth.
