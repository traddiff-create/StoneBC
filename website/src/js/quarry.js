/* The Quarry — Bike Listing Logic */

(function () {
  'use strict';

  var grid = document.getElementById('bike-grid');
  var filterBtns = document.querySelectorAll('.filter-btn');
  var allBikes = [];
  var activeFilter = 'all';

  function loadBikes() {
    fetch('../inventory/bikes.json')
      .then(function (res) { return res.json(); })
      .then(function (data) {
        allBikes = data.bikes || [];
        renderBikes();
      })
      .catch(function () {
        clearGrid();
        var empty = createEmptyState('Could not load bikes', 'Please try again later or contact us.');
        grid.appendChild(empty);
      });
  }

  function clearGrid() {
    while (grid.firstChild) {
      grid.removeChild(grid.firstChild);
    }
  }

  function renderBikes() {
    var filtered = allBikes.filter(function (bike) {
      if (activeFilter === 'all') return true;
      return bike.type === activeFilter;
    });

    filtered.sort(function (a, b) {
      if (a.status === 'available' && b.status !== 'available') return -1;
      if (a.status !== 'available' && b.status === 'available') return 1;
      return 0;
    });

    clearGrid();

    if (filtered.length === 0) {
      var empty = createEmptyState('No bikes in this category', 'Check back soon or contact us about what you\'re looking for.');
      grid.appendChild(empty);
      return;
    }

    filtered.forEach(function (bike) {
      grid.appendChild(buildCard(bike));
    });
  }

  function createEmptyState(title, message) {
    var div = document.createElement('div');
    div.className = 'empty-state';
    var h3 = document.createElement('h3');
    h3.textContent = title;
    var p = document.createElement('p');
    p.textContent = message;
    div.appendChild(h3);
    div.appendChild(p);
    return div;
  }

  function el(tag, className, textContent) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (textContent) node.textContent = textContent;
    return node;
  }

  function capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  function buildCard(bike) {
    var isAvailable = bike.status === 'available';
    var card = el('div', isAvailable ? 'bike-card' : 'bike-card refurbishing');
    card.setAttribute('data-type', bike.type || '');

    // Image area
    var imageDiv = el('div', 'bike-card-image');
    if (bike.photos && bike.photos.length > 0) {
      imageDiv.style.backgroundImage = 'url(\'../inventory/photos/' + bike.photos[0] + '\')';
    }
    var statusBadge = el('span', 'status-badge ' + (isAvailable ? 'status-available' : 'status-refurbishing'));
    statusBadge.textContent = isAvailable ? 'Available' : 'In the Shop';
    imageDiv.appendChild(statusBadge);
    var typeBadge = el('span', 'type-badge', capitalize(bike.type));
    imageDiv.appendChild(typeBadge);
    card.appendChild(imageDiv);

    // Body
    var body = el('div', 'bike-card-body');

    var title = el('h3', null, bike.model);
    body.appendChild(title);

    // Specs row
    var specs = el('div', 'bike-specs');
    [bike.frameSize, bike.wheelSize, bike.color].forEach(function (val) {
      if (val) {
        var s = el('span', null, val);
        specs.appendChild(s);
      }
    });
    var condSpan = el('span');
    var dot = el('span', 'condition-dot condition-' + (bike.condition || 'good'));
    condSpan.appendChild(dot);
    condSpan.appendChild(document.createTextNode(' ' + capitalize(bike.condition)));
    specs.appendChild(condSpan);
    body.appendChild(specs);

    // Features
    if (bike.features && bike.features.length > 0) {
      var features = el('div', 'bike-features');
      bike.features.forEach(function (f) {
        features.appendChild(el('span', null, f));
      });
      body.appendChild(features);
    }

    // Description
    body.appendChild(el('p', 'bike-description', bike.description));

    // Footer
    var footer = el('div', 'bike-card-footer');
    footer.appendChild(el('span', 'bike-price', '$' + bike.sponsorPrice));

    if (isAvailable) {
      var btn = el('a', 'btn btn-primary btn-small', 'Sponsor / Buy');
      btn.href = 'contact.html?subject=Quarry%20-%20' + encodeURIComponent(bike.model) + '%20(' + bike.id + ')';
      btn.setAttribute('data-bike', bike.id);
      footer.appendChild(btn);
    } else {
      var soon = el('span', 'btn btn-small', 'Coming Soon');
      soon.style.cssText = 'background:#9ca3af;border-color:#9ca3af;color:#fff;cursor:default;';
      footer.appendChild(soon);
    }

    body.appendChild(footer);
    card.appendChild(body);
    return card;
  }

  // Filter handlers
  filterBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      filterBtns.forEach(function (b) { b.classList.remove('active'); });
      btn.classList.add('active');
      activeFilter = btn.getAttribute('data-filter');
      renderBikes();
    });
  });

  // Pool button — redirects to contact until Stripe is configured
  var poolBtn = document.getElementById('pool-btn');
  if (poolBtn) {
    poolBtn.addEventListener('click', function (e) {
      e.preventDefault();
      // TODO: Replace with Stripe payment link for general pool
      window.location.href = 'contact.html?subject=Quarry%20-%20General%20Pool%20Contribution';
    });
  }

  loadBikes();
})();
