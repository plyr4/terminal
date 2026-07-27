#define ROLLING_SQUARE_SIZE        25.0
#define ROLLING_SQUARE_SPEED       50.0
#define ROLLING_SQUARE_BASE_Y      5.0
#define ROLLING_SQUARE_EDGE_SOFT   2.0
#define ROLLING_SQUARE_PAUSE_TIME  10.0
#define ROLLING_SQUARE_COUNT       2
#define ROLLING_SQUARE_SPACING     12300.0

const vec3 colorPalette[] = vec3[](
    vec3(0.40, 0.05, 0.85),
    vec3(0.30, 0.10, 0.60)
);

#define PALETTE_COUNT 2

#define PIXEL_SIZE    3.0
#define COLOR_STEPS   1.0

float hash1D(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

vec3 getPaletteColor(int index) {
    return colorPalette[index % PALETTE_COUNT];
}

vec2 rotate(vec2 p, float angle, vec2 pivot) {
    float c = cos(angle);
    float s = sin(angle);
    vec2 rel = p - pivot;
    return pivot + vec2(c * rel.x - s * rel.y, s * rel.x + c * rel.y);
}

float boxDistance(vec2 p, vec2 halfSize) {
    vec2 d = abs(p) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float rollingSquareDistance(vec2 p, float t, int squareIndex) {
    float largeWrap = 2000.0;
    float halfSize = ROLLING_SQUARE_SIZE * 0.5;
    
    float squareOffset = float(squareIndex) * ROLLING_SQUARE_SPACING;
    float distanceTraveled = t * ROLLING_SQUARE_SPEED + squareOffset;
    float cycleDistance = ROLLING_SQUARE_SIZE + ROLLING_SQUARE_PAUSE_TIME * ROLLING_SQUARE_SPEED;
    float cycleProgress = mod(distanceTraveled, cycleDistance);
    float rotationCycles = floor(distanceTraveled / cycleDistance);
    
    float squareX = mod(rotationCycles * ROLLING_SQUARE_SIZE, largeWrap);
    float squareY = ROLLING_SQUARE_BASE_Y + halfSize;
    
    float rotationAngle = 0.0;
    float halfPI = 1.5707963267948966;
    
    if (cycleProgress < ROLLING_SQUARE_SIZE) {
        float progress = cycleProgress / ROLLING_SQUARE_SIZE;
        rotationAngle = progress * halfPI;
    } else {
        rotationAngle = halfPI;
    }
    
    vec2 pivotPoint = vec2(squareX + halfSize, ROLLING_SQUARE_BASE_Y);
    vec2 squareCenter = vec2(squareX, squareY);
    
    vec2 rotatedP = rotate(p, rotationAngle, pivotPoint);
    float d = boxDistance(rotatedP - squareCenter, vec2(halfSize));
    
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 pixCoord = floor(fragCoord / PIXEL_SIZE) * PIXEL_SIZE;
    vec4 termColor = texture(iChannel0, uv);
    float t = iTime;

    vec3 resultColor = termColor.rgb;

    vec2 px = vec2(pixCoord.x, iResolution.y - pixCoord.y);
    
    for (int i = 0; i < ROLLING_SQUARE_COUNT; i++) {
        float d = rollingSquareDistance(px, t, i);
        
        float squareOffset = float(i) * ROLLING_SQUARE_SPACING;
        float distanceTraveled = t * ROLLING_SQUARE_SPEED + squareOffset;
        float cycleDistance = ROLLING_SQUARE_SIZE + ROLLING_SQUARE_PAUSE_TIME * ROLLING_SQUARE_SPEED;
        float cycleProgress = mod(distanceTraveled, cycleDistance);
        float rotationCycles = floor(distanceTraveled / cycleDistance);
        
        float colorT;
        if (cycleProgress < ROLLING_SQUARE_SIZE) {
            colorT = rotationCycles;
        } else {
            colorT = rotationCycles + 1.0;
        }
        
        float varyEdgeSoft = ROLLING_SQUARE_EDGE_SOFT * (0.6 + 0.6 * hash1D(px.x * 0.005));
        float varyWaveFreq = 1.0 + 0.5 * sin(px.x * 0.002 + iTime * 0.3);
        float wave = 1.0 - smoothstep(-varyEdgeSoft, varyEdgeSoft, d * varyWaveFreq);
        
        if (wave > 0.001) {
            vec3 squareColor = getPaletteColor(int(colorT));
            resultColor = clamp(resultColor + squareColor * wave * 0.8, 0.0, 1.0);
        }
    }

    fragColor = vec4(resultColor, termColor.a);
}
