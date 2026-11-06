
@group(0) @binding(0) var<uniform> settings: Settings;
@group(0) @binding(1) var<uniform> render: Render;
@group(0) @binding(2) var<storage, read_write> noiseBuffer: array<float>;


// Base value of generator `gi` at position `p_in` (0..1 across the texture).
// Ignores that generator's own warp; Blend generators have no position, so they return neutral 0.5.
fn noise_base(gi: uint, p_in: float3) -> float {
  let g = settings.generators[gi];
  let noiseType = uint(g.noiseType);
  let perlinSize = float(g.perlinSize);
  let perlinOctaves = uint(g.perlinOctaves);
  let perlinLacunarity = float(g.perlinLacunarity);
  let voronoiCellSize = float(g.voronoiCellSize);
  let voronoiDistanceType = uint(g.voronoiDistanceType);
  let seamless = uint(g.seamless) != 0u;
  let seed = uint(g.seed);
  let resolution = float3(settings.resolutionX, settings.resolutionY, settings.resolutionZ);

  // wrapping the position (e.g. after a warp) keeps seamless noise seamless
  var p = p_in;
  if (seamless) {
    p = fract(p_in);
  }

  if (noiseType == NOISE_TYPE_RANDOM) {
    return rand01(hash_int3(int3(floor(p * resolution + 0.5)) * 500) + seed);
  }

  if (noiseType == NOISE_TYPE_PERLIN) {
    let grid_resolution = int(floor(1.0 / perlinSize));
    let position = p * float(grid_resolution);
    var sum = 0.0;

    for (var i = 0u; i < perlinOctaves; i++)
    {
      let s = seed + i;
      let attenuation = floor(pow(perlinLacunarity, float(i)));
      let q = position * attenuation;
      let pi = int3(floor(q));
      let pf = fract(q);
      let f = fade(pf);

      let period = select(int3(100000000), int3(grid_resolution * int(attenuation)), seamless);

      let n000 = grad(hash_int3((pi + int3(0, 0, 0)) % period) + s, pf - float3(0, 0, 0));
      let n001 = grad(hash_int3((pi + int3(0, 0, 1)) % period) + s, pf - float3(0, 0, 1));
      let n010 = grad(hash_int3((pi + int3(0, 1, 0)) % period) + s, pf - float3(0, 1, 0));
      let n011 = grad(hash_int3((pi + int3(0, 1, 1)) % period) + s, pf - float3(0, 1, 1));
      let n100 = grad(hash_int3((pi + int3(1, 0, 0)) % period) + s, pf - float3(1, 0, 0));
      let n101 = grad(hash_int3((pi + int3(1, 0, 1)) % period) + s, pf - float3(1, 0, 1));
      let n110 = grad(hash_int3((pi + int3(1, 1, 0)) % period) + s, pf - float3(1, 1, 0));
      let n111 = grad(hash_int3((pi + int3(1, 1, 1)) % period) + s, pf - float3(1, 1, 1));

      let x00 = mix(n000, n100, f.x);
      let x01 = mix(n001, n101, f.x);
      let x10 = mix(n010, n110, f.x);
      let x11 = mix(n011, n111, f.x);

      let y0 = mix(x00, x10, f.y);
      let y1 = mix(x01, x11, f.y);

      sum += mix(y0, y1, f.z) / attenuation;
    }

    return sum * 0.5 + 0.5;
  }

  if (noiseType == NOISE_TYPE_VORONOI) {
    let grid_resolution = int(floor(1.0 / voronoiCellSize));
    let cell_size = 1.0 / float(grid_resolution);
    let cell = int3(floor(p * float(grid_resolution)));

    let weights = float4(g.voronoiWeight1, g.voronoiWeight2, g.voronoiWeight3, g.voronoiWeight4);
    var min_distances = float4(999999.0, 999999.0, 999999.0, 999999.0);

    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dz = -1; dz <= 1; dz++) {
          var neighbor_cell = cell + int3(dx, dy, dz);
          if (seamless) {
            neighbor_cell = (neighbor_cell + grid_resolution) % grid_resolution;
          }

          let feature_point = (float3(neighbor_cell) + rand_vector(hash_int3(neighbor_cell) + seed)) * cell_size;
          var delta = feature_point - p;
          if (seamless) {
            delta = min(abs(delta), 1.0 - abs(delta)); // toroidal distance
          }
          delta /= cell_size;
          var dist = 0.0;

          if (voronoiDistanceType == VORONOI_DISTANCE_TYPE_EUCLIDEAN) {
            dist = length(delta);
          }
          if (voronoiDistanceType == VORONOI_DISTANCE_TYPE_SQUARED) {
            dist = (delta.x * delta.x + delta.y * delta.y + delta.z * delta.z);
          }
          if (voronoiDistanceType == VORONOI_DISTANCE_TYPE_MANHATTAN) {
            dist = abs(delta.x) + abs(delta.y) + abs(delta.z);
          }
          if (voronoiDistanceType == VORONOI_DISTANCE_TYPE_CHEBYSHEV) {
            dist = max(max(abs(delta.x), abs(delta.y)), abs(delta.z));
          }

          // insert sorted
          if (dist < min_distances.x) {
            min_distances.w = min_distances.z;
            min_distances.z = min_distances.y;
            min_distances.y = min_distances.x;
            min_distances.x = dist;
          } else if (dist < min_distances.y) {
            min_distances.w = min_distances.z;
            min_distances.z = min_distances.y;
            min_distances.y = dist;
          } else if (dist < min_distances.z) {
            min_distances.w = min_distances.z;
            min_distances.z = dist;
          } else if (dist < min_distances.w) {
            min_distances.w = dist;
          }
        }
      }
    }

    return dot(min_distances, weights);
  }

  return 0.5;
}


