# godot-voip-opus-demo
A very simple demo showing how to implement voip with libOpus compression, for Godot 4.1+.

Looking for the Godot 3.x version? It lives on the [`godot3` branch](../../tree/godot3).

The base of this project was copied from:
https://github.com/cbarsugman/godot-voip-demo

## Opus Compression
Probably the biggest problem preventing VOIP from being implemented in Godot is the issue of compression.

In the original VOIP demo by cbarsugam, recorded audio is transmitted as raw PCM data. This is the type of data inside of a `.wav` file. It is loseless raw audio samples, and it is huge. Far too large for a real game to transmit over the internet between players.

What this project does, is it uses the [Godot-Opus wrapper](https://github.com/Wavesonics/libopus-gdnative) to compress the data before transmission, and on the receiving side decompress the data before playback. The wrapper is a GDExtension, so `OpusEncoderNode` and `OpusDecoderNode` are real node types available directly in the scene tree.

The compressed data is often more than 100 times smaller than the raw PCM data making this feasible for a real project.

## What this is not: Streaming audio
This is a very simple form of VOIP. Press a button to record an audio sample. Only when the recording is completed is it compressed as a whole and sent to the remote clients. Then on the receiving end it is decompressed as a whole, and played back.

So this is very clearly not real-time voice chat. libOpus is specifically designed however to accomidate real-time voice chat and has many advanced features to facilitate it, which we are not using here.

Godot 4 now provides the pieces needed for true streaming: `AudioEffectCapture` for pulling live mic frames and `AudioStreamGenerator` for playing back a live stream. Wiring those to Opus's streaming features is future work.
