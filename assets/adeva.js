import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const GESTURES = {
    "A": [0, 90, 90, 90, 90],
    "B": [0, 0, 0, 0, 90],
    "C": [90, 45, 45, 45, 90],
    "D": [0, 0, 90, 90, 90],
    "E": [90, 90, 90, 90, 90],
    "F": [0, 0, 0, 90, 90],
    "G": [0, 0, 0, 0, 0],
    "H": [0, 0, 90, 90, 0],
    "I": [90, 90, 90, 90, 0],
    "J": [90, 90, 90, 90, 45],
    "K": [0, 0, 90, 0, 90],
    "L": [0, 90, 90, 90, 90],
    "M": [0, 45, 45, 90, 90],
    "N": [0, 45, 90, 90, 90],
    "O": [90, 45, 45, 45, 45],
    "P": [0, 0, 90, 90, 90],
    "Q": [0, 0, 0, 45, 90],
    "R": [0, 0, 90, 0, 90],
    "S": [90, 90, 90, 90, 90],
    "T": [90, 90, 90, 90, 0],
    "U": [0, 0, 90, 90, 90],
    "V": [0, 0, 45, 90, 90],
    "W": [0, 0, 0, 45, 90],
    "X": [90, 45, 45, 45, 90],
    "Y": [0, 90, 90, 90, 0],
    "Z": [0, 0, 0, 0, 90],
    "OK": [45, 90, 0, 0, 0]
};

const FINGER_CHAINS = [
    { name: 'thumb',  bones: ['Bone018', 'Bone019'], axis: 'x' },
    { name: 'index',  bones: ['Bone008', 'Bone012', 'Bone014'], axis: 'x' },
    { name: 'middle', bones: ['Bone009', 'Bone013', 'Bone015'], axis: 'x' },
    { name: 'ring',   bones: ['Bone007', 'Bone011', 'Bone016'], axis: 'x' },
    { name: 'pinky',  bones: [ 'Bone006', 'Bone010', 'Bone017'], axis: 'x' }
];

let targetAngles = [0, 0, 0, 0, 0];
let currentAngles = [0, 0, 0, 0, 0];
let boneMap = {};
window.boneMap = boneMap;
let modelLoaded = false;
let lerpSpeed = 0.12;

let scene;
let camera;
let renderer;
let controls;
let wrap;

function applyFlutterGesture(id, angles) {
    if (Array.isArray(angles) && angles.length === 5) {
        targetAngles = angles.map((v) => Number(v) || 0);
    } else if (id != null && GESTURES[id]) {
        targetAngles = [...GESTURES[id]];
    }
    const cmdBox = document.getElementById('cmd-box');
    if (cmdBox) {
        const label = id != null ? String(id) : '—';
        cmdBox.textContent = `CMD: ${label}`;
    }
}

window.setGestureFromFlutter = (id, angles) => {
    applyFlutterGesture(id, angles);
};

window.receiveDataFromFlutter = function(jsonString) {
    try {
        const data = JSON.parse(jsonString);
        applyFlutterGesture(data.id, data.angles);
        window.setCharacterFromFlutter(data.id);
    } catch (e) {
        console.error("Error parsing data from Flutter:", e);
    }
};

window.updateHandFromFlutter = function (angles) {
    if (Array.isArray(angles) && angles.length === 5) {
        targetAngles = [...angles];
    }
};

window.setCharacterFromFlutter = (ch) => {
    const c = ch != null ? String(ch).toUpperCase().slice(0, 1) : '';
    const cmdBox = document.getElementById('cmd-box');
    if (cmdBox) cmdBox.textContent = c ? `Lettre: ${c}` : '—';
};

function showOverlayMessage(html) {
    const overlay = document.getElementById('overlay');
    if (overlay) overlay.innerHTML = html;
}

function fitRendererToWrap() {
    if (!wrap || !camera || !renderer) return;
    const w = Math.max(1, wrap.clientWidth || window.innerWidth);
    const h = Math.max(1, wrap.clientHeight || window.innerHeight);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
}

