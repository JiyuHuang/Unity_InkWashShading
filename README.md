# Ink-Wash shading

![](imgs/ink_wash.gif)

This project involves ink-wash style shading in Unity. The demo also includes a flowing water shader in accordance to the ink-wash style.

## Implementation

The implementation of ink-wash style shading includes object outlining and brush stroke painting effects.

The outlining of objects is implemented using an additional shading pass before the standard forward pass, rendering objects in black with a slightly larger scale behind the actual object. Thus, after the forward pass, an outlining effect is accomplished. To mimic the texture of a brush stroke, a noise-based additional pass is used to determine the thickness of the outline at any local point.

The brush stroke painting effect is implemented by combining the outcomes of a brush stroke texture map and a standard grayscale shading.

The flowing water animated effect is implemented in shader using Perlin noise to offset water's surface normals.
