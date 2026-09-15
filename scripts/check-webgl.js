const {app, BrowserWindow} = require('electron');

const {configureWebgl} = require('../src/main/webgl');

const skipWebglFix = process.argv.includes('--skip-webgl-fix');
const configuredSwitches = skipWebglFix ? [] : configureWebgl(app);

const checkWebgl = async () => {
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
        await window.loadURL(documentUrl);
        const result = await window.webContents.executeJavaScript(`(() => {
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
        })()`, true);
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
        window.destroy();
    }
};

app.whenReady().then(checkWebgl).then(
    () => app.exit(0),
    error => {
        console.error(error.stack || error);
        app.exit(1);
    }
);
