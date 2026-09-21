# Intro and UI pass

The game now opens with a skippable Amiin Studio reveal before the title menu. The original logo is the source texture at `Logo/X8y06N.png`.

`development/blender/AmiinStudioLogoIntro.blend` is the editable Blender source. It animates the original logo's scale, glow and orange reveal ribbons over 132 frames. `development/tools/amiin_studio_intro.py` saves the `.blend` and renders the settled title-card image into `Adventure/generated/amiin_studio_intro.png`.

The Godot intro adds a timed fade-and-settle sequence, title, studio credit, short game promise, and a click/key skip.

The UI refreshes title/menu panels, action buttons, hotbar cells and persistent controls with a darker woodland surface, warm amber focus state, larger menu heading and clearer Welcome copy. Existing menus, inventory and building catalog behavior remain unchanged.

Validation: `intro_ui_check.gd` verifies intro creation, the rendered logo asset, title readiness, skip behavior and the refreshed panel style. `phase_smoke.gd` continues to cover menus, inventory and hotbar input.
