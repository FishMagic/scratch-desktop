const ARM64_LINUX_WEBGL_SWITCHES = Object.freeze([
    {name: 'ignore-gpu-blocklist'},
    {name: 'enable-webgl'},
    {name: 'use-gl', value: 'angle'},
    {name: 'use-angle', value: 'swiftshader'},
    {name: 'enable-unsafe-swiftshader'}
]);

const getWebglSwitches = ({platform = process.platform, arch = process.arch} = {}) => {
    if (platform !== 'linux' || arch !== 'arm64') {
        return [];
    }

    return ARM64_LINUX_WEBGL_SWITCHES;
};

const configureWebgl = (electronApp, runtime = process) => {
    const switches = getWebglSwitches(runtime);
    for (const {name, value} of switches) {
        if (value === undefined) {
            electronApp.commandLine.appendSwitch(name);
        } else {
            electronApp.commandLine.appendSwitch(name, value);
        }
    }
    return switches;
};

module.exports = {
    configureWebgl,
    getWebglSwitches
};
