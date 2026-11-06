# Online Noise Generation Tool

This is a simple & free online noise texture generation tool. It allows you to easily create 2D or 3D seamless noise patterns for your projects and export them as png files.

It currently support the following noise models:
- [Random (Jenkins algorithm)](https://en.wikipedia.org/wiki/Jenkins_hash_function)
- [Perlin](https://en.wikipedia.org/wiki/Perlin_noise)
- [Voronoi/Worley](https://en.wikipedia.org/wiki/Worley_noise)

Support for Blue Noise is planned.

You can freely use it here: https://noisegen.bubblebirdstudio.com/

See it in action:

https://github.com/user-attachments/assets/53a38b09-0198-4a67-97d2-aa8bbc5d4874

This project uses [Deno](https://deno.com/).

## Dev

Start the dev server, use this command:
> Deno run dev

## Build

...and to build for production & serve the files on localhost:8080, this one:
> Deno run build

## License

The code is published under the MIT License.

## Support

This free-to-use noise generator is developed and maintained by [Bubblebird Studio](https://bubblebirdstudio.com/). You can support the development by buying our games!

## Blend & warp (fork additions)

Generators run in order G0..G3 into one buffer, so:
- **Blend** (generator type): mixes two *earlier* generators (A, B) with a mode (Mix, Add, Multiply, Screen, Difference, Min, Max, Overlay) and a factor, or a per-pixel factor taken from another earlier generator (mask). Blends can feed later blends.
- **Warp by** (any noise type): offsets the sample position by another generator's noise (3 decorrelated samples → XYZ offset), so it works in 2D and 3D and stays seamless if both are seamless. The warp source is evaluated as its own base noise: Blend generators can't be warp sources and the source's own warp isn't applied.

Run with `npm install && npm run dev` (Deno tasks still work too).
