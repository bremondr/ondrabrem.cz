// Configuration
const IMAGE_FOLDER = 'images/';
const SUPPORTED_FORMATS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

// State
let images = [];
let visibleImages = [];
let selectedTags = new Set();
let currentImageIndex = 0;

// DOM Elements
const gallery = document.getElementById('gallery');
const tagFiltersContainer = document.getElementById('tag-filters');
const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightbox-img');
const lightboxCounter = document.querySelector('.lightbox-counter');
const closeBtn = document.querySelector('.lightbox-close');
const prevBtn = document.querySelector('.lightbox-prev');
const nextBtn = document.querySelector('.lightbox-next');

// Initialize gallery
async function initGallery() {
    try {
        // Attempt to load images list from images.json
        const response = await fetch(IMAGE_FOLDER + 'images.json');
        if (response.ok) {
            const data = await response.json();
            images = normalizeImages(data.images);
        } else {
            // Fallback: Use predefined image list
            images = normalizeImages(await getImageList());
        }

        if (images.length === 0) {
            gallery.innerHTML = '<p style="text-align: center; color: #666;">No images found. Please add images to the "images" folder and create an images.json file.</p>';
            return;
        }

        buildTagFilters(images);
        applyFilters();
    } catch (error) {
        console.error('Error loading images:', error);
        // Try fallback
        images = normalizeImages(await getImageList());
        if (images.length > 0) {
            buildTagFilters(images);
            applyFilters();
        } else {
            gallery.innerHTML = '<p style="text-align: center; color: #666;">Error loading images. Please create an images.json file in the images folder.</p>';
        }
    }
}

// Fallback image list (update with your actual image filenames)
async function getImageList() {
    // This is a fallback list - you should create images.json with your actual images
    return [
        { file: 'image1.jpg', name: 'image1', keywords: [] },
        { file: 'image2.jpg', name: 'image2', keywords: [] },
        { file: 'image3.jpg', name: 'image3', keywords: [] },
        { file: 'image4.jpg', name: 'image4', keywords: [] },
        { file: 'image5.jpg', name: 'image5', keywords: [] }
    ];
}

// Normalize images to objects with file/name/keywords
function normalizeImages(list) {
    return (list || [])
        .map((item, index) => normalizeImageEntry(item, index))
        .filter(img => img.file);
}

function normalizeImageEntry(item, index) {
    if (typeof item === 'string') {
        return {
            file: item,
            name: stripExtension(item) || `Photo ${index + 1}`,
            keywords: []
        };
    }

    const file = item.file || item.src || item.path || '';
    return {
        file,
        name: item.name || stripExtension(file) || `Photo ${index + 1}`,
        keywords: Array.isArray(item.keywords) ? item.keywords : []
    };
}

function stripExtension(filename) {
    return filename ? filename.replace(/\\.[^/.]+$/, '') : '';
}

// Load gallery with CSS column masonry layout
function loadGallery() {
    gallery.innerHTML = '';

    if (visibleImages.length === 0) {
        gallery.innerHTML = '<p style="text-align: center; color: #666;">No images match the selected tags.</p>';
        return;
    }

    visibleImages.forEach((image, index) => {
        const imgContainer = document.createElement('div');
        imgContainer.className = 'gallery-item';

        const img = document.createElement('img');
        img.src = IMAGE_FOLDER + image.file;
        img.alt = image.name || `Photo ${index + 1}`;
        img.loading = 'lazy';

        img.onerror = function() {
            imgContainer.style.display = 'none';
        };

        imgContainer.addEventListener('click', () => openLightbox(index));

        imgContainer.appendChild(img);
        gallery.appendChild(imgContainer);
    });
}

// Lightbox functions
function openLightbox(index) {
    currentImageIndex = index;
    updateLightbox();
    lightbox.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeLightbox() {
    lightbox.classList.remove('active');
    document.body.style.overflow = '';
}

function updateLightbox() {
    const currentImage = visibleImages[currentImageIndex];
    lightboxImg.src = IMAGE_FOLDER + currentImage.file;
    lightboxImg.alt = currentImage.name || `Photo ${currentImageIndex + 1}`;
    lightboxCounter.textContent = `${currentImageIndex + 1} / ${visibleImages.length}`;
}

function nextImage() {
    currentImageIndex = (currentImageIndex + 1) % visibleImages.length;
    updateLightbox();
}

function prevImage() {
    currentImageIndex = (currentImageIndex - 1 + visibleImages.length) % visibleImages.length;
    updateLightbox();
}

// Tag filter helpers
function buildTagFilters(allImages) {
    if (!tagFiltersContainer) return;

    const keywords = getUniqueKeywords(allImages);

    if (keywords.length === 0) {
        tagFiltersContainer.style.display = 'none';
        return;
    }

    tagFiltersContainer.style.display = 'flex';
    tagFiltersContainer.innerHTML = '';

    const allBtn = createTagButton('All', true, () => {
        selectedTags.clear();
        updateActiveTags();
        applyFilters();
    });
    tagFiltersContainer.appendChild(allBtn);

    keywords.forEach(kw => {
        const btn = createTagButton(kw, false, () => {
            toggleTag(kw);
            applyFilters();
        });
        tagFiltersContainer.appendChild(btn);
    });
}

function getUniqueKeywords(list) {
    const keywordMap = new Map();
    list.forEach(img => {
        (img.keywords || []).forEach(raw => {
            if (typeof raw !== 'string') return;
            const kw = raw.trim();
            if (!kw) return;
            const key = kw.toLowerCase();
            if (!keywordMap.has(key)) keywordMap.set(key, kw);
        });
    });
    return Array.from(keywordMap.values());
}

function createTagButton(label, isActive, onClick) {
    const btn = document.createElement('button');
    btn.className = 'tag-filter';
    if (isActive) btn.classList.add('active');
    btn.textContent = label;
    btn.addEventListener('click', onClick);
    return btn;
}

function toggleTag(tag) {
    if (selectedTags.has(tag)) {
        selectedTags.delete(tag);
    } else {
        selectedTags.add(tag);
    }
    updateActiveTags();
}

function updateActiveTags() {
    const buttons = tagFiltersContainer.querySelectorAll('.tag-filter');
    buttons.forEach(btn => {
        const label = btn.textContent;
        if (label === 'All') {
            btn.classList.toggle('active', selectedTags.size === 0);
        } else {
            btn.classList.toggle('active', selectedTags.has(label));
        }
    });
}

function applyFilters() {
    visibleImages = getFilteredImages(images, selectedTags);
    currentImageIndex = 0;
    loadGallery();
}

function getFilteredImages(list, tags) {
    if (!tags || tags.size === 0) return list.slice();
    const required = Array.from(tags).map(t => t.toLowerCase());
    return list.filter(img => {
        const kws = (img.keywords || []).map(k => (typeof k === 'string' ? k.toLowerCase() : ''));
        return required.some(tag => kws.includes(tag));
    });
}

// Event Listeners
closeBtn.addEventListener('click', closeLightbox);
nextBtn.addEventListener('click', nextImage);
prevBtn.addEventListener('click', prevImage);

// Close lightbox when clicking outside image
lightbox.addEventListener('click', (e) => {
    if (e.target === lightbox) {
        closeLightbox();
    }
});

// Keyboard navigation
document.addEventListener('keydown', (e) => {
    if (!lightbox.classList.contains('active')) return;

    switch(e.key) {
        case 'Escape':
            closeLightbox();
            break;
        case 'ArrowRight':
            nextImage();
            break;
        case 'ArrowLeft':
            prevImage();
            break;
    }
});

// Initialize on page load
initGallery();
