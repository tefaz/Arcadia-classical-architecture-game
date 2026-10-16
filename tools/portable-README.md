# Arcadia — Classical Builder

A first-person classical architecture sandbox with unlimited materials. This is the first playable building prototype; gathering and survival systems will be added later.

**Creative** starts selected by default. **Survival** appears in the mode selector as **Coming later** and is unavailable for now. Quickly double-tap **Space** to toggle Creative flight. Hold **Space** to rise and **Shift** to descend. Double-tap **W** and hold the second press to sprint forward, on foot or in flight. Releasing W ends sprinting; Shift still sprints on foot and descends in flight. Normal flight coasts for about 0.2 seconds and less than two metres when you release movement keys; faster flight takes a little longer to settle. Opening the library or menu stops momentum immediately. A single Space tap jumps when walking. While flying, WASD movement stays level even when you look down to place components.

## Start

Keep `arcadia.x86_64` and `arcadia.pck` together. In this folder, run:

```bash
./play.sh
```

Click **Enter sanctuary**. Use **WASD** and the mouse to explore. Press **E** to choose building pieces, or **Esc** to open the menu. The sample pavilion is editable; the open gravel plot is ready for your own building.

The window starts at **1600 × 900 (16:9)** and is resizable. **F11** fills your monitor, including 2560 × 1440 displays. The compact hotbar leaves the view clear. **H** toggles the optional controls guide, hidden by default. Flight changes and successful autosaves stay silent; manual save confirmations and errors remain visible.

The hotbar has nine editable slots (**1–9**) and a fixed **− / Stack tool**. The default ninth slot starts empty and can be filled like any other slot. Select a filled slot to build, or an empty slot for empty hands. With an empty slot selected, aim at a component to highlight it and **right-click to remove it**; **Ctrl+Z** undoes the removal. Left-click does nothing while empty-handed. The mouse wheel cycles all ten slots. The dedicated Inspect slot and 0 shortcut have been removed. A large crosshair stays visible throughout play, including with empty hands. It reads the scene behind it, staying white over dark areas and turning dark over bright stone; a thin contrasting outline preserves visibility over middle tones. Menus hide it.

The **E** library shows all 40 components in a scrollable grid. Drag a card into slots **1–9** in the hotbar underneath to replace its assignment, or drag between hotbar slots to swap them.

Drag a hotbar component outside the bar and release to empty its slot; **Esc** cancels a drag. Use **Clear slots 1–9** above the hotbar to empty all nine editable slots at once. Drag library cards into the blanks to refill them. Selecting an empty slot gives you empty hands; The Stack tool stays fixed. Click a slot to select it. Press **E** or **Esc** to close the library and build. Custom assignments, including empty slots, are saved with the world. **B** and **Tab** also toggle the library.

A single bright sun crosses the sky over a **20-minute daylight cycle**, with moving shadows and warm evening colors. **At sunset, the world instantly returns to morning.** The cycle pauses in menus and the library; saving records the current time of day. Warm sunlight and cool sky fill keep architectural details visible in shade. Use **Brightness in shade** in Settings to adjust the ambient light.

Cinematic lighting uses Forward+ with a Vulkan-capable graphics driver. Warmer sunlight, cooler shade, softer shadows and AgX tone mapping give the stone more depth. Limestone has a warmer beige base that stays distinct from white marble at noon. Balanced adds contact shading and restrained highlight glow; High adds finer shadows and screen-space indirect light. Simple disables shadows and screen-space effects. New building pieces affect lighting immediately without baking.

**Pediment doorway wall** is under **E → Structure**. It has a 1.8 m wide, 2.7 m high walk-through opening, stone jambs and a triangular pediment on both sides. It fits ordinary/window wall corners and flush ceilings. There is no raised threshold or closed door leaf; add Temple steps separately for a raised foundation entrance. M selects the finish and comma/period adjust the wall span.

Cypresses, olive trees and umbrella pines form a wooded border on the surrounding hills. Their branches, individual leaves and textured bark replace the original simple tree shapes. Trees and loose rocks stay outside the central construction clearing, with extra clearance for the canopies.

Walking is now **10 m/s**, with **18 m/s** sprinting; Creative flight is **16 m/s**, or **28.8 m/s** when sprinting. Acceleration and braking preserve the quick response of the original controls.

Smoother hills, detailed soil and gravel, and short windblown grass give the landscape more depth. Grass clears beneath ground-level structures and returns when they are removed, including undo/redo and copied groups. Existing saved buildings clear their footprints automatically when loaded. Elevated roofs leave the ground vegetation intact. Graphics quality scales grass density and viewing distance; the gravel plot and approach remain clear.

