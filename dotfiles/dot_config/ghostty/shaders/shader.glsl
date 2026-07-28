#define ROLLING_SQUARE_SIZE          25.0
#define ROLLING_SQUARE_BASE_Y        5.0
#define ROLLING_SQUARE_EDGE_SOFT     2.0
#define ROLLING_SQUARE_START_X       40.0
#define ROLL_STEPS                   8.0
#define ROLLING_WRAP                 1600.0

const vec3 colorPalette[] = vec3[](
    vec3(0.40, 0.05, 0.85),
    vec3(0.30, 0.10, 0.60)
);
#define PALETTE_COUNT 2

#define PIXEL_SIZE 3.0

int decodeSignalCounter(vec3 color) {
    ivec3 rgb = ivec3(floor(color * 255.0 + 0.5));
    int rh = rgb.r / 16;
    int gh = rgb.g / 16;
    int bh = rgb.b / 16;
    if (rh != 14 || gh != 7 || (bh != 10 && bh != 11)) return -1;
    int hi   = rgb.r - rh * 16;
    int lo   = rgb.g - gh * 16;
    int high = bh - 10;
    int checksum = rgb.b - bh * 16;
    if (checksum != (hi + lo * 3 + high * 5 + 7) % 16) return -1;
    return high * 256 + hi * 16 + lo;
}

float decodedTurns(int currCounter) {
    if (currCounter < 0) return 0.0;
    return float(currCounter) / ROLL_STEPS;
}

float hash1D(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

vec3 getPaletteColor(int index) {
    // Safe modulo — handles negative index without UB on Metal/macOS.
    return colorPalette[((index % PALETTE_COUNT) + PALETTE_COUNT) % PALETTE_COUNT];
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

float rollingSquareDistance(vec2 p, float squareX, float rollProgress) {
    float halfSize = ROLLING_SQUARE_SIZE * 0.5;
    float halfPI   = 1.5707963267948966;
    float squareY  = ROLLING_SQUARE_BASE_Y + halfSize;

    float rotationAngle = rollProgress * halfPI;
    vec2  pivotPoint    = vec2(squareX + halfSize, ROLLING_SQUARE_BASE_Y);
    vec2  squareCenter  = vec2(squareX, squareY);

    vec2  rotatedP = rotate(p, rotationAngle, pivotPoint);
    return boxDistance(rotatedP - squareCenter, vec2(halfSize));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv        = fragCoord / iResolution.xy;
    vec2 pixCoord  = floor(fragCoord / PIXEL_SIZE) * PIXEL_SIZE;
    vec4 termColor = texture(iChannel0, uv);

    float turns = decodedTurns(decodeSignalCounter(iCurrentCursorColor.rgb));

    float completedRolls = floor(turns);
    float rollProgress   = fract(turns);

    float squareX = mod(ROLLING_SQUARE_START_X + completedRolls * ROLLING_SQUARE_SIZE,
                        ROLLING_WRAP);

    vec2  px = vec2(pixCoord.x, iResolution.y - pixCoord.y);
    float d  = rollingSquareDistance(px, squareX, rollProgress);

    float varyEdgeSoft = ROLLING_SQUARE_EDGE_SOFT * (0.6 + 0.6 * hash1D(px.x * 0.005));
    float varyWaveFreq = 1.0 + 0.5 * sin(px.x * 0.002 + iTime * 0.3);
    float wave = 1.0 - smoothstep(-varyEdgeSoft, varyEdgeSoft, d * varyWaveFreq);

    vec3 resultColor = termColor.rgb;
    if (wave > 0.001) {
        vec3 squareColor = getPaletteColor(int(completedRolls));
        resultColor = clamp(resultColor + squareColor * wave * 0.8, 0.0, 1.0);
    }

    fragColor = vec4(resultColor, termColor.a);
}
