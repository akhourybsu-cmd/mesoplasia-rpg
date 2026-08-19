# Caden Environment Art Bible

## Purpose and Scope

This document defines the initial environment-art standard for Caden, with Town Square serving as the visual vertical slice. It guides asset creation and scene dressing while preserving the established gameplay layout, technical baseline, and canon boundaries.

This is an art-production standard, not a source of new Mesoplasia lore. When a visual choice would imply an unidentified institution, tradition, historical event, symbol, or landmark, use a neutral treatment or request clarification rather than establishing canon through artwork.

## Art Direction Summary

Caden is a cozy, rustic Halcyon-Age town outside Terrebonne. It should feel warm, welcoming, homey, modest, and cabin-like. The environment should suggest a safe, lived-in stopping place without making Caden look grand, dense, or urban.

Town Square establishes the standard for later Caden environments. Its visual finish should support the same town-wide language without requiring every zone to use identical arrangements or props.

Core visual qualities:

- Warm and approachable rather than imposing.
- Rustic and maintained rather than pristine or neglected.
- Modest in scale and material richness.
- Lived-in without becoming visually crowded.
- Cohesive across terrain, architecture, vegetation, and props.
- Immediately readable as a playable top-down space.

## Technical Visual Standards

- Build environment art around the established `32 x 32`-pixel world-tile logic.
- Align terrain transitions, building footprints, collision-relevant edges, gates, and primary path boundaries to the tile grid wherever practical.
- Smaller pixel-art details may use subdivisions of a tile, but must not make collision or traversal boundaries ambiguous.
- Use a top-down view with a slight three-quarter presentation for building fronts and props. Roofs and façades may show depth, while their ground footprints remain clear.
- Preserve crisp pixel rendering. Assets should be authored for nearest-neighbor display without smoothing, unintended antialiasing, or fractional-pixel placement.
- Judge art at the project's `640 x 360` internal resolution, not only while zoomed in during asset creation.
- Favor gameplay-first composition. Traversable routes, obstacles, entrances, NPC silhouettes, and interaction points must remain understandable at a glance.
- Avoid fine detail that disappears, flickers, or becomes noisy at the internal resolution.
- Visible art may extend beyond a collision footprint, but the relationship between the image and the blocking area must remain predictable.

## Environment Standards

### Grass

- Use a calm, cohesive grass base rather than high-contrast noise on every tile.
- Break repetition with restrained clusters, tufts, flowers, worn patches, or subtle value variation.
- Concentrate secondary detail near boundaries, buildings, fences, and low-traffic edges.
- Keep primary walking space quieter so characters, prompts, and paths remain readable.
- Do not scatter isolated decorative pixels uniformly across the entire scene.

### Roads and Paths

- Roads and paths must read clearly against grass through deliberate hue, value, and edge treatment.
- Main routes should appear broader and more continuous than minor access paths.
- Preserve uninterrupted visual flow between zone entries, the plaza, and connecting routes.
- Variation such as stones, ruts, or worn patches should reinforce direction of travel rather than obscure it.
- Avoid decorative obstacles in the center of primary circulation lanes.

### Plaza Paving

- Plaza paving should be distinct from surrounding roads and grass while remaining part of the same rustic palette.
- Use an orderly but not overly formal pattern. Subtle variation is appropriate; ornate civic motifs are not established.
- Keep the center and primary crossing routes visually open.
- Use edging, tonal shifts, or paving direction to clarify the plaza boundary without making it resemble a grand urban square.

### Terrain and Material Transitions

- Use purposeful transition tiles between grass, paths, paving, building foundations, and other ground materials.
- Favor softened, irregular natural edges for grass-to-earth transitions while retaining tile-grid compatibility.
- Use cleaner constructed edges where paving meets architecture or maintained boundaries.
- Avoid abrupt seams, isolated transition fragments, and excessive single-tile edge noise.
- Corners, junctions, and narrow passages must remain visually consistent with their collision.

### Foliage Density

- Keep foliage denser around the perimeter, beside buildings, and in intentionally non-traversable pockets.
- Use lower density near entrances, exits, interaction points, and primary routes.
- Cluster foliage into deliberate shapes rather than distributing it evenly.
- Preserve open sightlines through Town Square and around NPCs.
- Foliage must not imply a passable gap where collision blocks movement, or conceal a real route.