For a flat roof on a rectangular house, select **Flat roof / ceiling** or **Foundation** and aim at a wall top or its upper section from inside. With grid and sockets enabled, **Flush wall cover** follows the outer wall faces. Extend from panel sides or use Stack; edge panels fit the room automatically. T selects manual ceiling anchors, and Alt allows free placement. Remove and re-place older offset test slabs to use the new alignment.

Requirements: 64-bit x86 Linux and a graphical desktop. For older hardware with OpenGL 3.3 / OpenGL ES 3.0, run `./play.sh --rendering-method gl_compatibility` to use the lightweight lighting fallback. No Godot installation or internet connection is needed. The executable was tested under X11 and Wayland on Linux with an AMD GPU; other GPUs and distributions have not been individually tested.

**Middle-click** a placed component to equip it. If its kind is already in slots 1–9, that slot is selected; otherwise it replaces the currently selected editable slot, including an empty slot. Picking also uses its stone finish. When Stack is selected, a missing component uses your previous building slot so the fixed tool stays available. Picking respects reach and is disabled in menus.

## Controls

| Action | Key |
| --- | --- |
| Move / sprint | WASD / double-tap W and hold; Shift also sprints on foot |
| Look | Mouse |
| Jump / fly up; fly down | Space; Shift |
| Toggle Creative flight | Quickly double-tap Space (within 0.3 seconds), or F |
| Place / remove aimed piece | Left / right click |
| Pick aimed component | Middle mouse button |
| Select building hotbar slot | 1–9 / mouse wheel |
| Empty hands; remove aimed component | Select any empty slot; right-click to remove |
| Equip dedicated Stack tool | − key, wheel, or library hotbar |
| Set first / second selection point with the tool | Left / right click |
| Repeat toward / away from the view | Mouse wheel forward / backward |
| Cancel / confirm stack | Left / right click; Esc also cancels |
| Open / close building library | E / B / Tab |
| Rotate 90° / 15° | R / Shift+R |
| Lower / raise piece | Page Down / Page Up; Q also lowers |
| Reset height | Home |
| Shorten / lengthen walls, entablatures, cornices, balustrades | Comma / period: 0.5 m |
| Restore automatic span fitting | / |
| Switch attachment anchor | T |
| Stone finish | M |
| Grid / socket snapping | G / C |
| Temporarily bypass snapping | Hold Alt |
| Placement reach | [ / ] |
| Undo / redo | Ctrl+Z / Ctrl+Y |
| Save / load | F5 / F9 |
| Show / hide optional controls | H |
| Fullscreen / menu | F11 / Esc |

The library has 40 components, including complete Doric, Ionic, and Corinthian columns with their feet, shafts, and capitals already included. Foundation tops show **marked centres and dashed 4 m guide lines** while placing columns. Columns snap to the same bay grid so entablatures can form a closed rectangle. The layout follows compatible existing columns on the connected platform. Hold **Alt** to place freely. Equip **Entablature** and aim at a column top: the beam starts at its end by default. **R** turns the beam at a corner; **T** reverses its direction. Corners and closing spans fit automatically. The Attic base was the moulded column foot. Separate column parts are retired from the library; old placed parts remain in saved buildings, and old hotbar assignments switch to complete columns. Choose limestone, marble, or sandstone. Arches have open doorways; roofs offer terracotta tiles or matching stone slabs and hollow domes.

The **Foundations** filter offers flush structural blocks with 4 × 4 m footprints: **Foundation** at 0.4 m, **Raised terrace** at 0.8 m, and **Temple podium** at 2 m. Repeat them sideways or vertically to make larger continuous foundations; recessed joints mark shared 0.4 m stone courses without projecting ledges. Decorative **Paved walkway** and **Courtyard paving** retain their 8 × 4 m and 8 × 8 m patterns. Foundations snap along four-metre bays and align their bases beside different-height neighbors.

Equip **Temple steps** and aim at a foundation's **side at the desired landing**. The flight automatically turns toward the edge and fits from ground level to its exact top, including stacked platforms. A 0.4 m slab gets two steps, a 0.8 m terrace four, a 2 m podium ten, and a 2.4 m platform twelve. Risers stay at most 0.2 m; each tread adds 0.5 m of run. The solid stair body needs no separate supports. Repeat flights sideways for wider entrances. Clear enough space for the full run; blocked stairs cannot silently become a shorter flight. On open ground, stairs retain their original four-step size. Disabling sockets or applying a manual height offset bypasses fitting. Existing stairs stay at their saved size. **Stair support** remains available for manually raised flights.

