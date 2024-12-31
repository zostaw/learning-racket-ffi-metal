# Performing Calculations on a GPU

Bindings for Metal

## Build

Build *dylib* and *metallib*
```
xcodebuild -project MetalComputeBasic.xcodeproj -scheme MetalComputeBasic -configuration Debug
```

It will build the two files under *Build/Products/Debug/*:
- *default.metallib*
- *libMetalComputeBasic* (dylib)

## Run

```
racket ./main.rkt
```

