#define ROLLING_SQUARE_SIZE                 30.0
#define ROLLING_SQUARE_BASE_Y               5.0
#define ROLLING_SQUARE_EDGE_SOFT            2.0
#define ROLLING_SQUARE_START_X              0.0
#define ROLL_STEPS                          8.0
#define ROLLING_BASE_WRAP_DISTANCE          2400.0
#define ROLLING_EXTRA_WRAP_DISTANCE         0.0
#define PIXEL_SIZE                          3.0
#define EDGE_SOFT_BASE                      0.6
#define EDGE_SOFT_VARIATION                 0.6
#define EDGE_HASH_SCALE_X                   0.005
#define WAVE_FREQ_BASE                      1.0
#define WAVE_FREQ_VARIATION                 0.5
#define WAVE_SPATIAL_SCALE_X                0.002
#define WAVE_TIME_SCALE                     0.3
#define WAVE_VISIBILITY_THRESHOLD           0.001
#define COLOR_BLEND_STRENGTH                0.8

#define PALETTE_COUNT                       2
#define COLOR_TO_BYTE_SCALE                 255.0
#define COLOR_TO_BYTE_ROUND_BIAS            0.5
#define NIBBLE_BASE                         16
#define COUNTER_PREFIX_R                    14
#define COUNTER_PREFIX_G                    7
#define COUNTER_HIGH_MIN                    10
#define COUNTER_HIGH_MAX                    11
#define COUNTER_HIGH_OFFSET                 10
#define CHECKSUM_LO_WEIGHT                  3
#define CHECKSUM_HIGH_WEIGHT                5
#define CHECKSUM_BIAS                       7
#define COUNTER_HIGH_MULTIPLIER             256
#define HASH_SIN_SCALE                      12.9898
#define HASH_OUTPUT_SCALE                   43758.5453
#define HALF_PI                             1.5707963267948966
#define WRAP_TILE_CAP                       512.0

const vec3 colorPalette[] = vec3[](
    vec3(0.40, 0.05, 0.85),
    vec3(0.30, 0.10, 0.60)
);

int decodeSignalCounter(vec3 color) {
    ivec3 rgb = ivec3(floor(color * COLOR_TO_BYTE_SCALE + COLOR_TO_BYTE_ROUND_BIAS));
    int rh = rgb.r / NIBBLE_BASE;
    int gh = rgb.g / NIBBLE_BASE;
    int bh = rgb.b / NIBBLE_BASE;
    if (rh != COUNTER_PREFIX_R || gh != COUNTER_PREFIX_G || (bh != COUNTER_HIGH_MIN && bh != COUNTER_HIGH_MAX)) return -1;
    int hi   = rgb.r - rh * NIBBLE_BASE;
    int lo   = rgb.g - gh * NIBBLE_BASE;
    int high = bh - COUNTER_HIGH_OFFSET;
    int checksum = rgb.b - bh * NIBBLE_BASE;
    if (checksum != (hi + lo * CHECKSUM_LO_WEIGHT + high * CHECKSUM_HIGH_WEIGHT + CHECKSUM_BIAS) % NIBBLE_BASE) return -1;
    return high * COUNTER_HIGH_MULTIPLIER + hi * NIBBLE_BASE + lo;
}

float decodedTurns(int currCounter) {
    if (currCounter < 0) return 0.0;
    return float(currCounter) / ROLL_STEPS;
}

float hash1D(float x) {
    return fract(sin(x * HASH_SIN_SCALE) * HASH_OUTPUT_SCALE);
}

vec3 getPaletteColor(int index) {
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
    float halfPI   = HALF_PI;
    float baseY    = ROLLING_SQUARE_BASE_Y;
    float squareY  = baseY + halfSize;

    float rotationAngle = rollProgress * halfPI;
    vec2  pivotPoint    = vec2(squareX + halfSize, baseY);
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

    float desiredWrapWidth = ROLLING_BASE_WRAP_DISTANCE + ROLLING_EXTRA_WRAP_DISTANCE;
    float maxWrapWidth = (WRAP_TILE_CAP / ROLL_STEPS) * ROLLING_SQUARE_SIZE;
    float snappedWrapWidth = floor(desiredWrapWidth / ROLLING_SQUARE_SIZE) * ROLLING_SQUARE_SIZE;
    float wrapWidth = clamp(snappedWrapWidth, ROLLING_SQUARE_SIZE, maxWrapWidth);
    float squareX = mod(ROLLING_SQUARE_START_X + completedRolls * ROLLING_SQUARE_SIZE,
                        wrapWidth);

    vec2  px = vec2(pixCoord.x, iResolution.y - pixCoord.y);
    float d  = rollingSquareDistance(px, squareX, rollProgress);

    float varyEdgeSoft = ROLLING_SQUARE_EDGE_SOFT * (EDGE_SOFT_BASE + EDGE_SOFT_VARIATION * hash1D(px.x * EDGE_HASH_SCALE_X));
    float varyWaveFreq = WAVE_FREQ_BASE + WAVE_FREQ_VARIATION * sin(px.x * WAVE_SPATIAL_SCALE_X + iTime * WAVE_TIME_SCALE);
    float wave = 1.0 - smoothstep(-varyEdgeSoft, varyEdgeSoft, d * varyWaveFreq);

    vec3 resultColor = termColor.rgb;
    if (wave > WAVE_VISIBILITY_THRESHOLD) {
        vec3 squareColor = getPaletteColor(int(completedRolls));
        resultColor = clamp(resultColor + squareColor * wave * COLOR_BLEND_STRENGTH, 0.0, 1.0);
    }

    fragColor = vec4(resultColor, termColor.a);
}
