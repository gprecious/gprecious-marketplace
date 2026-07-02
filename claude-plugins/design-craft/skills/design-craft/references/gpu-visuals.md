# GPU / WebGL / 3D / shader visuals

Open when the **signature element** (Gate 1) calls for GPU-driven visuals: a live shader background, a cinematic scroll-driven 3D scene, a generative hero, atmospheric depth. This is where a design stops looking templated — and also where a new kind of slop lives. Use it as a deliberate signature, never as decoration.

## When to reach for it (and when not)

- **Yes**: brand / marketing / portfolio / launch pages where a *memorable moment* is the job; a hero that must feel "expensive"; a product whose subject is inherently spatial/atmospheric.
- **No**: functional app UI, dashboards, forms, admin. GPU visuals there are pure cost and distraction — they violate the surface router (Gate 0). At most, a restrained ambient accent.
- **Earn it**: a 3D scene must carry meaning (the subject, a story, a state), not exist because it's impressive. Gratuitous 3D is slop.

## The one art-direction insight

**Restraint forces the 3D to carry the emotion.** Constrain the palette to **2–3 hex** (`{background, blob1, blob2}` mood system, interpolated per section with `THREE.Color.lerp()`). With color removed as a variable, **form, fog, light, and motion** must carry the feeling — so the 3D automatically becomes the protagonist and the screen reads as "expensive." This is the GPU-scale version of design-craft's *spend boldness in one place*.

## The stack & the three layers

Six flashy techniques reduce to three layers:

1. **Shading / rendering** — atmosphere is ~90% of the look.
   - Cheapest big win: `scene.fog = new THREE.FogExp2(color, density)` with `scene.background` set to the *same* hex. FogExp2 = exponential-squared falloff (near clear, far dissolves) — right curve for outdoor/atmospheric scenes.
   - Living fog: drive `fog.density` from scroll, or replace the `#include <fog_fragment>` chunk via `material.onBeforeCompile` for noise/height/background-texture fog. Merge `UniformsLib['fog']` + set `fog:true` on custom `ShaderMaterial` or that mesh won't receive fog.
   - Atmospheric rim: a mesh scaled ~1.13 with `THREE.BackSide` + `depthWrite:false` + Fresnel `pow(dot(viewDir,normal)+1.1, 2.0)` glows ridgelines. drei `<Sky>` / `<Clouds>` for instant mood (single draw call).
   - **Depth of field = use the library, never hand-port.** `@react-three/postprocessing` `<DepthOfField focusDistance focalLength bokehScale>` (+ `<Autofocus>` to track). Old BokehShader ports are learning-only.
   - Low FOV (≈15°) compresses the scene like a telephoto lens → cinematic "the mountain overwhelms you" feel.

2. **Scroll-camera orchestration** — put the frame on a timeline.
   - **Scroll is the single source of truth**: one `scrollProgress (0→1)` distributed to camera z, fog density, shader uniforms, and color interpolation at once.
   - **Lenis + GSAP integration (the canonical 3 lines):**
     ```js
     const lenis = new Lenis({ autoRaf: false })
     lenis.on('scroll', ScrollTrigger.update)
     gsap.ticker.add((t) => lenis.raf(t * 1000))   // seconds→ms; omit and scroll won't move
     gsap.ticker.lagSmoothing(0)                    // omit and tab-return causes a jump
     ```
   - Map in `ScrollTrigger.onUpdate(self => ...)` writing to refs; **apply in `useFrame`, mutating only `.value`** and scaling by `delta` for framerate independence. Don't recreate uniform objects.
   - Don't mix drei `<ScrollControls>` with Lenis — they fight over the scroll DOM. Consider `14islands/r3f-scroll-rig` for production scroll-sync.

3. **Art direction / restraint** — the 2–3 hex mood system above, plus film grain (`random(vUv*…) - 0.5`) for analog texture, oversized data-driven typography parallaxing at a different depth, and theme swaps via `ScrollTrigger` `onEnter`/`onLeaveBack` toggling CSS variables.

## Non-negotiable guardrails (these matter as much as the wow)

Mobile is a different machine. Skipping these turns a beautiful scene into a 20fps thermal-throttling crash.

- **Perf budget**: stable ≈ 27 meshes / 40k triangles / 2.1MB; draw calls "a few hundred, hard cap ~1000". Cache geometry with `useMemo` (object literals in `args` recreate geometry every render — a classic 800-draw-call bug). Never run `EffectComposer` and `renderer.render()` both.
- **Mobile**: **postprocessing OFF** (DoF/SSAO ~2× frametime); DPR `Math.min(devicePixelRatio, 2)` (1.5 on mobile); `frameloop="demand"` to skip idle renders; prefer vertex-shader/height fog.
- **`prefers-reduced-motion`**: static-image fallback for the 3D intro + a small notice. Non-negotiable, not optional.
- **SEO / accessibility**: canvas has no DOM text → **HTML-first**: real `<h1>`/CTA/semantic content in the DOM *before* the 3D, `<noscript>` fallback, a parallel semantic DOM alongside the visible 3D layer. Defer 3D after first paint; `OffscreenCanvas` + Web Worker for shader compile off the main thread.

## "WebGL slop" guard

GPU visuals have their own clichés — treat these as banlist items:
- generic glowy/blurred blobs and neon gradients as a reflexive "cool" background,
- a rotating 3D object that means nothing (spinning torus/blob),
- scroll-jacking so heavy the page fights the user,
- effects that tank Core Web Vitals for no narrative payoff.
If the 3D doesn't carry the subject/story/state, cut it. Over-production is slop.

## Build order (0 → deploy)

1. Scaffold: Next.js App Router, `transpilePackages:['three']`, `'use client'` `<Canvas>`, single `scrollProgress` store.
2. Static scene: geometry + FogExp2 + matching background + low FOV. Confirm one frame looks "expensive" before any scroll.
3. Shaders: `drei` `shaderMaterial()` (uTime/uScroll), `<Sky>`/`<Clouds>`, optional onBeforeCompile fog.
4. Scroll wiring: Lenis+GSAP 3-liner → distribute `self.progress` → apply in `useFrame`.
5. Camera: separate `cameraAnim`/`targetAnim` refs, per-segment `CustomEase`, optional `CatmullRomCurve3`, `pin`/`snap`.
6. Post: `<EffectComposer>` DoF + Bloom + Vignette + Noise — **desktop only**.
7. Art direction: 2–3 hex mood + `Color.lerp()` transitions + oversized type + grain.
8. Non-functional: DPR cap, `frameloop="demand"`, reduced-motion fallback, HTML-first + noscript, OffscreenCanvas.

## Sources / go-deeper
Codrops "Cinematic 3D Scroll with GSAP" & "Scroll-Reactive 3D Gallery (velocity + mood backgrounds)" · `houmahani/codrops-depth-gallery` (mood system, CatmullRom, velocity, film grain) · `14islands/r3f-scroll-rig` · pmndrs `react-three-fiber` / `drei` / `postprocessing` · Lenis (`darkroomengineering/lenis`) · GSAP ScrollTrigger · utsubo "100 Three.js Tips (2026)" & "WebGL/Three.js Site SEO" · Three.js Forum perf/accessibility threads. Full playbook: research trail `herdr-bench/design-skill/research/notion-webgl.md`.