function animate() {
    if (!renderer || !scene || !camera) return;
    requestAnimationFrame(animate);
    if (controls) controls.update();

    if (modelLoaded) {
        for (let i = 0; i < 5; i++) {
            currentAngles[i] = THREE.MathUtils.lerp(currentAngles[i], targetAngles[i], lerpSpeed);

            const chain = FINGER_CHAINS[i];
            const radPerJoint = THREE.MathUtils.degToRad(currentAngles[i] / chain.bones.length);

            chain.bones.forEach((boneName) => {
                const bone = boneMap[boneName];
                if (bone) {
                    bone.rotation.x = -radPerJoint * 2.5;
                    bone.rotation.y = 0;
                    bone.rotation.z = 0;
                }
            });

            const bar = document.getElementById(`bar-${i}`);
            if (bar) bar.style.width = `${(currentAngles[i] / 90) * 100}%`;
            const val = document.getElementById(`val-${i}`);
            if (val) val.innerText = `${Math.round(currentAngles[i])}°`;
        }
    }
    renderer.render(scene, camera);
}

function startHandViz() {
    wrap = document.getElementById('canvas-wrap');
    if (!wrap) {
        showOverlayMessage('<p style="color:#f88;font-family:sans-serif;padding:16px;">#canvas-wrap introuvable</p>');
        return;
    }

    const initialW = Math.max(1, wrap.clientWidth || window.innerWidth);
    const initialH = Math.max(1, wrap.clientHeight || window.innerHeight);

    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(45, initialW / initialH, 0.1, 1000);
    camera.position.set(0, 0.5, 4);

    try {
        renderer = new THREE.WebGLRenderer({
            antialias: true,
            alpha: true,
            powerPreference: 'default',
            failIfMajorPerformanceCaveat: false,
        });
    } catch (e) {
        showOverlayMessage(
            '<p style="color:#f88;font-family:sans-serif;padding:16px;">WebGL indisponible dans cette WebView.</p>'
        );
        return;
    }

    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(initialW, initialH);
    wrap.appendChild(renderer.domElement);

    controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;

    scene.add(new THREE.AmbientLight(0xffffff, 0.4));

    const mainLight = new THREE.DirectionalLight(0x4ff8c8, 1.2);
    mainLight.position.set(2, 5, 5);
    scene.add(mainLight);

    const fillLight = new THREE.DirectionalLight(0xffffff, 0.6);
    fillLight.position.set(-5, 0, -2);
    scene.add(fillLight);

    const rimLight = new THREE.PointLight(0xffffff, 0.5);
    rimLight.position.set(0, 5, -5);
    scene.add(rimLight);

    window.addEventListener('resize', fitRendererToWrap);

    const loader = new GLTFLoader();
    loader.load(
        './hand.glb',
        (gltf) => {
            const model = gltf.scene;
            scene.add(model);
            model.scale.set(1.5, 1.5, 1.5);
            model.position.y = -1.2;

            model.traverse((obj) => {
                if (obj.isBone) {
                    boneMap[obj.name] = obj;
                }
            });

            const overlay = document.getElementById('overlay');
            if (overlay) overlay.style.display = 'none';
            modelLoaded = true;
            fitRendererToWrap();
        },
        undefined,
        () => {
            showOverlayMessage(
                '<p style="color:#f88;font-family:sans-serif;padding:16px;">Modèle 3D indisponible (hand.glb)</p>'
            );
        }
    );

    animate();
}

const alphaGrid = document.getElementById('alpha-grid');
if (alphaGrid) {
    Object.keys(GESTURES).forEach((key) => {
        const btn = document.createElement('div');
        btn.className = 'gesture-item';
        btn.innerText = key;
        btn.onclick = () => {
            targetAngles = [...GESTURES[key]];
            const cmdBox = document.getElementById('cmd-box');
            if (cmdBox) cmdBox.innerText = `CMD: GESTURE_${key}`;
        };
        alphaGrid.appendChild(btn);
    });
}

const speedSlider = document.getElementById('speed-slider');
if (speedSlider) {
    speedSlider.oninput = (e) => {
        lerpSpeed = parseFloat(e.target.value);
        const speedVal = document.getElementById('speed-val');
        if (speedVal) speedVal.innerText = lerpSpeed;
    };
}

requestAnimationFrame(startHandViz);