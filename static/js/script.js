function getOtherTabs(tab) {
    const otherTabs = [];

    for (let prevTab = tab.previousSibling;
            prevTab !== null;
            prevTab = prevTab.previousSibling) {
        otherTabs.push(prevTab);
    }

    for (let nextTab = tab.nextSibling;
            nextTab !== null;
            nextTab = nextTab.nextSibling) {
        otherTabs.push(nextTab);
    }

    return otherTabs;
}

function getTabpanel(tab) {
    const id = tab.getAttribute('aria-controls');
    return document.getElementById(id);
}

function activateTab(tab) {
    tab.setAttribute('aria-selected', true);
    tab.setAttribute('aria-expanded', true);
    tab.setAttribute('tabindex', 0);

    const tabpanel = getTabpanel(tab);
    tabpanel.classList.remove('tabpanel-inactive');

    tab.focus();
}

function deactivateTab(tab) {
    tab.setAttribute('aria-selected', false);
    tab.setAttribute('aria-expanded', false);
    tab.setAttribute('tabindex', -1);

    const tabpanel = getTabpanel(tab);
    tabpanel.classList.add('tabpanel-inactive');
}

function selectTab(tab) {
    const otherTabs = getOtherTabs(tab);
    otherTabs.forEach(deactivateTab);
    activateTab(tab);
}

function getPreviousTab(tab) {
    if (tab.previousSibling === null) {
        return tab.parentNode.lastChild;
    } else {
        return tab.previousSibling;
    }
}

function getNextTab(tab) {
    if (tab.nextSibling === null) {
        return tab.parentNode.firstChild;
    } else {
        return tab.nextSibling;
    }
}

function initializeTab(tab) {
    // If this is the first tab in its tab-list.
    if (tab.previousSibling === null) {
        activateTab(tab);
    } else {
        deactivateTab(tab);
    }

    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('focus', () => selectTab(tab));
    tab.addEventListener('keydown', e => {
        if (e.defaultPrevented) {
            return;
        }

        switch (e.key) {
            case 'ArrowLeft':
                selectTab(getPreviousTab(tab));
                break;
            case 'ArrowRight':
                selectTab(getNextTab(tab));
                break;
        }
    });
}

function initializeTabs() {
    const tablists = document.querySelectorAll('.tablist-hidden');
    tablists.forEach(e => e.classList.remove('tablist-hidden'));

    const tabs = document.querySelectorAll('[role="tab"]');
    tabs.forEach(initializeTab);
}

function initializeTabpanelContainer(container) {
    const tabpanels = container.querySelectorAll('[role="tabpanel"]');
    const maxHeightPx = Array.from(tabpanels)
        .map(tp => tp.getBoundingClientRect().height)
        .reduce((h1, h2) => Math.max(h1, h2));
    const maxPaddedHeightPx = maxHeightPx +
        parseFloat(getComputedStyle(container).paddingTop) +
        parseFloat(getComputedStyle(container).paddingBottom) +
        parseFloat(getComputedStyle(container).borderTopWidth) +
        parseFloat(getComputedStyle(container).borderBottomWidth);

    // Convert height to ems on the container.
    const fontSizePx = parseFloat(getComputedStyle(container).fontSize);
    const maxHeightEm = maxPaddedHeightPx / fontSizePx;

    container.style.height = `${maxHeightEm}em`;
    container.style.minHeight = `${maxHeightEm}em`;

    container.classList.add('tabpanel-overlaps');
}

function initializeTabpanelContainers() {
    const containers = document.querySelectorAll('.tabpanel-container');
    containers.forEach(initializeTabpanelContainer);
}

document.addEventListener('DOMContentLoaded', () => {
    initializeTabpanelContainers();
    initializeTabs();
});
