# godot-voip-opus-demo
A very simple demo showing how to implement voip with libOpus compression, for Godot 4.1+.

Looking for the Godot 3.x version? It lives on the [`godot3` branch](../../tree/godot3).

The base of this project was copied from:
https://github.com/cbarsugman/godot-voip-demo

## Opus Compression
Probably the biggest problem preventing VOIP from being implemented in Godot is the issue of compression.

In the original VOIP demo by cbarsugam, recorded audio is transmitted as raw PCM data. This is the type of data inside of a `.wav` file. It is loseless raw audio samples, and it is huge. Far too large for a real game to transmit over the internet between players.

What this project does, is it uses the [Godot-Opus wrapper](https://github.com/Godot-Opus/libopus-gdnative) to compress the data before transmission, and on the receiving side decompress the data before playback. The wrapper is a GDExtension, so `OpusEncoderNode` and `OpusDecoderNode` are real node types available directly in the scene tree.

The compressed data is often more than 100 times smaller than the raw PCM data making this feasible for a real project.

## Two modes: whole-clip and streaming

The **Streaming** toggle in the UI switches between two transmission modes.

### Whole-clip (toggle off)
The original, very simple form of VOIP. Press a button to record an audio sample. Only when the recording is completed is it compressed as a whole and sent to the remote clients. Then on the receiving end it is decompressed as a whole, and played back. Latency is at least the length of the recording chunk (1 second here).

### Streaming (toggle on)
True live push-to-talk. While Speak is held, mic audio is pulled continuously from an `AudioEffectCapture` on the Record bus, fed to `OpusEncoderNode.push_audio()`, and every 20ms Opus packet is sent over an unreliable RPC as soon as it is ready. The receiver decodes each packet with `OpusDecoderNode.decode_frame()` and pushes the frames straight into an `AudioStreamGenerator`, so playback starts within tens of milliseconds.

This mode requires a 48kHz mix rate, since Opus does not accept Godot's default 44.1kHz; `project.godot` sets `audio/driver/mix_rate=48000`.

Left as an exercise: the demo shares a single output player and decoder for all remote peers, so two people talking at once will interleave into one stream. A real game would create one `AudioStreamPlayer` + `OpusDecoderNode` per remote peer, keyed by the sender id already passed in the RPC. Lost packets could also be concealed by tracking sequence numbers and calling `OpusDecoderNode.decode_dropped()` for each gap.

## Testing between two computers

1. Run the demo on both machines (both on the same LAN, or otherwise reachable).
2. On machine A, click **Start server**. The log prints the LAN address(es) clients can connect to.
3. On machine B, type machine A's address into the IP field and click **Start client**.
4. Toggle **Streaming** on both, hold **Speak**, and talk.

The connection uses UDP port 3000, so make sure the server machine's firewall allows it. Leaving the IP field blank connects to `127.0.0.1`, which keeps the old same-machine two-instance workflow working.

The project ships Linux and Windows export presets that build a self-contained binary (embedded pck) into `export/<platform>/`; only the platform's Opus library ships alongside it.

## Using this as a Push to Talk recipe for your game

The streaming path is intentionally small so it can be lifted into a real project. The pieces you need:

**Project settings** (`project.godot`):
- `audio/driver/enable_input=true`
- `audio/driver/mix_rate=48000` (Opus requires it; Godot's default 44.1kHz will not work)

**Scene / bus setup**:
- An audio bus (here named `Record`) that is muted, with an `AudioEffectCapture` on it (`default_bus_layout.tres`)
- An `AudioStreamPlayer` playing an `AudioStreamMicrophone` into that bus, `autoplay` on (`Input` node in `Control.tscn`)
- An `OpusEncoderNode` and `OpusDecoderNode` anywhere in the scene tree
- Per remote speaker: an `AudioStreamPlayer` whose stream is an `AudioStreamGenerator` with `mix_rate = 48000` and a small `buffer_length` (0.1s here; smaller = lower latency, larger = more resilient to jitter)

**Sender**, every `_process` while the PTT key is held (see `_process_streaming` in `voip.gd`):
```gdscript
encoder.push_audio(capture.get_buffer(capture.get_frames_available()))
while encoder.has_packet():
	_stream_packet.rpc(multiplayer.get_unique_id(), encoder.pop_packet())
```
On the frame the key is first pressed, discard stale audio: `capture.clear_buffer()` and `encoder.reset_stream()`.

**Receiver**, in the unreliable RPC handler (see `_stream_packet` in `voip.gd`):
```gdscript
var frames = decoder.decode_frame(packet)
if not player.playing:
	player.play()
var playback = player.get_stream_playback()
if playback.can_push_buffer(frames.size()):
	playback.push_buffer(frames)
```
When no packet has arrived for a short while (0.5s here), stop the player and call `decoder.reset_stream()` so the next burst starts from clean codec state.