Walls, entablatures, cornices, and balustrades start at four metres and automatically fit matching gaps from 0.5 to 3.5 m, including the first beam between aligned column tops. Matching profiles form mitred right-angle corners, including both ends of a closing span. Use **comma / period** to choose a fixed length from 0.5 to 8 m, and **/** to restore **Auto**. The HUD shows the actual length and **Fitted to gap**. Use **T** for the opposite attachment end. Lengths survive saves, undo/redo, and stacking; existing saves retain their placements and four-metre defaults.

Foundation support sockets use regular two-metre spacing, keeping opposite supports compatible with four-metre beam bays. The half-metre grid follows an aimed building's rotation and origin, preserves exact support heights, and aligns adjustable spans by their endpoints. On open ground the grid follows the selected rotation. Snapping skips blocked connections when a nearby clear placement is available.

A green preview is valid; a coral preview explains a blocked placement. Aim at the **top face** to build on top, a **side face** to build beside it, or the **underside** to attach below. Snapping uses only the aimed component and matching face; blocked connections stay blocked instead of jumping to another face or neighboring component. Looking at ground uses the ground grid. Use flight for tall buildings. T cycles a beam's centre and end anchors. Height changes bypass component snapping until you reset the height. Foundations and bays can connect at their edges. Creative buildings do not collapse and can be deliberately unsupported.

## Large pediments and sculpture

Open **E**, then use the **Pediments** filter for left/right slopes, a crown, recessed tympanum backing, and a base cornice. Modules are four metres wide. Connected rakes and crown ends continue their diagonal mouldings and dentils without notches; exposed eaves retain their trimmed ends. Aim at a left slope's high end to continue **4 m across and 2.4 m up**; add a crown, then descend with right slopes. One slope on each side makes **12 m**, two make **20 m**, and three make **28 m**. Fill beneath the raised sections with backing courses, each 2.4 m high, and run base cornices along the bottom. Fly to reach the upper joins.

The **Sculpture** filter contains a **Draped statue**, **Reclining figure**, and **Horse relief**. Aim at a backing block's recessed front to attach a standing figure or horse; the preview reads **Sculpture recess**. Reclining figures attach inside the sloping corners. **R** turns figures and horses: point reclining heads uphill and turn horses toward one another. Keep **C** snapping enabled and reset height with **Home**. Stone finishes, undo/redo, demolition, and saving work as usual. The original four-metre pediment remains available.

## Modular roofs

Open **E → Roofs** for **Terracotta Roof Slope** (4 m across, 2.4 m rise) and **Terracotta Roof Half Slope** (2 m across, 1.2 m rise). All are hollow tiled shells and repeat in 4 m depth bays. Aim at a matching **pediment's rear face** to attach the first roof piece. A pediment crown takes two half slopes, with one turned 180° using **R twice**. Aim near a roof's high/low edge to continue across the pitch, or its front/back edge to repeat along the building; **R** rotates it. Two small halves make the original 4 m roof; add large slopes below them to fit 12, 20 or 28 m pediments, or pair large slopes directly for 8/16 m roofs. Rear gables snap back onto roof ends. Shells cut back at attached gables to clear cornices and finials while keeping the building on the four-metre grid. Existing saved whole roofs remain unchanged; their hotbar assignment becomes Terracotta Roof Half Slope.

## Stacking copies

Equip the dedicated **Stack tool** slot with the wheel, **−** key, or library hotbar. Hovering highlights the first point **red** and the second point **green**; selected parts keep a subtle tint, with muted red/green endpoints. **Left-click** the first component, then **right-click** the last component. The highlighted box selects components whose centres lie between the endpoints, following the first piece's orientation. Individual outlines show the selected parts. Scroll forward to repeat toward your view or backward to repeat away from it, passing through zero to switch sides. Look up or down for vertical stacking; backward scrolling reverses that direction too. Direction follows the closest component axis. Layout, rotation, and finish are preserved, and spacing follows the group's combined dimensions. For a single-piece stack, select the same component with both clicks. Scrolling starts repeating only after both points are set.

**Left-click cancels; right-click confirms.** Originals stay in place. Up to 32 repeated sets can preview at once, limited to 256 total preview components. A blocked array stays in preview; no partial stack is placed. **Ctrl+Z** undoes the entire confirmed batch; **Ctrl+Y** redoes it. Previews have no collision and are omitted from saves. Esc, switching slots, or opening a menu cancels the tool. Ctrl+Z while selecting or previewing cancels without undoing prior building.

## Stone roofs and domes

Open **E → Roofs** for **Stone Roof Slope** and **Stone Roof Half Slope**, matching the terracotta profiles. Use **R twice** to turn a slope 180° for the opposite side. Press **M** to choose limestone, marble, or sandstone. Broad slab joints replace the terracotta tiles.

**Dome roof** covers 4 × 4 m and rises 2.4 m; **Grand dome roof** covers 8 × 8 m and rises 4.4 m. Their interiors stay hollow, with square bases covering the room corners. Aim at a matching wall or entablature run's top to centre the dome over the room. **R** turns the attached edge; **T** cycles centre, edge, and corner anchors. Foundations use the centre anchor by default.

**Flat roof / ceiling** is a 4 × 4 m slab, 0.2 m thick, with a flat underside. Its default edge anchor keeps it extending inward from an entablature. **T** cycles four edges, four corners and the centre; **R** turns it. Corner anchors fit beam endpoints. Aim at a slab's side to tile another beside it, or use Stack for larger ceilings. **M** selects limestone, marble or sandstone.

## Classical windows

**E → Structure** offers **Pediment window wall** (rectangular opening with triangular pediment), **Curved pediment window** (rectangular opening with a shallow segmental pediment, recessed centre and layered cornice above), and **Elliptical window wall** (half-ellipse arched opening). All three are 4 m wide and 4.1 m tall, with open holes, sills and stone surrounds on both faces. They fit plain walls, foundations and entablatures, including mixed wall corners. **M** changes the finish; **R/T** rotate or change the attachment anchor. Comma/period and automatic fitting adjust their length; short bays narrow the opening to fit.

## Walls along foundation edges

Aim at the **top near an outside foundation edge** with a plain or window wall equipped. **R** turns it parallel to that edge. The wall's outer masonry snaps flush with the foundation; the preview automatically fits end bays so perpendicular walls close with proper mitres. Connected foundations share one perimeter, including stepped and L-shaped platforms. Window surrounds retain their normal decorative projection.

Keep grid/socket snapping enabled (**G/C**) and use **/** for automatic length fitting. The HUD shows **Flush foundation edge** and the exact fitted length. **Alt**, explicit lengths, manual height offsets, and **T** end anchors retain manual placement. Existing buildings stay in their saved positions.

