#version 440
// Liquid-glass material pass.
//
// `field` is the blurred coverage field. Thresholding it yields the metaball
// mask (necks grow where blobs' falloffs overlap); its gradient yields the
// surface normal that drives refraction, specular, and rim reflection.
// `bg` / `frost` are the pixels behind the glass, sharp and pre-blurred.
// Output is premultiplied alpha, as Qt expects.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;           // 1 / field texture size
    vec2 lightDir2;       // xy of light direction (z fixed below)
    vec4 tintColor;       // glass tint, straight alpha
    float threshold;      // metaball cutoff, ~0.5
    float softness;       // mask edge width (also the anti-aliasing)
    float normalStrength; // gradient -> normal steepness
    float refractStrength;// background UV displacement at edges/necks
    float specPower;      // specular exponent
    float rimPower;       // fresnel-ish rim exponent
    float frostMix;       // 0 = clear glass, 1 = fully frosted
};

layout(binding = 1) uniform sampler2D field;
layout(binding = 2) uniform sampler2D bg;
layout(binding = 3) uniform sampler2D frost;

void main() {
    float f = texture(field, qt_TexCoord0).a;
    float mask = smoothstep(threshold - softness, threshold + softness, f);
    if (mask < 0.004) {
        fragColor = vec4(0.0);
        return;
    }

    // Surface normal from the field gradient: strong at edges and necks,
    // flat in blob interiors.
    float gx = texture(field, qt_TexCoord0 + vec2(texel.x, 0.0)).a
             - texture(field, qt_TexCoord0 - vec2(texel.x, 0.0)).a;
    float gy = texture(field, qt_TexCoord0 + vec2(0.0, texel.y)).a
             - texture(field, qt_TexCoord0 - vec2(0.0, texel.y)).a;
    vec3 n = normalize(vec3(vec2(-gx, -gy) * normalStrength, 1.0));

    // Refraction: bend the background lookup along the surface normal.
    vec2 buv = clamp(qt_TexCoord0 + n.xy * refractStrength, 0.0, 1.0);
    vec3 base = mix(texture(bg, buv).rgb, texture(frost, buv).rgb, frostMix);
    base = mix(base, tintColor.rgb, tintColor.a);

    // Specular glint + rim reflection.
    vec3 l = normalize(vec3(lightDir2, 0.72));
    float spec = pow(max(dot(n, l), 0.0), specPower);
    float rim = pow(clamp(1.0 - n.z, 0.0, 1.0), rimPower);

    vec3 col = base + spec * 0.45 + rim * 0.30;
    fragColor = vec4(col, 1.0) * mask * qt_Opacity;
}
