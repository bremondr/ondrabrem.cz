# PowerShell Script Manual

Use this guide to remember what every `.ps1` helper does, when to run it, and which knobs you can turn. All examples assume you launch PowerShell from the project root so paths such as `images\images.json` resolve correctly.

## Common Requirements
- PowerShell 5.1+ (ships with Windows) or PowerShell 7.
- The default folder layout from this repo (`images`, `originals`, `ultimate`, …).
- `images\images.json` is UTF-8 encoded; every script writes UTF-8.
- Supported image extensions: JPG, JPEG, PNG, WEBP, GIF unless otherwise noted.
- Keep a backup of `images\images.json` before running batch scripts if you are unsure of the outcome.

---

## `process-originals.ps1`
**Purpose:** End-to-end pipeline that ingests everything under `originals\`, cleans filenames, resizes images, moves them to `images\`, and updates `images\images.json` without disturbing pre-existing entries.

**What it does**
- Recursively scans `originals\` (or any folder passed via `-SourceRoot`) and picks up every supported image, no matter how deeply nested.
- Converts filenames to lowercase ASCII slugs so they are web safe, while keeping extensions intact.
- Resizes each image so its longest edge equals `-MaxDimension` (default 2000 px); smaller files are copied untouched.
- Captures every subfolder in the relative path as a keyword (e.g., `originals\Birds\Owls\shot.jpg` → keywords `["Birds","Owls"]`).
- Writes the processed files into `images\` (or `-DestinationFolder`) and reuses existing filenames unless you pass `-OverwriteExisting`.
- Loads `images\images.json`, appends new entries, and merges keywords with existing ones to preserve manual edits.

**Parameters**
- `-SourceRoot` (default `originals`)
- `-DestinationFolder` (default `images`)
- `-MaxDimension` (default `2000`)
- `-OverwriteExisting` (switch)

**Usage**
```powershell
pwsh .\process-originals.ps1 `
    -SourceRoot originals `
    -DestinationFolder images `
    -MaxDimension 1800
```

**Tips**
- Run from the project root so the default relative paths resolve automatically.
- The script leverages .NET `System.Drawing`, so run it on Windows PowerShell / PowerShell 7 on Windows.
- Folder names feed keywords verbatim (spaces preserved); rename the directories if you prefer different keywords.
- Older helper scripts still exist for targeted chores, but `process-originals.ps1` replaces the usual rename/resize/JSON stack in one pass.

---

## `generate-images-json.ps1`
**Purpose:** Scans the `images` folder and builds/updates `images\images.json` where each entry contains `file`, `name`, and `keywords`.

**How it works**
- Creates the `images` folder when missing.
- Collects every file in `images` whose extension is in `$supportedExtensions`.
- Loads the current JSON (if it exists) and reuses existing metadata (`name`, `keywords`) by matching on `file`. New files become blank entries with empty keyword arrays.
- Outputs a sorted list of image objects under `{ "images": [...] }`.

