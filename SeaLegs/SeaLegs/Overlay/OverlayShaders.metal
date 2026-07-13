#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct OverlayUniforms {
    float2 viewportSize;
    float vignetteOpacity;
    float vignetteInnerRadius;
    float vignetteOuterRadius;
    float vignetteSoftness;

    uint centerDotEnabled;
    float centerDotOpacity;
    float centerDotRadius;
    float2 centerDotPosition;

    uint crosshairEnabled;
    float crosshairOpacity;
    float crosshairLength;
    float crosshairThickness;
    float2 crosshairPosition;

    uint horizonEnabled;
    float horizonOpacity;
    float horizonY;

    uint dashboardEnabled;
    float dashboardOpacity;

    uint virtualNoseEnabled;
    float virtualNoseOpacity;

    uint peripheralFrameEnabled;
    float peripheralFrameOpacity;
    float peripheralFrameThickness;
};

vertex VertexOut overlayVertex(uint vid [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2( 1.0, -1.0), float2( 1.0,  1.0), float2(-1.0,  1.0)
    };
    float2 uvs[6] = {
        float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0),
        float2(1.0, 1.0), float2(1.0, 0.0), float2(0.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

fragment float4 overlayFragment(VertexOut in [[stage_in]], constant OverlayUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.viewportSize.x / max(u.viewportSize.y, 1.0);
    float2 centered = uv - float2(0.5, 0.5);
    centered.x *= aspect;

    float r = length(centered) * 2.0;
    float vignetteAlpha = smoothstep(u.vignetteInnerRadius, u.vignetteOuterRadius, r) * u.vignetteOpacity;
    float guideAlpha = 0.0;

    float2 px = uv * u.viewportSize;
    float2 centerDotPx = clamp(u.centerDotPosition, float2(0.0), float2(1.0)) * u.viewportSize;
    float2 crosshairPx = clamp(u.crosshairPosition, float2(0.0), float2(1.0)) * u.viewportSize;

    if (u.centerDotEnabled != 0) {
        float d = distance(px, centerDotPx);
        float dotAlpha = 1.0 - smoothstep(u.centerDotRadius, u.centerDotRadius + 1.5, d);
        guideAlpha = max(guideAlpha, dotAlpha * u.centerDotOpacity);
    }

    if (u.crosshairEnabled != 0) {
        float dx = abs(px.x - crosshairPx.x);
        float dy = abs(px.y - crosshairPx.y);
        bool horizontal = (dx < u.crosshairLength && dy < u.crosshairThickness);
        bool vertical = (dy < u.crosshairLength && dx < u.crosshairThickness);
        if (horizontal || vertical) {
            guideAlpha = max(guideAlpha, u.crosshairOpacity);
        }
    }

    if (u.horizonEnabled != 0) {
        float y = u.horizonY * u.viewportSize.y;
        float dy = abs(px.y - y);
        float margin = u.viewportSize.x * 0.18;
        bool inRange = px.x > margin && px.x < (u.viewportSize.x - margin);
        if (inRange && dy < 1.0) {
            guideAlpha = max(guideAlpha, u.horizonOpacity);
        }
    }

    if (u.dashboardEnabled != 0) {
        float yStart = u.viewportSize.y * 0.82;
        if (px.y > yStart) {
            float t = smoothstep(yStart, u.viewportSize.y, px.y);
            guideAlpha = max(guideAlpha, t * u.dashboardOpacity);
        }
    }

    if (u.virtualNoseEnabled != 0) {
        float2 noseCenter = float2(u.viewportSize.x * 0.5, u.viewportSize.y * 0.92);
        float2 p = (px - noseCenter) / float2(28.0, 44.0);
        float d = length(p);
        float noseAlpha = (1.0 - smoothstep(0.75, 1.0, d)) * u.virtualNoseOpacity;
        guideAlpha = max(guideAlpha, noseAlpha);
    }

    if (u.peripheralFrameEnabled != 0) {
        float edgeDistance = min(min(px.x, u.viewportSize.x - px.x), min(px.y, u.viewportSize.y - px.y));
        float thickness = max(1.0, u.peripheralFrameThickness * 2.0);
        float frameAlpha = (1.0 - smoothstep(thickness, thickness * 2.0, edgeDistance)) * u.peripheralFrameOpacity;
        guideAlpha = max(guideAlpha, frameAlpha);
    }

    float alpha = max(vignetteAlpha, guideAlpha);
    float guideMix = smoothstep(0.0, 0.02, guideAlpha) * clamp(guideAlpha / max(alpha, 0.001), 0.0, 1.0);
    float3 color = mix(float3(0.0, 0.0, 0.0), float3(0.92, 0.96, 1.0), guideMix);
    return float4(color, clamp(alpha, 0.0, 0.85));
}