### Fences and Boundaries

- Favor modest wood and low stone treatments compatible with Caden's rustic material language.
- Boundary shapes should be simple, practical, and clearly readable from the play view.
- Gates and openings must align visually with traversable paths and collision gaps.
- Use heavier visual blocking where the player cannot pass; do not rely on invisible collision for ordinary environment boundaries.
- Avoid ornate, monumental, fortified, or institution-specific boundary designs unless separately approved.

### Prop Density

- Use props to suggest regular habitation and travel without filling every available tile.
- Place props in small related clusters near buildings, edges, and activity areas.
- Leave primary walking corridors and interaction approach spaces clear.
- Give important interactive or collision-bearing props more visual separation than background decoration.
- Reuse a controlled prop vocabulary, with variation, instead of combining unrelated fantasy objects.
- Every prop should support composition, material language, navigation, or atmosphere; omit filler that only adds noise.

## Architecture Standards

### Scale and Proportions

- Keep buildings modest and broad enough for doors, porches, and façades to read at game scale.
- Base ground footprints and collision-relevant elements on the `32 x 32` grid.
- Doorways, steps, porches, and approach paths should align with clear player access where entry is intended.
- No structure should visually exceed two stories.
- Avoid exaggerated vertical scale that makes Caden feel urban, aristocratic, or monumental.

### Roofs

- Favor simple pitched or gabled roof silhouettes with consistent three-quarter projection.
- Keep roof pitch and visible plane angles consistent across a shared building set.
- Use restrained overhangs that communicate depth without hiding doors, paths, or nearby characters.
- Roof complexity should reflect modest construction; avoid towers, elaborate spires, oversized domes, or grand ornamental profiles.
- Roof variants may add visual rhythm, but must retain a common Caden construction language.

### Materials

- Timber should provide the dominant warm structural language.
- Stone may support foundations, chimneys, steps, retaining edges, and practical accents.
- Materials should appear sturdy, familiar, and maintained rather than luxurious, industrial, or severely ruined.
- Use consistent pixel scale, outlining, and texture density across wood, stone, roofing, and trim.
- Do not mix incompatible fantasy architectural styles merely to increase variety.

### Doors, Windows, Porches, and Chimneys

- Doors must be clearly identifiable and scaled relative to the Player and NPCs.
- Windows should use simple shapes, consistent placement logic, and restrained highlights.
- Porches should read as usable transition spaces and should not narrow routes or conceal collision boundaries.
- Chimneys should be proportionate to the roof and use the established timber-and-stone language.
- Decorative trim should remain secondary to building silhouette and entrance readability.
- Do not introduce symbols, crests, business identities, or institutional markings without approved content direction.

## Lighting and Shadows

- Use one consistent environmental light direction across Caden asset sets and assembled scenes. For the initial Town Square set, treat light as coming from the upper-left of the screen.
- Keep environmental shadows soft-edged in shape language, even when rendered with crisp pixel clusters.
- Use restrained shadow lengths so buildings and props feel grounded without covering large portions of traversable space.
- Maintain readable contrast inside shadows; paths, collision edges, NPCs, and interaction points must not disappear.
- Contact shadows should help explain where buildings, foliage, fences, and props meet the ground.
- Avoid isolated highlights or shadows that contradict the scene-wide light direction.
- Lighting should reinforce Caden's warm welcome without flattening all material and depth differences.

## Color and Palette Philosophy

- Use a warm, cohesive, rustic palette across Caden.
- Keep palette families related, but preserve clear value and hue separation between grass, roads, plaza paving, buildings, and props.
- Reserve the strongest contrast and saturation for information that benefits from attention, including characters, entrances, and interactable elements.
- Use controlled warm neutrals for timber and stone rather than allowing every surface to converge into the same brown value range.
- Keep vegetation distinct from paths and roofs even under shared lighting.
- Avoid muddy scenes in which adjacent materials share nearly identical values.
- Test readability in grayscale or reduced saturation when evaluating separation between major gameplay surfaces.
- Palette additions should be deliberate and reusable rather than unique colors introduced for isolated props.

