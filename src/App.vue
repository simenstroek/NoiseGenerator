<template>
  <div class="container text-center" :style="{'max-width': '1000px'}">
    <div class="row m-5">
      <div class="position-relative">
        <h1 class="display-3">Noise Generator</h1><span class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-info">Blend &amp; warp</span>
      </div>
      <p><small>A 3D noise texture generator with blending and domain warping. A fork of the <a href="https://github.com/Bubblebird-Studio/NoiseGenerator" target="_blank">NoiseGenerator</a> by Bubblebird Studio (MIT license).</small></p>
    </div>

    <div v-if="error != ''" class="alert alert-danger" role="alert">
      <p>{{ error }}</p>
      <p>Open an issue on <a href="https://github.com/simenstroek/NoiseGenerator/issues">Github</a> to let us know what went wrong.</p>
    </div>

    <div class="row">
      <div class="col-md-auto position-sticky align-self-start" :style="{top: '1rem'}">
        <div class="viewer overflow-auto">
          <div v-if="generating" id="generatingPlanel" class="d-flex align-items-center justify-content-center">
            <div class="spinner-border" role="status">
              <span class="visually-hidden">Generating...</span>
            </div>
          </div>
          <div v-if="renderType == 1" id="previewInfoPanel" class="d-flex align-content-center justify-content-center">
            <p>Lit view of G{{ litGenerator }}</p>
          </div>
          <canvas width="256" height="256" ref="canvas" @mouseenter="renderType = 1" @mouseleave="renderType = 0" @mousemove="handleMouseMove"></canvas>
        </div>

        <p class="text-info">
          <span class="m-3">{{ settings.name }}.png</span>
          <span class="m-3">{{ canvasWidth }} x {{ canvasHeight }} pixels</span>
          <span class="m-3" v-if="is3d">{{ xTiles }} x {{ yTiles }} tiles</span>
        </p>

        <div class="input-group mb-3 justify-content-center">
          <label class="input-group-text">Display</label>
          <label class="input-group-text" for="outputR">R</label>
          <div class="input-group-text">
            <input class="form-check-input" type="checkbox" id="outputR" v-model="settings.channels[0].display">
          </div>
          <label class="input-group-text" for="outputG">G</label>
          <div class="input-group-text">
            <input class="form-check-input" type="checkbox" id="outputG" v-model="settings.channels[1].display">
          </div>
          <label class="input-group-text" for="outputB">B</label>
          <div class="input-group-text">
            <input class="form-check-input" type="checkbox" id="outputB" v-model="settings.channels[2].display">
          </div>
          <label class="input-group-text" for="outputA">A</label>
          <div class="input-group-text">
            <input class="form-check-input" type="checkbox" id="outputA" v-model="settings.channels[3].display">
          </div>
        </div>

        <div class="btn-group" role="group">
          <button class="btn btn-primary mt-3" type="button" @click="exportImage()"><i class="bi bi-download"></i> Export PNG</button>
          <button class="btn btn-secondary mt-3" type="button" @click="copyImageToClipboard()"><i class="bi bi-copy"></i> Copy</button>
          <button class="btn btn-secondary mt-3" type="button" data-bs-toggle="modal" data-bs-target="#loadBackdrop"><i class="bi bi-floppy"></i> Load...</button>
          <button class="btn btn-secondary mt-3" type="button" data-bs-toggle="modal" data-bs-target="#saveBackdrop"><i class="bi bi-floppy"></i> Save...</button>
        </div>
      </div>

      <div class="col">
        <div class="input-group mb-3">
          <label class="input-group-text" for="resolution">Resolution</label>
          <div class="input-group-text">
            <input type="range" class="form-range" min="3" max="12" id="resolution" :value="Math.log2(settings.resolution)" @input="event => settings.resolution = 1 << event.target.value">
          </div>
          <label class="input-group-text" for="resolution">{{ settings.resolution }}</label>
        </div>

        <div class="input-group mb-3">
          <label class="input-group-text" for="dimension">Dimension</label>
          <select class="form-select" id="dimension" v-model="settings.dimension">
            <option value="2d">2D</option>
            <option value="3d">3D</option>
          </select>
          <span v-show="settings.dimension == '3d' && settings.resolution > 256" class="input-group-text text-danger" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Resolution is too high for 3d. Generating an image will fall back to 2d.">
            <i class="bi bi-exclamation-triangle-fill"></i>
          </span>
        </div>

        <div v-show="settings.dimension == '3d'" class="input-group mb-3">
          <label class="input-group-text" for="layout">3D tiles layout</label>
          <select class="form-select" id="layout" v-model="settings.layout">
            <option value="auto">Auto</option>
            <option value="square">Square</option>
            <option value="horizontal">Horizontal</option>
            <option value="vertical">Vertical</option>
          </select>
          <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Lets you choose how to arrange the tiles (the slices of your volume texture) in 2D.">
            <i class="bi bi-question"></i>
          </span>
        </div>

        <!-- ################  GENERATORS  ################ -->
        <div v-for="(gen, gi) in settings.generators" :key="gen.uid" class="card mb-3 text-start" :class="{'border-info': settings.previewGenerator == gi}">
          <div class="card-header d-flex align-items-center gap-2" role="button" @click="openGenerator = openGenerator == gi ? -1 : gi">
            <i class="bi" :class="openGenerator == gi ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
            <strong>G{{ gi }}</strong>
            <select class="form-select form-select-sm w-auto" v-model="gen.type" @click.stop>
              <option v-for="(noiseType, i) in noiseTypes" :value="i">{{ noiseType }}</option>
            </select>
            <button class="btn btn-sm ms-auto" :class="settings.previewGenerator == gi ? 'btn-info' : 'btn-outline-info'" type="button" title="Preview this generator" @click.stop="settings.previewGenerator = settings.previewGenerator == gi ? -1 : gi"><i class="bi bi-eye"></i> Preview</button>
            <button class="btn btn-sm btn-outline-danger" type="button" title="Remove generator" :disabled="settings.generators.length <= 1" @click.stop="removeGenerator(gi)"><i class="bi bi-trash3"></i></button>
          </div>
          <div v-show="openGenerator == gi" class="card-body p-3">
          <div v-show="gen.type == noiseTypes.indexOf('Perlin')" class="settings m-3">
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'perlinSize'+gi">Size</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="0.01" max="0.3" step="0.01" v-model="gen.perlinSize">
              </div>
              <input type="number" class="form-control" min="0.01" max="0.3" step="0.01" v-model="gen.perlinSize" :id="'perlinSize'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'perlinOctaves'+gi">Octaves</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="1" max="10" step="1" :id="'perlinOctaves'+gi" v-model="gen.perlinOctaves">
              </div>
              <label class="input-group-text" :for="'perlinOctaves'+gi">{{ gen.perlinOctaves }}</label>
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Sets the number of noise layers combined to create fractal detail.">
                <i class="bi bi-question"></i>
              </span>
            </div>
            <div v-show="gen.perlinOctaves > 1" class="input-group mb-1">
              <label class="input-group-text" :for="'perlinLacunarity'+gi">Lacunarity</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="1.0" max="10.0" step="0.01" v-model="gen.perlinLacunarity" @dblclick="gen.perlinLacunarity = defaultGeneratorSettings.perlinLacunarity">
              </div>
              <input type="number" class="form-control" min="1.0" max="10.0" step="0.01" v-model="gen.perlinLacunarity" :id="'perlinLacunarity'+gi">
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Controls how quickly frequency increases with each octave, affecting texture detail.">
                <i class="bi bi-question"></i>
              </span>
            </div>
          </div>

          <div v-show="gen.type == noiseTypes.indexOf('Voronoi')" class="settings m-3">
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiCellSize'+gi">Cell size</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="0.01" max="0.3" step="0.01" v-model="gen.voronoiCellSize">
              </div>
              <input type="number" class="form-control" min="0.01" max="0.3" step="0.01" v-model="gen.voronoiCellSize" :id="'voronoiCellSize'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiWeight1'+gi">Weight feature 1</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="-2.0" max="2.0" step="0.01" v-model="gen.voronoiWeight1" @dblclick="gen.voronoiWeight1 = 0">
              </div>
              <input type="number" class="form-control" min="-2.0" max="2.0" step="0.01" v-model="gen.voronoiWeight1" :id="'voronoiWeight1'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiWeight2'+gi">Weight feature 2</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="-2.0" max="2.0" step="0.01" :id="'voronoiWeight2'+gi" v-model="gen.voronoiWeight2" @dblclick="gen.voronoiWeight2 = 0">
              </div>
              <input type="number" class="form-control" min="-2.0" max="2.0" step="0.01" v-model="gen.voronoiWeight2" :id="'voronoiWeight2'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiWeight3'+gi">Weight feature 3</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="-2.0" max="2.0" step="0.01" :id="'voronoiWeight3'+gi" v-model="gen.voronoiWeight3" @dblclick="gen.voronoiWeight3 = 0">
              </div>
              <input type="number" class="form-control" min="-2.0" max="2.0" step="0.01" v-model="gen.voronoiWeight3" :id="'voronoiWeight3'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiWeight4'+gi">Weight feature 4</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="-2.0" max="2.0" step="0.01" :id="'voronoiWeight4'+gi" v-model="gen.voronoiWeight4" @dblclick="gen.voronoiWeight4 = 0">
              </div>
              <input type="number" class="form-control" min="-2.0" max="2.0" step="0.01" v-model="gen.voronoiWeight4" :id="'voronoiWeight4'+gi">
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'voronoiDistanceType'+gi">Distance type</label>
              <select class="form-select" v-model="gen.voronoiDistanceType" :id="'voronoiDistanceType'+gi">
                <option v-for="(distanceType, i) in distanceTypes" :value="i">{{ distanceType }}</option>
              </select>
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Choose the algorithm to use for distance calculation">
                <i class="bi bi-question"></i>
              </span>
            </div>
          </div>

          <div v-show="gen.type == BLEND" class="settings m-3">
            <p v-if="gi == 0" class="text-warning mb-1">G0 is computed first, so it can't blend anything. Use G1 or later.</p>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'blendA'+gi">Source A</label>
              <select class="form-select" v-model="gen.blendA" :id="'blendA'+gi">
                <option v-for="(n, i) in settings.generators.length" :value="i" :disabled="i >= gi">G{{ i }}</option>
              </select>
              <label class="input-group-text" :for="'blendB'+gi">Source B</label>
              <select class="form-select" v-model="gen.blendB" :id="'blendB'+gi">
                <option v-for="(n, i) in settings.generators.length" :value="i" :disabled="i >= gi">G{{ i }}</option>
              </select>
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Sources must be earlier generators (the final output of each, including its warp). Blends can feed later blends.">
                <i class="bi bi-question"></i>
              </span>
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'blendMode'+gi">Mode</label>
              <select class="form-select" v-model="gen.blendMode" :id="'blendMode'+gi">
                <option v-for="(mode, i) in blendModes" :value="i">{{ mode }}</option>
              </select>
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'blendFactor'+gi">Factor</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="0" max="1" step="0.01" v-model="gen.blendFactor" @dblclick="gen.blendFactor = 0.5">
              </div>
              <input type="number" class="form-control" min="0" max="1" step="0.01" v-model="gen.blendFactor" :id="'blendFactor'+gi">
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Result = mix(A, mode(A, B), factor). With Mix this is a plain crossfade from A to B.">
                <i class="bi bi-question"></i>
              </span>
            </div>
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'blendMask'+gi">Factor mask</label>
              <select class="form-select" v-model="gen.blendMask" :id="'blendMask'+gi">
                <option :value="-1">None (use factor)</option>
                <option v-for="(n, i) in settings.generators.length" :value="i" :disabled="i >= gi">G{{ i }}</option>
              </select>
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Use an earlier generator as a per-pixel factor instead of the slider.">
                <i class="bi bi-question"></i>
              </span>
            </div>
            <p v-if="[gen.blendA, gen.blendB, gen.blendMask].some(s => s >= gi)" class="text-danger mb-0">
              A source at or after G{{ gi }} isn't computed yet and counts as 0.
            </p>
          </div>

          <div v-show="gen.type != BLEND" class="settings m-3">
            <div class="input-group mb-1">
              <label class="input-group-text" :for="'warpSource'+gi">Warp by</label>
              <select class="form-select" v-model="gen.warpSource" :id="'warpSource'+gi">
                <option :value="-1">None</option>
                <option v-for="(n, i) in settings.generators.length" :value="i" :disabled="i == gi || settings.generators[i].type == BLEND">G{{ i }}</option>
              </select>
              <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Offsets the sample position by another generator's noise (domain warp). The source is sampled as its own base noise, so Blend generators and the source's own warp are not used.">
                <i class="bi bi-question"></i>
              </span>
            </div>
            <div v-show="gen.warpSource >= 0" class="input-group mb-1">
              <label class="input-group-text" :for="'warpStrength'+gi">Strength</label>
              <div class="input-group-text">
                <input type="range" class="form-range" min="0" max="2" step="0.01" v-model="gen.warpStrength" @dblclick="gen.warpStrength = 0.25">
              </div>
              <input type="number" class="form-control" min="0" max="2" step="0.01" v-model="gen.warpStrength" :id="'warpStrength'+gi">
            </div>
          </div>

          <div v-show="gen.type != BLEND" class="input-group mb-3">
            <label class="input-group-text" :for="'seamless'+gi">Seamless</label>
            <div class="input-group-text">
              <input class="form-check-input mt-0" type="checkbox" :id="'seamless'+gi" v-model="gen.seamless">
            </div>
            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Makes the image tileable.">
              <i class="bi bi-question"></i>
            </span>
          </div>

          <div v-show="gen.type != BLEND" class="input-group">
            <label class="input-group-text" :for="'seed'+gi">Seed</label>
            <input type="number" class="form-control" v-model="gen.seed" :id="'seed'+gi">
            <button class="btn btn-outline-secondary" type="button" @click="gen.seed = getRandomSeed()"><i class="bi bi-arrow-clockwise"></i></button>
            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Defines the starting point for random number generation, producing different noise patterns.">
              <i class="bi bi-question"></i>
            </span>
          </div>
          </div>
        </div>
        <button class="btn btn-outline-secondary mb-3" type="button" :disabled="settings.generators.length >= MAX_GENERATORS" @click="addGenerator()"><i class="bi bi-plus-lg"></i> Add generator</button>

        <!-- ################  SWIZZLE  ################ -->
        <ul class="nav nav-tabs">
          <li class="nav-item">
            <a class="nav-link disabled" aria-disabled="true">Swizzle</a>
          </li>
          <li class="nav-item dropdown">
            <button class="nav-link dropdown-toggle" data-toggle="dropdown" data-bs-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="true">Presets</button>
            <ul class="dropdown-menu">
              <li><span class="dropdown-item disabled" href="#">Choose a preset</span></li>
              <li><hr class="dropdown-divider"></li>
              <li><a v-for="(channelPreset, i) in channelsPresets" class="dropdown-item" role="button" @click="onPresetSelection(i)">{{ i }}</a></li>
            </ul>
          </li>
          <li class="nav-item">
            <a class="nav-link channel-nav" :class="{'active': settings.activeChannel == 0}" role="button" data-channel=0 @click="settings.activeChannel = 0">R</a>
          </li>
          <li class="nav-item">
            <a class="nav-link channel-nav" :class="{'active': settings.activeChannel == 1}" role="button" data-channel=1 @click="settings.activeChannel = 1">G</a>
          </li>
          <li class="nav-item">
            <a class="nav-link channel-nav" :class="{'active': settings.activeChannel == 2}" role="button" data-channel=2 @click="settings.activeChannel = 2">B</a>
          </li>
          <li class="nav-item">
            <a class="nav-link channel-nav" :class="{'active': settings.activeChannel == 3}" role="button" data-channel=3 @click="settings.activeChannel = 3">A</a>
          </li>
        </ul>

        <div class="col border-start border-end border-bottom p-3 mb-3">
          <div class="input-group mb-3">
            <label class="input-group-text" for="sourceGenerator">Source generator</label>
            <select class="form-select" v-model="activeChannel.generator" id="sourceGenerator">
              <option v-for="(n, i) in settings.generators.length" :value="i">G{{ i }}</option>
            </select>
            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Choose the source for this channel of the image">
              <i class="bi bi-question"></i>
            </span>
          </div>

          <div class="input-group mb-3">
            <label class="input-group-text" for="sourceType">Value type</label>
            <select class="form-select" v-model="activeChannel.type" id="sourceType">
              <option v-for="(sourceType, i) in sourceTypes" :value="i">{{ sourceType }}</option>
            </select>
            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Choose the type of value to use for this channel">
              <i class="bi bi-question"></i>
            </span>
          </div>

          <div class="input-group mb-3">
            <div class="input-group-text">
              <input type="range" class="form-range" :style="{width: '40px'}" min="0.0" max="2.0" step="0.01" id="gain" v-model="activeChannel.gain" @dblclick="activeChannel.gain = 1.0">
            </div>
            <label class="input-group-text" for="gain">{{ activeChannel.gain }}</label>

            <div class="input-group-text">
              <input type="range" class="form-range" :style="{width: '40px'}" min="0.0" max="2.0" step="0.01" id="gamma" v-model="activeChannel.gamma" @dblclick="activeChannel.gamma = 1.0">
            </div>
            <label class="input-group-text" for="gamma">{{ activeChannel.gamma }}</label>

            <div class="input-group-text">
              <input type="range" class="form-range" :style="{width: '40px'}" min="-1.0" max="1.0" step="0.01" id="offset" v-model="activeChannel.offset" @dblclick="activeChannel.offset = 0.0">
            </div>
            <label class="input-group-text" for="offset">{{ activeChannel.offset }}</label>

            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Adjusts the gain, gamma curve and offset values">
              <i class="bi bi-question"></i>
            </span>
          </div>

          <div class="input-group mb-3">
            <label class="input-group-text" for="invert">Invert</label>
            <div class="input-group-text">
              <input class="form-check-input mt-0" type="checkbox" id="invert" v-model="activeChannel.invert">
            </div>
            <span class="input-group-text" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Inverts the range of the values (1.0 - x).">
              <i class="bi bi-question"></i>
            </span>
          </div>
        </div>
      </div>
      <div class="row m-5">
        <p class="text-secondary">
          Report bugs or request features on the <a href="https://github.com/simenstroek/NoiseGenerator/issues" target="_blank">Github project page</a>.
          Original tool by <a href="https://bubblebirdstudio.com/" target="_blank">Bubblebird Studio</a>.
        </p>
      </div>
    </div>
  </div>

  <!-- save as modal -->
  <div class="modal fade" id="saveBackdrop" data-bs-keyboard="false" tabindex="-1" aria-labelledby="saveBackdropLabel" aria-hidden="true">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h1 class="modal-title fs-5" id="saveBackdropLabel"><i class="bi bi-floppy"></i> Save your settings</h1>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label for="recipient-name" class="col-form-label">Choose a name for these settings:</label>
            <input type="text" class="form-control mb-2" v-model="settings.name">
            <p class="text-warning">
              <i class="bi bi-info-circle"></i> Settings are saved in your browser only (localStorage). 
              If you clear the cache or data for this domain, you will lose them.
            </p>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
          <button type="button" class="btn btn-primary" data-bs-dismiss="modal" @click="saveSettings()">Save</button>
        </div>
      </div>
    </div>
  </div>

  <!-- load modal -->
  <div class="modal fade" id="loadBackdrop" data-bs-keyboard="false" tabindex="-1" aria-labelledby="loadBackdropLabel" aria-hidden="true">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h1 class="modal-title fs-5" id="loadBackdropLabel"><i class="bi bi-floppy"></i> Load settings</h1>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label for="recipient-name" class="col-form-label">Choose a setting to load:</label>
            <div class="list-group">
              <div v-for="setting in settingsCollection" class="btn-group mt-3 d-flex" role="group">
                <button type="button" class="btn btn-secondary flex-grow-1" @click.stop="loadSetting(setting)">{{ setting.name }}</button>
                <button type="button" class="btn btn-danger flex-grow-0" @click.stop="removeSetting(setting)"><i class="bi bi-trash3"></i></button>
              </div>
              <div v-if="Object.keys(settingsCollection).length == 0"><p class="text-info"><i class="bi bi-info-circle"></i> No settings saved on this browser.</p></div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, useTemplateRef, reactive , onMounted, watch, nextTick } from "vue";
