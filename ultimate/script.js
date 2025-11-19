// Configuration
const IMAGE_FOLDER = 'images/';
const SUPPORTED_FORMATS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

// State
let events = [];
let currentEvent = null;
let currentImageIndex = 0;
let currentGalleryImages = [];

// DOM Elements
const eventsGrid = document.getElementById('events-grid');
const galleryContainer = document.getElementById('gallery-container');
const gallery = document.getElementById('gallery');
const eventTitle = document.getElementById('event-title');
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
            events = data.events || [];
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

// Load event preview grid
function loadEventsGrid() {
    eventsGrid.innerHTML = '';

    events.forEach((event, index) => {
        const eventCard = document.createElement('div');
        eventCard.className = 'event-card';

        // Get first image as preview thumbnail
        const firstImage = event.images && event.images.length > 0 
            ? event.images[0] 
            : 'placeholder.jpg';
        const imagePath = IMAGE_FOLDER + event.folder + '/' + firstImage;

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

    if (currentGalleryImages.length === 0) {
        gallery.innerHTML = '<p style="text-align: center; color: #666;">No images in this event.</p>';
    } else {
        loadGallery();
    }

    eventTitle.textContent = currentEvent.name;
    eventsGrid.style.display = 'none';
    galleryContainer.style.display = 'block';
}

// Back to events grid
function backToEvents() {
    currentEvent = null;
    eventsGrid.style.display = 'grid';
    galleryContainer.style.display = 'none';
    closeLightbox();
}

// Load gallery for current event
function loadGallery() {
    gallery.innerHTML = '';

    currentGalleryImages.forEach((imageName, index) => {
        const imgContainer = document.createElement('div');
        imgContainer.className = 'gallery-item';

        const img = document.createElement('img');
        img.src = IMAGE_FOLDER + currentEvent.folder + '/' + imageName;
        img.alt = `Photo ${index + 1}`;
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
    lightboxImg.src = IMAGE_FOLDER + currentEvent.folder + '/' + currentGalleryImages[currentImageIndex];
    lightboxCounter.textContent = `${currentImageIndex + 1} / ${currentGalleryImages.length}`;
}

function nextImage() {
    currentImageIndex = (currentImageIndex + 1) % currentGalleryImages.length;
    updateLightbox();
}

function prevImage() {
    currentImageIndex = (currentImageIndex - 1 + currentGalleryImages.length) % currentGalleryImages.length;
    updateLightbox();
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
