# Examples

These are runnable SwiftPM executables. Each can be executed with `swift run` from the repo root.

The default input file is:
`Examples/file_example_MP4_1280_10MG.mp4`

## Build once

```bash
swift build
```

## 1) Inspect streams and duration

```bash
swift run example-inspect [input-path]
```

## 2) Decode video frames

```bash
swift run example-decode [input-path] [max-frames]
```

## 3) Filter frames (scale + hflip)

```bash
swift run example-filter [input-path] [max-frames]
```

## 4) Encode a short clip (H.264)

```bash
swift run example-encode [input-path] [output-path] [max-frames]
```

## 5) Remux AAC audio to ADTS

```bash
swift run example-adts [input-path] [output-path]
```

## 6) Encode MP3 audio

```bash
swift run example-mp3 [input-path] [output-path] [max-frames]
```

Notes:
- The encode example assumes the H.264 encoder accepts the input pixel format. If it fails, you may need to add a conversion step.
- Output defaults to `Examples/output.mp4`.
- The ADTS example requires the input audio codec to be AAC.
- Output defaults to `Examples/output.adts`.
- Output defaults to `Examples/output.mp3`.
- The MP3 example requires an FFmpeg build with an MP3 encoder (for example libmp3lame).