## Player and NPC Scale Guidance

- Character collision footprints remain designed around the `32 x 32` tile grid, although visible sprites may extend beyond one tile.
- Player and NPC sprites must remain large enough to read clearly against terrain while still feeling appropriately scaled beside doors, porches, fences, and props.
- Use strong, recognizable silhouettes for bodies, heads, carried objects, and directional facing.
- Preserve visible separation between characters and similarly colored ground or building surfaces.
- Environment props should not routinely match character height and silhouette unless their scale makes that relationship clear.
- Building doors and architectural features should make characters feel human-scaled without making modest buildings appear miniature.
- Avoid environment detail that competes with character silhouettes at normal play scale.

## Festival Subtext

- Festival-related visual touches must remain background subtext in the Caden vertical slice.
- Any approved touches should be sparse, optional to notice, and subordinate to navigation and everyday town life.
- Generic blue-and-cream ribbons or fabric decorations may be used sparingly as approved background subtext. Do not invent Festival symbols, crests, religious imagery, relic imagery, historical iconography, ceremonies, artifacts, or traditions.
- Use only approved narrative references when Festival-specific visual content is requested.
- In the absence of approved specifics, prefer neutral signs of increased travel or preparation that do not establish new lore.

## Edenite Accent Direction

- Blue Edenite illumination is an important visual identifier of Mesoplasia.
- Caden may use restrained Edenite-blue fixtures and accents.
- Edenite remains an accent rather than the town's dominant palette.
- Only a small number of visibly glowing elements should normally appear within one `640 x 360` camera view.
- Edenite should not be attached indiscriminately to every building, lamp, fence, roof, or prop.
- The approved effect uses sapphire/cyan blue with restrained pale-blue glow.
- Warm timber, stone, greenery, and cream remain the dominant Caden palette.
- Generic blue-and-cream Festival-period ribbons or fabric decorations are visually approved when used sparingly.
- No Festival symbols, crests, religious imagery, relic imagery, or historical iconography may be invented.
- The reserved Town Square community space remains undefined.
- Edenite pedestal and crystal assets from the source sheet are optional reference components and are not authorization to create a permanent centerpiece, monument, shrine, or fountain.

## Town Square Visual-Slice Rules

- Preserve the locked scene footprint and established connection logic unless a later layout revision is explicitly approved.
- Preserve the plaza's openness and keep its principal crossing routes unobstructed.
- Maintain clear visual routes to Wayfarer's Approach, the Residential Quarter, the Marketplace, and the Commons.
- Keep zone entries, exits, NPC approach spaces, and transition corridors easy to identify through composition rather than labels alone.
- Building art should respect the established generic footprints and must not imply unapproved building identities.
- Keep the road toward Terrebonne visually legible while preserving its current blocked gameplay state. Do not use art to invent a reason for the closure.
- The reserved central community space remains undefined. Do not assign it a monument, institution, ritual use, symbol, or permanent prop without approval.
- Concentrate decorative density around edges and building-adjacent areas, leaving the plaza and main routes comparatively calm.
- Technical development labels and placeholder geometry must not influence final visual identity except where they represent approved dimensions, routes, collision, or reserved space.

## Things to Avoid

- An overly urban, dense, or capital-like appearance.
- Gothic grandeur, monumental silhouettes, or aristocratic ornament.
- Excessive prop, foliage, texture, or color clutter.
- Industrial materials, machinery, mass-produced styling, or heavy infrastructure.
- Generic random-fantasy mixing that weakens the shared Caden visual language.
- Unreadable material boundaries or collision that conflicts with visual cues.
- Structures that appear taller than two stories.
- Ornate civic, religious, political, factional, or Festival imagery that has not been approved.
- Environmental storytelling that silently establishes new history, institutions, characters, or events.
- Final-detail work that compromises route clarity, plaza openness, or character readability.

## Maintaining This Standard

Town Square is the first production reference for Caden, not the final limit of its visual vocabulary. Update this document deliberately as approved art establishes reusable materials, palette choices, tile families, architectural modules, and prop sets. Any addition that affects Mesoplasia canon must be resolved through the project's canon process rather than inferred from visual needs.