**Usage**
1. Add or remove files in `images\`.
2. Run `pwsh .\generate-images-json.ps1` (or `powershell.exe`).
3. Confirm the console summary and spot-check the JSON.

**Configuration Tips**
- Edit `$imagesFolder`, `$outputFile`, or `$supportedExtensions` at the top of the script if you need to point to another directory or allow extra formats.
- Populate names/keywords manually inside `images.json` after generation; rerunning the script preserves those edits as long as filenames stay the same.

---

## `generate-images-json-simple.ps1`
**Purpose:** Fast, no-frills alternative that recreates `images\images.json` from scratch without merging metadata.

**How it works**
- Recursively finds all images under `images\`.
- Builds objects with `file`, `name` (derived from filename), and an empty `keywords` array.
- Overwrites `images\images.json`.

**Usage**
1. Use when you just need a quick inventory or are starting from zero.
2. Run `pwsh .\generate-images-json-simple.ps1`.
3. Edit the resulting JSON if you need friendly names or keywords.

**Configuration Tips**
- Adjust the `Get-ChildItem` `-Path` or `-Include` filters if your asset folder lives elsewhere or uses different extensions.
- Because it wipes metadata, keep a backup if you care about existing names or tags.

---

## `rename-images.ps1`
**Purpose:** Removes leading underscores from filenames in `images\` and keeps `images\images.json` in sync.

**How it works**
- Loads `images\images.json` and stops if parsing fails (so you never write over corrupt data).
- Finds every supported image whose name starts with `_`.
- Renames each file (`_DSC0001.jpg` → `DSC0001.jpg`) and updates the matching JSON entry’s `file` plus `name` (derived from the new filename).
- Saves the updated JSON with UTF-8 encoding.

**Usage**
1. Make sure `images\images.json` is valid JSON.
2. Run `pwsh .\rename-images.ps1`.
3. Review the console output; it lists every rename and whether a JSON entry was updated.

**Configuration Tips**
- Change `$imagesFolder` if your working directory differs.
- Extend the extension whitelist in the `$filesToRename` filter if you work with other formats.

---

## `resize-images.ps1`
**Purpose:** Batch-resize images so their longest edge is a fixed size (default 2000 px) while keeping aspect ratio.

**Parameters**
- `-SourceFolder` (default `images`): where originals live.
- `-OutputFolder` (default `images_resized`): where resized copies are written.
- `-MaxSize` (default `2000`): target pixel dimension for the long edge.
- `-Overwrite` (switch, default `False`): replace files in the output folder when set.

**How it works**
- Uses .NET’s `System.Drawing` APIs (Windows requirement) to load, resize, and save each image.
- Skips files that already exist in the output folder unless `-Overwrite` is supplied.
- Copies images that are already smaller than `MaxSize` without resizing.
- Writes JPEGs with 90% quality; other formats keep their original encoding.

**Usage Examples**
- Resize originals once: `pwsh .\resize-images.ps1 -SourceFolder originals -OutputFolder images -MaxSize 1600`.
- Refresh existing resized set: `pwsh .\resize-images.ps1 -OutputFolder images -Overwrite`.

**Configuration Tips**
- Ensure the output folder exists or let the script create it; consider pointing it at `images` when you want to immediately publish the smaller files.
- Because `System.Drawing` locks files while processing, avoid editing the same images in another program simultaneously.

---

## `ultimate\add-event.ps1`
**Purpose:** Imports an entire event (folder of photos) by web-safing filenames, optionally resizing them, copying them into `images\<event-folder>`, and adding the event structure to `images\images.json`.

**Parameters**
- `-EventName` *(required)*: Friendly name that appears in JSON.
- `-FolderPath` *(required)*: Path to the folder containing the source images.
- `-MaxDimension` *(optional, default `1920`)*: Long-edge size for resized copies.

**How it works**
- Generates a slug from the source folder name (lowercase, hyphenated, ASCII) for both the target folder and the JSON `folder` field.
- Tries to resize via `ffmpeg`, then `magick` (ImageMagick). If neither exists it copies the originals untouched.
- Normalizes any existing entries under the same event so that re-running the script preserves previously edited `name`/`keywords`.
- Saves results inside the `images.events` array with structure: `{ name, folder, images: [ { file, name, keywords }...] }`.

**Usage**
```powershell
pwsh .\ultimate\add-event.ps1 `
    -EventName "Perseid Meteor Shower 2024" `
    -FolderPath "D:\Photos\Perseid2024" `
    -MaxDimension 2048
```
1. Verify the console log for copy/resize operations.
2. Inspect `images\<slug>\` to ensure the files look correct.
3. Open `images\images.json` and update `name`/`keywords` if needed.

**Configuration Tips**
- Install [FFmpeg](https://ffmpeg.org) or [ImageMagick](https://imagemagick.org) and add them to `PATH` for the best resizing results; otherwise the script simply copies files.
- If your `images.json` currently uses the flat `images` array instead of `events`, you can still run the script—just be consistent about how the front end reads the file.
- The filename sanitizer is conservative; rename the source files first if you need a very specific output name.

---


## Quick Reference
- Full pipeline from `originals\` -> `images\` with keywords and JSON updates -> `process-originals.ps1`.
- Refresh gallery metadata only -> `generate-images-json.ps1`.
- Quick rebuild from scratch -> `generate-images-json-simple.ps1`.
- Strip leading underscores and sync JSON -> `rename-images.ps1`.
- Create resized copies for publishing or storage -> `resize-images.ps1`.
- Import a whole event/folder with optional resizing and JSON integration -> `ultimate\add-event.ps1`.
