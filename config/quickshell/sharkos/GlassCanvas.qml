import QtQuick

// Liquid-glass renderer.
//
// Takes two same-sized, invisible source layers:
//   coverage   — solid-white silhouettes of every mergeable element
//   background — the pixels "behind" the glass (wallpaper crop, screenshot, ...)
// and renders the glass on itself: the coverage field is blurred and
// thresholded (metaball merge — necks grow where silhouettes come close),
// then the same field's gradient drives refraction, specular, and rim light.
//
// Text/icons must NOT be in the coverage layer — draw them sharp, on top.
Item {
    id: root

    required property Item coverage
    required property Item background

    // Merge field
    property real fieldScale: 0.25  // field resolution as a fraction of full size
    property real blurStep: 1.6     // gaussian tap spacing in field texels; larger = longer merge reach
    property real threshold: 0.5
    property real softness: 0.055
    // Material
    property string tint: "#66101820"
    property real normalStrength: 5.0
    property real refractStrength: 0.045
    property real specPower: 26.0
    property real rimPower: 2.4
    property real frostMix: 0.85
    property vector2d lightDir: Qt.vector2d(-0.35, -0.65)

    readonly property size fieldSize: Qt.size(
        Math.max(1, Math.round(width * fieldScale)),
        Math.max(1, Math.round(height * fieldScale)))

    // ---- coverage -> blurred merge field (downsampled) ----
    ShaderEffectSource {
        id: covSrc
        sourceItem: root.coverage
        textureSize: root.fieldSize
        smooth: true
        visible: false
    }
    ShaderEffect {
        id: fieldBlurH
        width: root.fieldSize.width
        height: root.fieldSize.height
        visible: false
        property var source: covSrc
        property vector2d dir: Qt.vector2d(root.blurStep / Math.max(1, width), 0)
        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }
    ShaderEffectSource {
        id: fieldBlurHSrc
        sourceItem: fieldBlurH
        smooth: true
        visible: false
    }
    ShaderEffect {
        id: fieldBlurV
        width: root.fieldSize.width
        height: root.fieldSize.height
        visible: false
        property var source: fieldBlurHSrc
        property vector2d dir: Qt.vector2d(0, root.blurStep / Math.max(1, height))
        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }
    ShaderEffectSource {
        id: fieldSrc
        sourceItem: fieldBlurV
        smooth: true
        visible: false
    }

    // ---- background -> sharp + frosted textures ----
    ShaderEffectSource {
        id: bgSharp
        sourceItem: root.background
        smooth: true
        visible: false
    }
    ShaderEffect {
        id: bgBlurH
        width: root.fieldSize.width
        height: root.fieldSize.height
        visible: false
        property var source: bgSharp
        property vector2d dir: Qt.vector2d(1.4 / Math.max(1, width), 0)
        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }
    ShaderEffectSource {
        id: bgBlurHSrc
        sourceItem: bgBlurH
        smooth: true
        visible: false
    }
    ShaderEffect {
        id: bgBlurV
        width: root.fieldSize.width
        height: root.fieldSize.height
        visible: false
        property var source: bgBlurHSrc
        property vector2d dir: Qt.vector2d(0, 1.4 / Math.max(1, height))
        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }
    ShaderEffectSource {
        id: bgFrostSrc
        sourceItem: bgBlurV
        smooth: true
        visible: false
    }

    // ---- final glass pass ----
    ShaderEffect {
        anchors.fill: parent
        property var field: fieldSrc
        property var bg: bgSharp
        property var frost: bgFrostSrc
        property vector2d texel: Qt.vector2d(1 / root.fieldSize.width, 1 / root.fieldSize.height)
        property vector2d lightDir2: root.lightDir
        property color tintColor: root.tint
        property real threshold: root.threshold
        property real softness: root.softness
        property real normalStrength: root.normalStrength
        property real refractStrength: root.refractStrength
        property real specPower: root.specPower
        property real rimPower: root.rimPower
        property real frostMix: root.frostMix
        fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
    }
}