// noise_base plus the generator's invert, so warp sources respect it too
fn noise_at(gi: uint, p_in: float3) -> float {
  let v = noise_base(gi, p_in);
  return select(v, 1.0 - v, settings.generators[gi].invert != 0.0);
}


fn blend_op(mode: uint, a: float, b: float) -> float {
  if (mode == BLEND_ADD) { return a + b; }
  if (mode == BLEND_MULTIPLY) { return a * b; }
  if (mode == BLEND_SCREEN) { return 1.0 - (1.0 - a) * (1.0 - b); }
  if (mode == BLEND_DIFFERENCE) { return abs(a - b); }
  if (mode == BLEND_MIN) { return min(a, b); }
  if (mode == BLEND_MAX) { return max(a, b); }
  if (mode == BLEND_OVERLAY) { return select(1.0 - 2.0 * (1.0 - a) * (1.0 - b), 2.0 * a * b, a < 0.5); }
  return b; // BLEND_MIX
}


@compute @workgroup_size(8, 8, 8)
fn main(@builtin(global_invocation_id) coord: uint3) {
  let generatorIndex = uint(settings.generatorIndex);
  let count = uint(settings.generatorCount);
  let resolutionX = uint(settings.resolutionX);
  let resolutionY = uint(settings.resolutionY);
  let resolutionZ = uint(settings.resolutionZ);

  let x = coord.x;
  let y = coord.y;
  let z = coord.z;

  if (x >= resolutionX || y >= resolutionY || z >= resolutionZ) {
    return;
  };

  let resolution = uint3(resolutionX, resolutionY, resolutionZ);
  let index = x + resolutionX * y + resolutionX * resolutionY * z;
  let g = settings.generators[generatorIndex];
  var output = 0.0;

  if (uint(g.noiseType) == NOISE_TYPE_BLEND) {
    // Generators run in order 0..3, so only earlier ones are in the buffer yet; later ones read as 0.
    let a = int(g.blendA);
    let b = int(g.blendB);
    let m = int(g.blendMask);
    let av = select(0.0, noiseBuffer[index * count + uint(max(a, 0))], a >= 0 && a < int(generatorIndex));
    let bv = select(0.0, noiseBuffer[index * count + uint(max(b, 0))], b >= 0 && b < int(generatorIndex));
    var factor = float(g.blendFactor);
    if (m >= 0 && m < int(generatorIndex)) {
      factor = noiseBuffer[index * count + uint(m)];
    }
    output = mix(av, blend_op(uint(g.blendMode), av, bv), saturate(factor));
    if (g.invert != 0.0) { output = 1.0 - output; }
  } else {
    var p = float3(coord) / float3(resolution);
    let warpSource = int(g.warpSource);
    if (warpSource >= 0 && warpSource < int(count) && uint(warpSource) != generatorIndex) {
      // offset = the source noise sampled at 3 decorrelated positions, centered on 0
      let w = uint(warpSource);
      let offset = float3(
        noise_at(w, p),
        noise_at(w, p + float3(0.19, 0.43, 0.71)),
        noise_at(w, p + float3(0.67, 0.23, 0.37))
      ) - 0.5;
      p += offset * float(g.warpStrength);
    }
    output = noise_at(generatorIndex, p);
  }

  noiseBuffer[index * count + generatorIndex] = output;
}
