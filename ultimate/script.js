// Configuration
const IMAGE_FOLDER = 'images/';
const SUPPORTED_FORMATS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

// State
let events = [];
let currentEvent = null;
let currentImageIndex = 0;
let currentGalleryImages = [];
let visibleImages = [];
let selectedTags = new Set();

// DOM Elements
const eventsGrid = document.getElementById('events-grid');
const galleryContainer = document.getElementById('gallery-container');
const gallery = document.getElementById('gallery');
const eventTitle = document.getElementById('event-title');
const tagFiltersContainer = document.getElementById('tag-filters');
const backBtn = document.getElementById('back-btn');
const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightbox-img');
const lightboxCounter = document.querySelector('.lightbox-counter');
const closeBtn = document.querySelector('.lightbox-close');
const prevBtn = document.querySelector('.lightbox-prev');
const nextBtn = document.querySelector('.lightbox-next');

// Initialize portfolio
async function initPortfolio() {
    try {
        // Load events from images.json
        const response = await fetch(IMAGE_FOLDER + 'images.json');
        if (response.ok) {
            const data = await response.json();
            events = normalizeEvents(data.events);
        } else {
            events = [];
        }

        if (events.length === 0) {
            eventsGrid.innerHTML = '<p style="text-align: center; color: #666; grid-column: 1/-1;">No events found. Please add events to images/images.json</p>';
            return;
        }

        loadEventsGrid();
    } catch (error) {
        console.error('Error loading events:', error);
        eventsGrid.innerHTML = '<p style="text-align: center; color: #666; grid-column: 1/-1;">Error loading events. Please check images/images.json</p>';
    }
}

// Normalize events and their images to have consistent fields
function normalizeEvents(list) {
    return (list || []).map(event => {
        const folder = event.folder || '';
        return {
            ...event,
            name: event.name || folder || 'Untitled event',
            folder,
            images: normalizeImages(event.images)
        };
    });
}

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

// Load event preview grid
function loadEventsGrid() {
    eventsGrid.innerHTML = '';

    events.forEach((event, index) => {
        const eventCard = document.createElement('div');
        eventCard.className = 'event-card';

        // Get first image as preview thumbnail
        const firstImage = event.images && event.images.length > 0 
            ? event.images[0] 
            : null;
        const imagePath = firstImage 
            ? IMAGE_FOLDER + event.folder + '/' + firstImage.file 
            : IMAGE_FOLDER + 'placeholder.jpg';

        const preview = document.createElement('img');
        preview.src = imagePath;
        preview.alt = event.name;
        preview.className = 'event-preview-img';
        preview.onerror = function() {
            this.style.display = 'none';
        };

        const overlay = document.createElement('div');
        overlay.className = 'event-overlay';

        const info = document.createElement('div');
        info.className = 'event-info';

        const name = document.createElement('h3');
        name.className = 'event-name';
        name.textContent = event.name;

        const count = document.createElement('p');
        count.className = 'event-count';
        count.textContent = `${event.images ? event.images.length : 0} photos`;

        info.appendChild(name);
        info.appendChild(count);
        overlay.appendChild(info);

        eventCard.appendChild(preview);
        eventCard.appendChild(overlay);

        eventCard.addEventListener('click', () => openEvent(index));
        eventsGrid.appendChild(eventCard);
    });
}

// Open specific event gallery
function openEvent(eventIndex) {
    currentEvent = events[eventIndex];
    currentImageIndex = 0;
    currentGalleryImages = currentEvent.images || [];
    selectedTags.clear();

    if (currentGalleryImages.length === 0) {
        gallery.innerHTML = '<p style="text-align: center; color: #666;">No images in this event.</p>';
        if (tagFiltersContainer) tagFiltersContainer.style.display = 'none';
    } else {
        buildTagFilters(currentGalleryImages);
        applyFilters();
    }

    eventTitle.textContent = currentEvent.name;
    eventsGrid.style.display = 'none';
    galleryContainer.style.display = 'block';
}

// Back to events grid
function backToEvents() {
    currentEvent = null;
    selectedTags.clear();
    eventsGrid.style.display = 'grid';
    galleryContainer.style.display = 'none';
    closeLightbox();
}

// Load gallery for current event
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
        img.src = IMAGE_FOLDER + currentEvent.folder + '/' + image.file;
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
    lightboxImg.src = IMAGE_FOLDER + currentEvent.folder + '/' + currentImage.file;
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
function buildTagFilters(images) {
    if (!tagFiltersContainer) return;

    const keywords = getUniqueKeywords(images);
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
    if (!tagFiltersContainer) return;
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
    visibleImages = getFilteredImages(currentGalleryImages, selectedTags);
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
backBtn.addEventListener('click', backToEvents);
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
initPortfolio();
