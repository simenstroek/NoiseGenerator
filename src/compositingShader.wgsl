
@group(0) @binding(0) var<uniform> settings: Settings;
@group(0) @binding(1) var<uniform> render: Render;
@group(0) @binding(2) var<storage, read_write> noiseBuffer: array<float>;
@group(0) @binding(3) var<storage, read_write> outputBuffer: array<float>;

@vertex
fn vertex(@builtin(vertex_index) i: uint) -> @builtin(position) float4 {
  var pos = array<float2, 6>(
    float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0),
    float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
  );
  return float4(pos[i], 0.0, 1.0);
}

// value, normal x, normal y, 0, 1 of generator g at this pixel
fn sample_values(g: uint, index: uint, indexL: uint, indexB: uint, res: float2) -> array<float, 5> {
  let count = uint(settings.generatorCount);
  let i = min(g, count - 1u);
  let v = noiseBuffer[index * count + i];
  let gdx = (v - noiseBuffer[indexL * count + i]) * res.x * 0.1;
  let gdy = (v - noiseBuffer[indexB * count + i]) * res.y * 0.1;
  let glength = sqrt(gdx * gdx + gdy * gdy + 1.0);
  return array<float, 5>(v, -gdx / glength * 0.5 + 0.5, -gdy / glength * 0.5 + 0.5, 0.0, 1.0);
}

@fragment
fn fragment(@builtin(position) fragCoord: float4) -> @location(0) float4 {
  let generatorIndex = uint(settings.generatorIndex);
  let resolutionX = uint(settings.resolutionX);
  let resolutionY = uint(settings.resolutionY);
  let resolutionZ = uint(settings.resolutionZ);
  let xTiles = uint(settings.xTiles);
  let yTiles = uint(settings.yTiles);
  let channel0display = float(settings.channel0display);
  let channel0generator = uint(settings.channel0generator);
  let channel0type = uint(settings.channel0type);
  let channel0invert = uint(settings.channel0invert) != 0u;
  let channel0gain = float(settings.channel0gain);
  let channel0gamma = float(settings.channel0gamma);
  let channel0offset = float(settings.channel0offset);
  let channel1display = float(settings.channel1display);
  let channel1generator = uint(settings.channel1generator);
  let channel1type = uint(settings.channel1type);
  let channel1invert = uint(settings.channel1invert) != 0u;
  let channel1gain = float(settings.channel1gain);
  let channel1gamma = float(settings.channel1gamma);
  let channel1offset = float(settings.channel1offset);
  let channel2display = float(settings.channel2display);
  let channel2generator = uint(settings.channel2generator);
  let channel2type = uint(settings.channel2type);
  let channel2invert = uint(settings.channel2invert) != 0u;
  let channel2gain = float(settings.channel2gain);
  let channel2gamma = float(settings.channel2gamma);
  let channel2offset = float(settings.channel2offset);
  let channel3display = float(settings.channel3display);
  let channel3generator = uint(settings.channel3generator);
  let channel3type = uint(settings.channel3type);
  let channel3invert = uint(settings.channel3invert) != 0u;
  let channel3gain = float(settings.channel3gain);
  let channel3gamma = float(settings.channel3gamma);
  let channel3offset = float(settings.channel3offset);

  let renderType = u32(render.renderType);
  let lightPositionX = float(render.lightPositionX);
  let lightPositionY = float(render.lightPositionY);
  let activeGenerator = u32(render.activeGenerator);

  let normalScale = 1.0;

  let fragX = uint(fragCoord.x);
  let fragY = uint(fragCoord.y);
  let tileX = fragX / resolutionX;
  let tileY = fragY / resolutionY;
  let x = fragX % resolutionX;
  let y = fragY % resolutionY;
  let z = tileX + xTiles * tileY;
  let u = float(fragX) / float(resolutionX * xTiles);
  let v = float(fragY) / float(resolutionY * yTiles);

  let outputIndex = fragX + (resolutionX * xTiles) * fragY;
  let index = x + resolutionX * y + resolutionX * resolutionY * z;
  let indexL = ((x + 1) % resolutionX) + resolutionX * y + resolutionX * resolutionY * z;
  let indexB = x + resolutionX * ((y + 1) % resolutionY) + resolutionX * resolutionY * z;

  let res = float2(float(resolutionX), float(resolutionY));
  var values = array<array<float, 5>, 4>(
    sample_values(channel0generator, index, indexL, indexB, res),
    sample_values(channel1generator, index, indexL, indexB, res),
    sample_values(channel2generator, index, indexL, indexB, res),
    sample_values(channel3generator, index, indexL, indexB, res),
  );
  let previewGenerator = i32(render.previewGenerator);
  let activeValues = sample_values(activeGenerator, index, indexL, indexB, res);

  var outputR = saturate(pow(values[0][channel0type] * channel0gain, channel0gamma) + channel0offset);
  var outputG = saturate(pow(values[1][channel1type] * channel1gain, channel1gamma) + channel1offset);
  var outputB = saturate(pow(values[2][channel2type] * channel2gain, channel2gamma) + channel2offset);
  var outputA = saturate(pow(values[3][channel3type] * channel3gain, channel3gamma) + channel3offset);

  if (channel0invert) { outputR = 1.0 - outputR; };
  if (channel1invert) { outputG = 1.0 - outputG; };
  if (channel2invert) { outputB = 1.0 - outputB; };
  if (channel3invert) { outputA = 1.0 - outputA; };

  outputBuffer[outputIndex * 4 + 0] = outputR;
  outputBuffer[outputIndex * 4 + 1] = outputG;
  outputBuffer[outputIndex * 4 + 2] = outputB;
  outputBuffer[outputIndex * 4 + 3] = outputA;

  var output = float4(outputR * channel0display, outputG * channel1display, outputB * channel2display, mix(1.0, outputA, channel3display));

  if (previewGenerator >= 0) {
    // preview shows the raw generator value; outputBuffer (export) keeps the channel output
    let pv = saturate(sample_values(uint(previewGenerator), index, indexL, indexB, res)[0]);
    output = float4(pv, pv, pv, 1.0);
  }

  let checkerColor = (floor(float(fragX) * 0.1) + floor(float(fragY) * 0.1)) % 2.0 * 0.2 + 0.2;
  let background = float4(checkerColor, checkerColor, checkerColor, checkerColor);

  let normal = normalize(float3(activeValues[1] * 2.0 - 1.0, activeValues[2] * 2.0 - 1.0, 1.0));
  let viewDirection = normalize(float3(u * 2.0 - 1.0, v * 2.0 - 1.0, 1.0));
  let lightDirection = normalize(float3(lightPositionX, lightPositionY, 1.0));
  let halfVec = normalize(lightDirection + viewDirection);
  let nDotL = saturate(dot(normal, lightDirection));
  let nDotH = saturate(dot(normal, halfVec));
  let specular = pow(nDotH, 10.0);

  if (renderType == RENDER_TYPE_BASE) {
    return alpha_blend(output, background);
  }

  if (renderType == RENDER_TYPE_LIT) {
    return float4(specular, specular, specular, 1.0);
  }

  return alpha_blend(output, background);
}