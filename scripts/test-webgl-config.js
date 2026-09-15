const assert = require('assert');

const {configureWebgl, getWebglSwitches} = require('../src/main/webgl');

const switchNames = switches => switches.map(({name, value}) => (
    value === undefined ? name : `${name}=${value}`
));

assert.deepStrictEqual(
    switchNames(getWebglSwitches({platform: 'linux', arch: 'arm64'})),
    [
        'ignore-gpu-blocklist',
        'enable-webgl',
        'use-gl=angle',
        'use-angle=swiftshader',
        'enable-unsafe-swiftshader'
    ]
);
assert.deepStrictEqual(getWebglSwitches({platform: 'linux', arch: 'x64'}), []);
assert.deepStrictEqual(getWebglSwitches({platform: 'darwin', arch: 'arm64'}), []);

const appendedSwitches = [];
configureWebgl({
    commandLine: {
        appendSwitch: (name, value) => appendedSwitches.push(
            value === undefined ? name : `${name}=${value}`
        )
    }
}, {platform: 'linux', arch: 'arm64'});
assert.deepStrictEqual(appendedSwitches, switchNames(getWebglSwitches({platform: 'linux', arch: 'arm64'})));

console.log('WebGL startup switch configuration passed.');
