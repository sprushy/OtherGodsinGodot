# Pop-up book board

An interactive 3D art study of the Other Gods field, available through **Pop-up Book** on the main menu. Open `res://scenes/popup_book_board.tscn` directly in Godot to work on the scene in isolation.

The board is an open clothbound book with layered pages, printed lane frames, cut-paper figures with folded supports, god shrines, power ribbons, deck stacks, graves, an abyss, paper trees, mountains, clouds, and a hanging sun. Its five lanes and four ranks follow the current field. All scenery is built from native meshes; the paper shader adds fine grain without new bitmap assets.

- Hover a field figure, god, power ribbon, or hand card to see the existing card's name and ability.
- Select a hand card, then an empty teal slot, to pop a figure onto the page.
- Select a friendly field figure, then an empty teal slot, to move it.
- Right-drag to turn the camera; scroll to zoom.
- Press Escape to clear the selection.
- **Fold book** / **Open book** animates the leaves, scenery, shrines, and field figures.
- **Reset field** restores the sample arrangement and hand.
- **Back to menu** returns to the regular game.

This scene is a presentation prototype with a sample field. Placement and movement are diorama interactions; it does not run match rules, spend mana, or connect to a server. Existing matches use their current board. Card names, stats, and ability text are read from the current card scripts; counters and power labels are illustrative.

Implementation: `scripts/three_d/PopUpBookBoard.gd` assembles the scene and handles interaction, `scripts/three_d/PaperCraft.gd` builds the paper geometry, and `shaders/popup_paper.gdshader` supplies its material.
