#version 440
// Separable 13-tap gaussian. Run twice: dir = (step/width, 0) then (0, step/height).
// Used both to spread the metaball coverage field and to frost the background.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 dir; // tap offset in UV space, already divided by texture size
};

layout(binding = 1) uniform sampler2D source;

void main() {
    const float w[7] = float[7](0.15527, 0.14420, 0.11551, 0.07981,
                                0.04754, 0.02444, 0.01085);
    vec4 acc = texture(source, qt_TexCoord0) * w[0];
    for (int i = 1; i < 7; i++) {
        acc += texture(source, qt_TexCoord0 + dir * float(i)) * w[i];
        acc += texture(source, qt_TexCoord0 - dir * float(i)) * w[i];
    }
    fragColor = acc * qt_Opacity;
}
