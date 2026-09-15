const {app, BrowserWindow} = require('electron');

const {configureWebgl} = require('../src/main/webgl');

const DEBUG_PREFIX = '[DEBUG-webgl-probe]';
const PROBE_TIMEOUT_MS = 30000;
const skipWebglFix = process.argv.includes('--skip-webgl-fix');
const configuredSwitches = skipWebglFix ? [] : configureWebgl(app);

const debug = message => console.error(`${DEBUG_PREFIX} ${message}`);

const withTimeout = (promise, label) => {
    let timer;
    const timeout = new Promise((resolve, reject) => {
        timer = setTimeout(
            () => reject(new Error(`${label} timed out after ${PROBE_TIMEOUT_MS}ms`)),
            PROBE_TIMEOUT_MS
        );
    });
    return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
};

const checkWebgl = async () => {
    debug('creating BrowserWindow');
    const window = new BrowserWindow({
        show: false,
        webPreferences: {
            sandbox: false
        }
    });

    try {
        const documentUrl = `data:text/html;charset=utf-8,${encodeURIComponent(
            '<!doctype html><html><body></body></html>'
        )}`;
        debug('loading data URL');
        await withTimeout(window.loadURL(documentUrl), 'loadURL');
        debug('data URL loaded');
        debug('executing WebGL context probe');
        const result = await withTimeout(window.webContents.executeJavaScript(`(() => {
            const canvas = document.createElement('canvas');
            const attributes = {alpha: false, stencil: true, antialias: false};
            const webgl = canvas.getContext('webgl', attributes) ||
                canvas.getContext('experimental-webgl', attributes);
            const webgl2 = canvas.getContext('webgl2', attributes);
            const context = webgl || webgl2;
            return {
                webgl: Boolean(webgl),
                webgl2: Boolean(webgl2),
                renderer: context ? context.getParameter(context.RENDERER) : null,
                vendor: context ? context.getParameter(context.VENDOR) : null
            };
        })()`, true), 'executeJavaScript');
        debug('WebGL context probe returned');
        const gpuFeatureStatus = typeof app.getGPUFeatureStatus === 'function' ?
            app.getGPUFeatureStatus() : {};

        console.log(JSON.stringify({
            arch: process.arch,
            configuredSwitches,
            gpuFeatureStatus,
            platform: process.platform,
            result,
            skipWebglFix
        }, null, 2));

        if (!result.webgl && !result.webgl2) {
            throw new Error('WebGL context could not be created.');
        }
    } finally {
        debug('destroying BrowserWindow');
        window.destroy();
    }
};

debug(`starting; skipWebglFix=${skipWebglFix}; configuredSwitches=${JSON.stringify(configuredSwitches)}`);
withTimeout(app.whenReady(), 'app.whenReady').then(() => {
    debug('app ready');
    return checkWebgl();
}).then(
    () => app.exit(0),
    error => {
        console.error(error.stack || error);
        app.exit(1);
        setTimeout(() => process.exit(1), 1000).unref();
    }
);