import { getRandomSeed, createBuffer, createPipeline } from "./utils.ts";
import utilsShader from "./utils.wgsl?raw" with { type: "text" };
import computeShader from "./computeShader.wgsl?raw" with { type: "text" };
import compositingShader from "./compositingShader.wgsl?raw" with { type: "text" };

let initialized = false;
let device: any;
let context: any;
let format: any;
let computeModule: any;
let compositingModule: any;
let settingsBuffer: any;
let renderBuffer: any;
let noiseBuffer: any;
let outputBuffer: any;
let computePipeline: any;
let compositingPipeline: any;
let computeBindGroup: any;
let compositingBindGroup: any;

const noiseTypes = ["Random", "Perlin", "Voronoi", "Blend"];
const BLEND = noiseTypes.indexOf("Blend");
const MAX_GENERATORS = 8; // matches array<Generator, 8> in utils.wgsl; the noise buffer holds every generator per voxel
let nextUid = 0;
const openGenerator = ref(0); // accordion: index of the expanded generator card, -1 = all collapsed
const blendModes = ["Mix", "Add", "Multiply", "Screen", "Difference", "Min", "Max", "Overlay"];
const distanceTypes = ["Euclidean", "Squared", "Manhattan", "Chebyshev"];
const sourceTypes = ["Value", "Normal X", "Normal Y", "0", "1"];
const channelsData = [];
const generating = ref(false);
const renderType = ref(0);
const lightPositionX = ref(0.5);
const lightPositionY = ref(0.5);
const error = ref("");
const canvas = useTemplateRef("canvas");
const initialSeed = getRandomSeed();

