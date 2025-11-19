# Copilot Instructions - Photography Portfolio

## Project Overview
This is a static HTML5 photography portfolio gallery with a responsive masonry layout and lightbox viewer. It requires zero backend—images are loaded from a JSON manifest and rendered entirely client-side. The project is designed to work on GitHub Pages and other static hosting.

## Architecture & Core Patterns

### Image Loading Pipeline
1. **Data Source**: `images/images.json` (array of filenames) - manually curated or auto-generated
2. **Gallery Renderer**: `script.js` loads image list via fetch, then populates DOM with lazy-loaded `<img>` elements
3. **Layout**: CSS Grid with dynamic row spans based on image aspect ratios (computed on image load via `naturalHeight/naturalWidth`)
4. **Lightbox Modal**: Fixed overlay with navigation; state managed via `currentImageIndex` variable

**Key principle**: Images must exist in `images/` folder AND be listed in `images.json` or they won't display.

### Responsive Breakpoints
- **Desktop (>768px)**: Auto-fit grid with 250px minimum column width, 15px gap
- **Tablet (≤768px)**: 150px minimum columns, 10px gap, lightbox buttons scaled down
- **Mobile (≤480px)**: Single column layout, reduced padding/margins

## Developer Workflows

### Quick Start: Adding Images
```powershell
# Windows PowerShell - Auto-generate images.json from folder contents
.\generate-images-json.ps1
```
- **Verbose script** (`generate-images-json.ps1`): Handles edge cases, reports progress, sorts images by name
- **Simple script** (`generate-images-json-simple.ps1`): One-liner alternative, case-insensitive extension matching

Both scripts:
- Scan `images/` directory recursively for `.jpg, .jpeg, .png, .webp, .gif`
- Create `images/images.json` with filename array
- Exit code 0 = success

### Manual Setup (no scripts)
1. Create `images/` folder
2. Add image files to `images/` folder
3. Manually edit `images.json` with filenames (see `images/images.json` example)

## Key Implementation Details

### Image Rendering (`script.js`)
```javascript
// Fallback pattern: Try images.json first, then getImageList() hardcoded array
const response = await fetch(IMAGE_FOLDER + 'images.json');
// If fetch fails or returns empty, uses fallback array (update this for local dev)
```
- **Lazy loading**: `img.loading = 'lazy'` enables browser optimization
- **Error handling**: `img.onerror` hides broken images silently
- **Aspect ratio math**: `rowSpan = Math.ceil(aspectRatio * 30)` controls grid spacing tightness

### Lightbox Navigation
- **Click handlers**: Previous/Next buttons, close button
- **Keyboard**: Arrow keys (← →) to navigate, ESC to close
- **Modal behavior**: Clicking overlay (not image) also closes; `body.overflow = 'hidden'` prevents scroll
- **Counter**: Shows `{currentIndex + 1} / {totalImages}` in bottom bar

### Styling Notes
- **Grid row**: CSS `grid-auto-rows: 10px` is a base unit; aspect ratio multiplier of 30 scales row heights
- **Lightbox**: Semi-transparent overlay (`rgba(0,0,0,0.95)`) with flex centering
- **Hover effects**: Gallery items scale +2% with shadow on hover for affordance
- **Border radius**: 4px applied consistently to images, buttons, and counter

## Important Conventions

1. **File naming**: Image filenames in JSON must match exactly what's in `images/` folder (case-sensitive on Linux/GitHub Pages, but scripts handle case-insensitive matching)
2. **Supported formats**: JPG, JPEG, PNG, WebP, GIF (case variations handled by scripts)
3. **Configuration**: Adjustable parameters in `script.js`:
   - `IMAGE_FOLDER = 'images/'` — folder path
   - `SUPPORTED_FORMATS` — list of extensions (informational; fetch doesn't validate)
   - Row span multiplier (line 72: `* 30`) — increase for wider rows, decrease for tighter packing
4. **No build step**: Code runs directly in browser; minification/bundling not needed
5. **GitHub Pages compatible**: All paths are relative; works without a custom domain if in repository subdirectory

## Debugging Common Issues

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| No images display | `images.json` missing or malformed | Run `generate-images-json.ps1` or verify JSON syntax |
| Broken image icons | Image file not in `images/` folder or filename mismatch | Check filename case and file existence in `images/` |
| Lightbox not opening | CSS `.lightbox.active` not applying flex display | Check browser console for JavaScript errors; verify gallery item click handler attached |
| Aspect ratio distorted | Grid row span calculation off | Adjust multiplier from 30 to higher (looser) or lower (tighter) value in script.js line 72 |

## File Reference
- **index.html** — DOM structure; lightbox template and gallery container
- **script.js** — Core logic: image fetch, gallery render, lightbox state/events
- **styles.css** — Grid layout, responsive rules, lightbox & modal styling
- **images/images.json** — Image manifest (auto-generated or manual)
- **generate-images-json.ps1** — Recommended script for Windows; verbose output