Double-tap W sprint requires two distinct presses within 0.3 seconds. Releasing W, pressing backwards, opening a menu/library, changing flight mode, loading a world, or losing focus clears sprint state.

The **Corinthian column** now has two crowns of carved acanthus leaves with raised veins, corner volutes, inward scrolls, floral ornaments and a concave moulded abacus. Its 4.3 m height and attachment points are unchanged, and existing placed columns update automatically. The detail uses your chosen limestone, marble or sandstone finish.

The **Doric column** has a smoother cushion, fine neck rings and a chamfered abacus. The **Ionic column** has solid carved volutes, side bolsters, egg-and-dart ornament and a beaded neck. Both remain 4.1 m tall with their original attachment points, support heights and stone finishes; existing columns update automatically.

Flat ceiling panels fit automatically against the backs of pediments, including large modular gables. Place the ceiling or pediment first; the panel edges trim while keeping their four-metre spacing. Removing the pediment restores the full slab. Stacked copies also fit at their destination.

Modular pediments automatically reach the outer left and right corners of the entablature run. Their slopes, crown, backing and base fit together continuously, with a stone cap covering the roof edge from the front. Existing saved placements update automatically.

A square entablature ring can carry two pediments, roof slopes and a complete flat ceiling together. Ceiling tops taper automatically beneath the eaves while the underside remains flat. Build the roof or ceiling first. If a roof hides the beam top, aim at the room-facing side of the entablature; R turns the ceiling inward and T cycles anchors. Side snapping and Stack fill the remaining ceiling bays.

Ceiling tiles can also fit across roof bays when their grid is offset by half a metre. Aim near an entablature, pediment or roof beside your existing ceiling to fill a missing bay on the same ceiling grid. Existing tiles keep their positions.

**Rectangular pedestal** (Details) and **Lion statue** (Sculpture) are separate building pieces. Place the broad rectangular plinth, then aim at its top to centre the reclining lion. R rotates each piece; M selects limestone, marble or sandstone. The statue has a full carved mane, raised head, paws and curled tail; both pieces support ordinary picking, history, saving and stacking.