const defaultGeneratorSettings = {
  type: 2,
  seamless: true,
  seed: initialSeed,
  perlinSize: 0.2,
  perlinOctaves: 1,
  perlinLacunarity: 2.0,
  voronoiCellSize: 0.2,
  voronoiWeight1: 1.0,
  voronoiWeight2: 0.0,
  voronoiWeight3: 0.0,
  voronoiWeight4: 0.0,
  voronoiDistanceType: 0,
  blueNoiseRadius: 1.5,
  warpSource: -1,     // generator whose noise offsets this one's position (-1 = none)
  warpStrength: 0.25,
  blendA: 0,          // blend sources must be earlier generators (G0 is computed first)
  blendB: 1,
  blendMode: 0,
  blendFactor: 0.5,
  blendMask: -1       // generator used as per-pixel blend factor (-1 = use blendFactor)
}

const channelsPresets = {
    "Default": [
      { display: true, generator: 0, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G0 -> R, G1 -> G, G2 -> B, G3 -> A": [
      { display: true, generator: 0, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 1, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 2, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 3, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G0 to Normal map (OpenGL)": [
      { display: true, generator: 0, type: 1, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 2, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G0 to Normal map (DirectX)": [
      { display: true, generator: 0, type: 1, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 2, invert: true , gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G0 to red channel": [
      { display: true, generator: 0, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G1 to green channel": [
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 1, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
    "G2 to blue channel": [
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 3, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 2, type: 0, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
      { display: true, generator: 0, type: 4, invert: false, gain: 1.0, gamma: 1.0, offset: 0.0 },
    ],
}

const defaultSettings = {
  name: "Noise",
  resolution: 256,
  dimension: "2d",
  layout: "auto",
  previewGenerator: -1, // generator shown raw in the canvas, -1 = channel output
  generators: [{ ...defaultGeneratorSettings, uid: 0 }],
  activeChannel: 0,
  channels: channelsPresets["Default"],
  normalScale: 1.0,
}

const settings = reactive(JSON.parse(JSON.stringify(defaultSettings)));
const is3d = computed(() => settings.dimension === "3d" && settings.resolution < 512)
const litGenerator = computed(() => settings.previewGenerator >= 0 ? settings.previewGenerator : settings.channels[0].generator)
const activeChannel = computed(() => settings.channels[settings.activeChannel])
const canvasWidth = computed(() => settings.resolution * xTiles.value)
const canvasHeight = computed(() => settings.resolution * yTiles.value)
const settingsCollection = reactive(JSON.parse(localStorage.getItem("settingsCollection") || "{}"));

const xTiles = computed(() => {
  const sqr = Math.sqrt(settings.resolution);
  if (!is3d.value) return 1;
  if (settings.layout === "auto") return Number.isInteger(sqr) ? Math.ceil(sqr) : 1;
  if (settings.layout === "square") return Math.ceil(sqr);
  if (settings.layout === "horizontal") return settings.resolution;
  if (settings.layout === "vertical") return 1;
  return 1;
})

const yTiles = computed(() => {
  const sqr = Math.sqrt(settings.resolution);
  if (!is3d.value) return 1;
  if (settings.layout === "auto") return Number.isInteger(sqr) ? Math.ceil(sqr) : settings.resolution;
  if (settings.layout === "square") return Math.ceil(sqr);
  if (settings.layout === "horizontal") return 1;
  if (settings.layout === "vertical") return settings.resolution;
  return 1;
})

watch(() => settings.dimension, (newValue, oldValue) => {
  setupRenderPipeline();
  generateNoise();
})

watch(() => settings.layout, (newValue, oldValue) => {
  setupRenderPipeline();
  generateNoise()
})

watch(() => settings.resolution, (newValue, oldValue) => {
  setupRenderPipeline();
  generateNoise()
})

watch(() => settings.generators.length, () => {
  setupRenderPipeline(); // the noise buffer is sized by generator count; must run before the settings watcher below
})

watch(settings, (newValue, oldValue) => {
  generateNoise();
})

onMounted(async () => {
  initTooltips();
  try {
    const adapter = await navigator.gpu.requestAdapter();
    device = await adapter.requestDevice({
      requiredLimits: {
        maxBufferSize: 2147483644,
        maxStorageBufferBindingSize: 2147483644,
        maxTextureDimension2D: 16384,
        maxComputeInvocationsPerWorkgroup: 1024
      }
    });
    context = canvas.value?.getContext("webgpu");
    if (!context) throw new Error("Can't get the webgpu context");
    format = navigator.gpu.getPreferredCanvasFormat();
    computeModule = device.createShaderModule({ code: utilsShader + computeShader }),
    compositingModule = device.createShaderModule({ code: utilsShader + compositingShader });
    context.configure({ device, format, alphaMode: "opaque" });
    initialized = true;
    setupRenderPipeline();
    generateNoise();
  } catch(e) {
    error.value = `Your browser doesn't support webGPU! error: ${e.message}`;
    console.error(e);
    initialized = false;
  }
  requestAnimationFrame(renderLoop);
})


// Layout must match struct Settings in utils.wgsl: 8 header floats, 4 x 7 channel floats, 8 x 20 generator floats.
function GetSettingsBufferData(generator: number) {
  const g = (i: number) => {
    const o = settings.generators[i];
    return [
      o.type, o.perlinSize, o.perlinOctaves, o.perlinLacunarity, o.voronoiCellSize,
      o.voronoiWeight1, o.voronoiWeight2, o.voronoiWeight3, o.voronoiWeight4, o.voronoiDistanceType,
      o.seamless ? 1 : 0, o.seed,
      o.warpSource, o.warpStrength, o.blendA, o.blendB, o.blendMode, o.blendFactor, o.blendMask, 0,
    ];
  };
  return new Float32Array([
    generator, settings.resolution, settings.resolution, is3d.value ? settings.resolution : 1,
    xTiles.value, yTiles.value, settings.generators.length, 0,
    ...settings.channels.flatMap((c: any) => [+c.display, c.generator, c.type, c.invert ? 1 : 0, c.gain, c.gamma, c.offset]),
    ...Array.from({ length: MAX_GENERATORS }, (_, i) => i < settings.generators.length ? g(i) : new Array(20).fill(0)).flat(),
  ]);
}

function GetRenderBufferData() {
  return new Float32Array([
    renderType.value,
    lightPositionX.value,
    lightPositionY.value,
    litGenerator.value,
    settings.previewGenerator,
    0, 0, 0,
  ]);
}


function setupRenderPipeline() {
  if (initialized == false) return;
  const resolutionX = settings.resolution;
  const resolutionY = settings.resolution;
  const resolutionZ = is3d.value ? settings.resolution : 1;

  canvas.value.width = canvasWidth.value;
  canvas.value.height = canvasHeight.value;

  settingsBuffer = device.createBuffer({
    size: GetSettingsBufferData(0).byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  renderBuffer = device.createBuffer({
    size: GetRenderBufferData().byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  noiseBuffer = device.createBuffer({
    size: resolutionX * resolutionY * resolutionZ * settings.generators.length * 4,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
  });

  outputBuffer = device.createBuffer({
    size: canvasWidth.value * canvasHeight.value * 4 * 4,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
  });

  const bindGroupLayout = device.createBindGroupLayout({
    entries: [
      { binding: 0, visibility: GPUShaderStage.COMPUTE | GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' }, },
      { binding: 1, visibility: GPUShaderStage.COMPUTE | GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' }, },
      { binding: 2, visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT, buffer: { type: 'storage' }, },
      { binding: 3, visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT, buffer: { type: 'storage' }, },
    ],
  });

  const pipelineLayout = device.createPipelineLayout({
    bindGroupLayouts: [bindGroupLayout]
  });

  computePipeline = device.createComputePipeline({
    label: 'ComputePipeline',
    layout: pipelineLayout,
    compute: {
      module: computeModule,
      entryPoint: 'main'
    }
  });

  compositingPipeline = device.createRenderPipeline({
    label: 'CompositingPipeline',
    layout: pipelineLayout,
    vertex: {
      module: compositingModule,
      entryPoint: "vertex"
    },
    fragment: {
      module: compositingModule,
      entryPoint: "fragment",
      targets: [{ format }]
    },
    primitive: {
      topology: 'triangle-list'
    }
  });

  computeBindGroup = device.createBindGroup({
    layout: computePipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: settingsBuffer } },
      { binding: 1, resource: { buffer: renderBuffer } },
      { binding: 2, resource: { buffer: noiseBuffer } },
      { binding: 3, resource: { buffer: outputBuffer } },
    ]
  });

  compositingBindGroup = device.createBindGroup({
    layout: compositingPipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: settingsBuffer } },
      { binding: 1, resource: { buffer: renderBuffer } },
      { binding: 2, resource: { buffer: noiseBuffer } },
      { binding: 3, resource: { buffer: outputBuffer } },
    ]
  });
}


function generateNoise() {
  if (initialized == false) return;
  const resolutionX = settings.resolution;
  const resolutionY = settings.resolution;
  const resolutionZ = is3d.value ? settings.resolution : 1;
  const dispatchX = Math.ceil(resolutionX  / 8);
  const dispatchY = Math.ceil(resolutionY / 8);
  const dispatchZ = Math.ceil(resolutionZ  / 8);

  for (let c = 0; c < settings.generators.length; c++) {
    device.queue.writeBuffer(settingsBuffer, 0, GetSettingsBufferData(c));
    const commandEncoder = device.createCommandEncoder();
    const computePass = commandEncoder.beginComputePass();
    computePass.setPipeline(computePipeline);
    computePass.setBindGroup(0, computeBindGroup);
    computePass.dispatchWorkgroups(dispatchX, dispatchY, dispatchZ);
    computePass.end();
    device.queue.submit([commandEncoder.finish()]);
  }
}


function renderLoop() {
  render();
  requestAnimationFrame(renderLoop);
}


function render() {
  const commandEncoder = device.createCommandEncoder();
  const compositingPass = commandEncoder.beginRenderPass({
    colorAttachments: [{
      view: context.getCurrentTexture().createView(),
      clearValue: { r: 0, g: 0, b: 0, a: 1 },
      loadOp: 'load',
      storeOp: 'store',
    }]
  });
  compositingPass.setPipeline(compositingPipeline);
  compositingPass.setBindGroup(0, compositingBindGroup);
  compositingPass.draw(6);
  compositingPass.end();

  device.queue.writeBuffer(renderBuffer, 0, GetRenderBufferData());
  device.queue.submit([commandEncoder.finish()]);
}


function initTooltips() {
  // doesn't work on hidden panels: use v-show instead of v-if
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => bootstrap.Tooltip.getOrCreateInstance(el));
}


function addGenerator() {
  if (settings.generators.length >= MAX_GENERATORS) return;
  settings.generators.push({ ...defaultGeneratorSettings, seed: getRandomSeed(), uid: ++nextUid });
  openGenerator.value = settings.generators.length - 1;
  nextTick(initTooltips);
}


// Generators only reference earlier ones, so removing one re-points or clears every reference to it.
function removeGenerator(k: number) {
  if (settings.generators.length <= 1) return;
  const shift = (v: number, fallback: number) => v === k ? fallback : v > k ? v - 1 : v;
  settings.generators.splice(k, 1);
  for (const g of settings.generators) {
    g.warpSource = shift(g.warpSource, -1);
    g.blendMask = shift(g.blendMask, -1);
    g.blendA = shift(g.blendA, 0);
    g.blendB = shift(g.blendB, 0);
  }
  for (const c of settings.channels) c.generator = shift(c.generator, 0);
  settings.previewGenerator = shift(settings.previewGenerator, -1);
  openGenerator.value = Math.min(shift(openGenerator.value, 0), settings.generators.length - 1);
}


function onPresetSelection(channelPresetName) {
  settings.channels = structuredClone(channelsPresets[channelPresetName]);
}


function handleMouseMove(event) {
  const rect = canvas.value.getBoundingClientRect()
  const x = (event.clientX - rect.left) / rect.width;
  const y = (event.clientY - rect.top) / rect.height;

  lightPositionX.value = -(x * 2 - 1)
  lightPositionY.value = -(y * 2 - 1);
}


async function getImageData() {
  const resultBuffer = device.createBuffer({
    size: canvasWidth.value * canvasHeight.value * 4 * 4,
    usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
  });
  const encoder = device.createCommandEncoder();
  encoder.copyBufferToBuffer(outputBuffer, 0, resultBuffer, 0, canvasWidth.value * canvasHeight.value * 4 * 4);
  device.queue.submit([encoder.finish()]);

  await resultBuffer.mapAsync(GPUMapMode.READ);
  const floatArray = new Float32Array(resultBuffer.getMappedRange().slice());
  resultBuffer.unmap();
  resultBuffer.destroy();

  const clampedArray = new Uint8ClampedArray(canvasWidth.value * canvasHeight.value * 4);

  for (let i = 0; i < clampedArray.length; i++) {
    const val = floatArray[i];
    clampedArray[i] = Math.max(0, Math.min(255, val <= 1 ? val * 255 : val));
  }

  return new ImageData(clampedArray, canvasWidth.value, canvasHeight.value);
}


async function exportImage() {
  generating.value = true;
  try {
    const imageData = await getImageData();
    const canvas = document.createElement("canvas");
    canvas.width = canvasWidth.value;
    canvas.height = canvasHeight.value;
    canvas.getContext("2d").putImageData(imageData, 0, 0);

    const link = document.createElement("a");
    link.download = `${settings.name}.png`;
    link.href = canvas.toDataURL("image/png") || "";
    link.click();

    link.remove();
    canvas.remove();
  } catch (err) {
    alert("Failed to export image: " + err);
  }
  generating.value = false;
}

async function copyImageToClipboard() {
  generating.value = true;
  try {
    const imageData = await getImageData();
    const canvas = document.createElement("canvas");
    canvas.width = canvasWidth.value;
    canvas.height = canvasHeight.value;
    canvas.getContext("2d").putImageData(imageData, 0, 0);

    const blob = await new Promise(resolve => canvas.toBlob(resolve));
    const item = new ClipboardItem({ 'image/png': blob as Blob });
    await navigator.clipboard.write([item]);
    alert("Image copied to clipboard!");
  } catch (err) {
    alert("Failed to copy: " + err);
  }
  generating.value = false;
}


async function loadSetting(loadedSettings: any) {
  Object.assign(settings, loadedSettings, {
    // fill in fields older saves predate, and give every card a fresh key
    generators: loadedSettings.generators.map((g: any) => ({ ...defaultGeneratorSettings, ...g, uid: ++nextUid })),
    previewGenerator: -1,
  });
  openGenerator.value = 0;
  nextTick(initTooltips);
}


function removeSetting(setting: any) {
  if (confirm(`Really delete setting ${setting.name}`)) {
    delete settingsCollection[setting.name];
    localStorage.setItem("settingsCollection", JSON.stringify(settingsCollection));
  }
}


function saveSettings() {
  try {
    settingsCollection[settings.name] = JSON.parse(JSON.stringify(settings));
    localStorage.setItem("settingsCollection", JSON.stringify(settingsCollection));
  } catch(e) {
    fixSettingsCollection();
  }
}


function fixSettingsCollection() {
  alert("Your settings collection was corrupted. They were cleared to fix the issue.")
  localStorage.setItem("settingsCollection", "{}");
}
</script>

<style lang="scss">
@use './style.css';
</style>
