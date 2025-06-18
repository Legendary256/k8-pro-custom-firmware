// Warning alert
alert("PLEASE WHATCH OUT, THIS IS A PHISHING SITE. DON'T ENTER UNLESS YOU KNOW WHAT YOU ARE DOING");

const oldJsonParse = JSON.parse;
JSON.parse = (...args) => {
    const res = oldJsonParse(...args);
    if (res && res.data && res.data.firmware && res.data.firmware.lasted && res.data.firmware.lasted.path)
        res.data.firmware.lasted.path = "http://localhost/firmware/keychron_k8_pro_ansi_rgb_autostart.bin";
    console.log(res);
    return res;
}

const BASE_URL = "https://launcher.keychron.com";

async function fetchMissingFile(url) {
    try {
        console.log(`Attempting to fetch missing file: ${url}`);
        const response = await fetch(`${BASE_URL}${url}`);
        if (!response.ok) {
            throw new Error(`Failed to fetch: ${response.status}`);
        }
        const blob = await response.blob();
        const blobUrl = URL.createObjectURL(blob);
        console.log(`Successfully fetched and created blob URL for: ${url}`);
        return blobUrl;
    } catch (error) {
        console.error(`Failed to fetch missing file ${url}:`, error);
        return null;
    }
}

const originalFetch = window.fetch;
window.fetch = async (...args) => {
    try {
        const response = await originalFetch(...args);
        if (response.status === 404) {
            const url = new URL(args[0], window.location.origin);
            const path = url.pathname;
            console.log(`404 detected for: ${path}`);
            
            // Attempt to fetch from the original site
            const blobUrl = await fetchMissingFile(path);
            if (blobUrl) {
                // Return a new response with the fetched content
                const originalResponse = await originalFetch(blobUrl);
                return originalResponse;
            }
        }
        return response;
    } catch (error) {
        console.error('Fetch error:', error);
        throw error;
    }
};

const originalXHROpen = XMLHttpRequest.prototype.open;
const originalXHRSend = XMLHttpRequest.prototype.send;

XMLHttpRequest.prototype.open = function(method, url, ...args) {
    this._url = url;
    return originalXHROpen.call(this, method, url, ...args);
};

XMLHttpRequest.prototype.send = function(...args) {
    const originalOnReadyStateChange = this.onreadystatechange;
    const originalOnLoad = this.onload;
    const originalOnError = this.onerror;
    
    this.onreadystatechange = async function() {
        if (this.readyState === 4 && this.status === 404) {
            console.log(`XHR 404 detected for: ${this._url}`);
            try {
                const blobUrl = await fetchMissingFile(this._url);
                if (blobUrl) {
                    // Create a new XHR to fetch the blob
                    const newXHR = new XMLHttpRequest();
                    newXHR.open('GET', blobUrl);
                    newXHR.onload = () => {
                        // Override the current XHR properties
                        Object.defineProperty(this, 'status', { value: 200, writable: true });
                        Object.defineProperty(this, 'statusText', { value: 'OK', writable: true });
                        Object.defineProperty(this, 'response', { value: newXHR.response, writable: true });
                        Object.defineProperty(this, 'responseText', { value: newXHR.responseText, writable: true });
                        
                        if (originalOnLoad) originalOnLoad.call(this);
                    };
                    newXHR.send();
                    return;
                }
            } catch (error) {
                console.error('Error handling XHR 404:', error);
            }
        }
        if (originalOnReadyStateChange) originalOnReadyStateChange.call(this);
    };
    
    return originalXHRSend.call(this, ...args);
};

document.addEventListener('error', async (e) => {
    if (e.target.tagName === 'SCRIPT' || e.target.tagName === 'IMG' || e.target.tagName === 'LINK') {
        const src = e.target.src || e.target.href;
        if (src && src.includes('localhost')) {
            const url = new URL(src);
            const path = url.pathname;
            console.log(`Resource loading error detected for: ${path}`);
            
            const blobUrl = await fetchMissingFile(path);
            if (blobUrl) {
                if (e.target.tagName === 'SCRIPT') {
                    // For scripts, create a new script element and inject it
                    const newScript = document.createElement('script');
                    newScript.src = blobUrl;
                    if (e.target.type) newScript.type = e.target.type;
                    if (e.target.defer) newScript.defer = e.target.defer;
                    document.head.appendChild(newScript);
                    console.log(`Injected new script element for: ${path}`);
                } else {
                    // For other resources, update the src/href
                    if (e.target.src) {
                        e.target.src = blobUrl;
                    } else if (e.target.href) {
                        e.target.href = blobUrl;
                    }
                    console.log(`Updated resource URL to blob: ${path}`);
                }
            }
        }
    }
}, true);

// Also handle scripts that might be loaded dynamically by the Angular app
const originalCreateElement = document.createElement.bind(document);
document.createElement = function(tagName, options) {
    const element = originalCreateElement(tagName, options);
    
    if (tagName.toLowerCase() === 'script') {
        const originalSetAttribute = element.setAttribute.bind(element);
        element.setAttribute = function(name, value) {
            if (name === 'src' && value && !value.startsWith('http') && !value.startsWith('blob:')) {
                console.log(`Intercepting script src: ${value}`);
                // Try to fetch the script if it's not available locally
                fetchMissingFile(value).then(blobUrl => {
                    if (blobUrl) {
                        originalSetAttribute('src', blobUrl);
                        console.log(`Updated dynamically created script src to blob: ${value}`);
                    } else {
                        originalSetAttribute(name, value);
                    }
                }).catch(() => {
                    originalSetAttribute(name, value);
                });
                return;
            }
            originalSetAttribute(name, value);
        };
    }
    
    return element;
};
