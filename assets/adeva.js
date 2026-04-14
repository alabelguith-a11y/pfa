import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// 1. DATA CONFIGURATION (angles match assets/gesture.json — thumb, index, middle, ring, pinky)
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

// UPDATED: Using Bone001 naming convention and forcing X axis
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

// 2. SCENE SETUP
const scene = new THREE.Scene();
const wrap = document.getElementById('canvas-wrap');
const camera = new THREE.PerspectiveCamera(45, wrap.clientWidth / wrap.clientHeight, 0.1, 1000);
camera.position.set(0, 0.5, 4);

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setSize(wrap.clientWidth, wrap.clientHeight);
wrap.appendChild(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;

// 1. Soft base light (Ambient)
// Lowering this from 0.8 to 0.3-0.4 prevents the "washed out" look
scene.add(new THREE.AmbientLight(0xffffff, 0.4));

// 2. Primary Accent Light (The Green one)
// This gives the hand that high-tech "ADEVA" green glow
const mainLight = new THREE.DirectionalLight(0x4ff8c8, 1.2);
mainLight.position.set(2, 5, 5); // Positioned higher up
scene.add(mainLight);

// 3. Fill Light (The "Customer Visibility" light)
// This hits the side that was previously dark, using a neutral white
const fillLight = new THREE.DirectionalLight(0xffffff, 0.6);
fillLight.position.set(-5, 0, -2); // Hits from the opposite side and slightly behind
scene.add(fillLight);

// 4. Rim Light (Optional but looks great)
// Placed behind the hand to give a crisp outline
const rimLight = new THREE.PointLight(0xffffff, 0.5);
rimLight.position.set(0, 5, -5);
scene.add(rimLight);
// 3. LOAD MODEL
const loader = new GLTFLoader();
loader.load('./hand.glb', (gltf) => {
    const model = gltf.scene;
    scene.add(model);
    model.scale.set(1.5, 1.5, 1.5);
    model.position.y = -1.2;

    model.traverse(obj => {
        if (obj.isBone) {
            boneMap[obj.name] = obj;
        }
    });

    document.getElementById('overlay').style.display = 'none';
    modelLoaded = true;
    animate();
});

// 4. ANIMATION LOOP
function animate() {
    requestAnimationFrame(animate);
    controls.update();

    if (modelLoaded) {
        // Update interpolation
        for (let i = 0; i < 5; i++) {
            currentAngles[i] = THREE.MathUtils.lerp(currentAngles[i], targetAngles[i], lerpSpeed);
            
            const chain = FINGER_CHAINS[i];
            const radPerJoint = THREE.MathUtils.degToRad(currentAngles[i] / chain.bones.length);

            chain.bones.forEach(boneName => {
                const bone = boneMap[boneName];
                if (bone) {
                    // Force rotation on X axis
                    bone.rotation.x = -radPerJoint *2;
                    bone.rotation.y = 0;
                    bone.rotation.z = 0;
                }
            });

            // Update UI
            const bar = document.getElementById(`bar-${i}`);
            if (bar) bar.style.width = `${(currentAngles[i] / 90) * 100}%`;
            const val = document.getElementById(`val-${i}`);
            if (val) val.innerText = `${Math.round(currentAngles[i])}°`;
        }
    }
    renderer.render(scene, camera);
}

// 5. UI INTERACTION (BUTTONS)
const alphaGrid = document.getElementById('alpha-grid');
Object.keys(GESTURES).forEach(key => {
    const btn = document.createElement('div');
    btn.className = 'gesture-item';
    btn.innerText = key;
    btn.onclick = () => {
        // This line updates the target array that animate() is watching
        targetAngles = [...GESTURES[key]];
        document.getElementById('cmd-box').innerText = `CMD: GESTURE_${key}`;
    };
    alphaGrid.appendChild(btn);
});

// Speed Slider
const speedSlider = document.getElementById('speed-slider');
speedSlider.oninput = (e) => {
    lerpSpeed = parseFloat(e.target.value);
    document.getElementById('speed-val').innerText = lerpSpeed;
};

// 6. FLUTTER BRIDGE (optional)
// Flutter can call this to drive the model in real time.
window.setGestureFromFlutter = (id, angles) => {
    if (Array.isArray(angles) && angles.length === 5) {
        targetAngles = angles.map((v) => Number(v) || 0);
    } else if (id && GESTURES[id]) {
        targetAngles = [...GESTURES[id]];
    }
    const cmdBox = document.getElementById('cmd-box');
    if (cmdBox) cmdBox.innerText = `CMD: ${id ?? '—'}`;
};