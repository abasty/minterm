// Distorsion en barillet façon tube cathodique bombé (effet "CRT 80's").
// L'image de l'écran Minitel déjà rendu (avec ses scanlines) est fournie
// comme texture uTexture ; on échantillonne chaque pixel de sortie à une
// coordonnée source décalée vers l'extérieur proportionnellement au carré
// de la distance au centre. Aux coins, où cette distance est maximale, la
// coordonnée source sort de [0,1] : on peint du noir, ce qui donne
// naturellement des coins arrondis/coupés, comme le bord visible d'un vrai
// tube bombé — sans masque séparé.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uStrength;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 centered = uv * 2.0 - 1.0;
  float r2 = dot(centered, centered);
  vec2 warped = centered * (1.0 + uStrength * r2);
  vec2 srcUv = warped * 0.5 + 0.5;

  // On échantillonne toujours à une coordonnée clampée puis on masque le
  // résultat après coup (mix/step) plutôt qu'un early return avant
  // texture() : plus robuste sur les cibles où une branche juste avant un
  // texture() peut perturber l'échantillonnage.
  vec4 sampled = texture(uTexture, clamp(srcUv, 0.0, 1.0));
  float inBounds = step(0.0, srcUv.x) * step(srcUv.x, 1.0) *
      step(0.0, srcUv.y) * step(srcUv.y, 1.0);
  fragColor = mix(vec4(0.0, 0.0, 0.0, 1.0), sampled, inBounds);
}
