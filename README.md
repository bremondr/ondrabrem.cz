# Photography Portfolio - Setup Instructions

## File Structure
```
project-folder/
│
├── index.html
├── styles.css
├── script.js
└── images/
    ├── images.json
    ├── photo1.jpg
    ├── photo2.jpg
    └── ... (your photos)
```

## Setup Steps

1. Create an `images` folder in your project directory
2. Add all your photos to the `images` folder
3. Create an `images.json` file inside the `images` folder
4. List all your image filenames in `images.json` (see template below)

## images.json Template
```json
{
  "images": [
    "landscape1.jpg",
    "wildlife1.jpg",
    "landscape2.jpg",
    "wildlife2.jpg"
  ]
}
```

## Features
- Automatic image loading from images folder
- Responsive masonry grid layout adapting to image aspect ratios
- Lightbox viewer with full-screen images
- Navigation: Click next/prev buttons OR use keyboard arrows (← →)
- Press ESC to close lightbox
- Mobile-friendly design

## Notes
- Supported formats: JPG, JPEG, PNG, WebP, GIF
- Images automatically lazy-load for better performance
- Grid automatically adjusts based on image aspect ratios
- Works on GitHub Pages without backend

## For GitHub Pages Deployment
1. Push all files to your repository
2. Enable GitHub Pages in repository settings
3. Your portfolio will be live at: username.github.io/repository-name
