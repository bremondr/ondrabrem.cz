// Configuration
const IMAGE_FOLDER = 'images/';
const SUPPORTED_FORMATS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

// State
let images = [];
let currentImageIndex = 0;

// DOM Elements
const gallery = document.getElementById('gallery');
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
            images = data.images || [];
        } else {
            // Fallback: Use predefined image list
            images = await getImageList();
        }

        if (images.length === 0) {
            gallery.innerHTML = '<p style="text-align: center; color: #666;">No images found. Please add images to the "images" folder and create an images.json file.</p>';
            return;
        }

        loadGallery();
    } catch (error) {
        console.error('Error loading images:', error);
        // Try fallback
        images = await getImageList();
        if (images.length > 0) {
            loadGallery();
        } else {
            gallery.innerHTML = '<p style="text-align: center; color: #666;">Error loading images. Please create an images.json file in the images folder.</p>';
        }
    }
}

// Fallback image list (update with your actual image filenames)
async function getImageList() {
    // This is a fallback list - you should create images.json with your actual images
    return [
        'image1.jpg',
        'image2.jpg',
        'image3.jpg',
        'image4.jpg',
        'image5.jpg'
    ];
}

// Load gallery with CSS column masonry layout
function loadGallery() {
    gallery.innerHTML = '';

    images.forEach((imageName, index) => {
        const imgContainer = document.createElement('div');
        imgContainer.className = 'gallery-item';

        const img = document.createElement('img');
        img.src = IMAGE_FOLDER + imageName;
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
    lightboxImg.src = IMAGE_FOLDER + images[currentImageIndex];
    lightboxCounter.textContent = `${currentImageIndex + 1} / ${images.length}`;
}

function nextImage() {
    currentImageIndex = (currentImageIndex + 1) % images.length;
    updateLightbox();
}

function prevImage() {
    currentImageIndex = (currentImageIndex - 1 + images.length) % images.length;
    updateLightbox();
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