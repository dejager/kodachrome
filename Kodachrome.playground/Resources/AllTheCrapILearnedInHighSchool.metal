#include <metal_stdlib>
using namespace metal;

float2 rotato(float2 position, float axis) {
  return float2(position.x * cos(axis) - position.y * sin(axis), position.x * sin(axis) + position.y * cos(axis));
}

// 1D
float random(float n) {
    return fract(sin(n) * 43758.5453123);
}

// 2D
float2 random2(thread float2 p) {
  return fract(float2(sin(p.x * 591.32 + p.y * 154.077), cos(p.x * 391.32 + p.y * 49.077)));
}

float noise(float p) {
  float fl = floor(p);
  float fc = fract(p);
  return mix(random(fl), random(fl + 1.0), fc);
}

// Voronoi distance noise
float voronoi(thread float2 x) {
  float2 p = floor(x);
  float2 f = fract(x);

  float2 res = float2(8.0);
  for(int j = -1; j <= 1; j ++)
  {
    for(int i = -1; i <= 1; i ++)
    {
      float2 b = float2(i, j);
      float2 r = float2(b) - f + random2(p + b);

      float d = max(abs(r.x), abs(r.y));

      if(d < res.x)
      {
        res.y = res.x;
        res.x = d;
      }
      else if(d < res.y)
      {
        res.y = d;
      }
    }
  }
  return res.y - res.x;
}


kernel void giveUsThoseNiceBrightColors(texture2d<float, access::write> o[[texture(0)]],
                                        texture2d<float, access::read> i[[texture(1)]],
                                        constant float &time [[buffer(0)]],
                                        constant float2 *touchEvent [[buffer(1)]],
                                        constant int &numberOfTouches [[buffer(2)]],
                                        ushort2 gid [[thread_position_in_grid]]) {

  int width = o.get_width();
  int height = o.get_height();
  float2 res = float2(width, height);

  float2 uv = float2(gid.xy);
  uv = uv.xy / res.xy;
  uv = (uv - 0.5) * 2.0;
  float2 suv = uv;
  uv.x *= res.x / res.y;

  float flicker = noise(time * 2.0) * 0.8 + 0.4;
  float v = 0.0;

  // mingle
  uv *= 0.6 + sin(time * 0.1) * 0.4;
  uv = rotato(uv, sin(time * 0.3) * 1.0);
  uv += time * 0.4;


  float a = 0.6;
  float f = 1.0;

  for(int i = 0; i < 3; i ++) {
    float v1 = voronoi(uv * f + 5.0);
    float v2 = 0.0;

    // electrons
    if(i > 0) {
      v2 = voronoi(uv * f * 0.5 + 50.0 + time);

      float va = 0.0, vb = 0.0;
      va = 1.0 - smoothstep(0.0, 0.1, v1);
      vb = 1.0 - smoothstep(0.0, 0.08, v2);
      v += a * pow(va * (0.5 + vb), 2.0);
    }

    // looking sharp
    v1 = 1.0 - smoothstep(0.0, 0.3, v1);

    // noise intensity map
    v2 = a * (noise(v1 * 5.5 + 0.1));

    // sweet imagination
    if(i == 0) {
      v += v2 * flicker;
    } else {
      v += v2;
    }

    f *= 3.0;
    a *= 0.7;
  }

  // vignette it
  v *= exp(-0.6 * length(suv)) * 1.2;

  // give us those nice bright colors

  ushort2 texturePosition1 = ushort2(uv * 0.001);
  ushort2 texturePosition2 = ushort2(uv * 0.01);

  float3 textureColor1 = i.read(texturePosition1).rgb * 3.0;
  float3 textureColor2 = i.read(texturePosition2).rgb;

  float3 cexp = float3(2.0, 4.0, 6.0);

  float colorTime = time;
  colorTime *= 0.1;
  cexp.r += sin(colorTime);
  cexp.g -= abs(sin(colorTime * 1.324));
  cexp.b += sin(colorTime * 0.324);
  cexp *= 1.4;

  float3 col = float3(pow(v, cexp.x), pow(v, cexp.y), pow(v, cexp.z)) * 2.0;

  o.write(float4(col, 1.0), gid);
}
