# Racket Calculations on a Metal

This repo shows how to call Metal kernels from Racket.  
It's a learning playground, you won't find here any high-level stuff.  

## Overview

I written 4 simple kernels:
- add_arrays
- mult_arrays
- add_matrices
- matmul

There are no optimizations, really, just simple functions.  

I tried to extract the minimum that is required to run kernel computations from Racket.  
The most important pieces are:  

#### Devices and Library

Metal requires the Buffers to be associated with device and library.  
Below structure keeps the reference, it's used with pretty much every command.  

**_metal-config**  
A struct that holds device and library.  
Almost all other functions take metal-config as an argument.  

#### Vectors

**_metal_vector**
A struct that contains Metal Buffer pointer as well as other informations about the metal vector.  
See source code and take a look at *[metal-ffi.rkt](./metal-ffi.rkt)* (or [MetalAdder.m](./MetalComputeBasic/MetalAdder.m)) to see how it's defined.  

**list->mvector | mvector->list**  
Transition lists similar to those you might know from racket (i.e. list->vector). But they additionally take metal-config as first argument and they require the list to be a flat list.  
It's the first building block for the communication with Metal, it allocates Metal Buffer with shape of the list.  

**compute-add | compute-mul**
Vector operations. They take 2 *metal_vector*'s and return a new one.  
You can see in [examples.rkt](./examples.rkt) how to use them.


#### Matrices

**_metal_matrix**
A struct that contains Metal Buffer pointer as well as other informations about the metal matrix.  
See source code and take a look at *[metal-ffi.rkt](./metal-ffi.rkt)* (or [MetalAdder.m](./MetalComputeBasic/MetalAdder.m)) to see how it's defined.  
It's pretty much the same as *_metal_vector*, but it also contains information about number of rows and columns.  

**list->mmatix | mmatrix->list**  
Just like *list->mvector* and *mvector->list*, but with matrix in mind.  
It requires the list to be 2D of course.  

**compute-mat-add | compute-mat-mul**
Matrix operations. They take 2 *metal_matrix*'s and return a new one.  
You can see in [examples.rkt](./examples.rkt) how to use them.


## Run examples

```
racket examples.rkt
```


## Build

Build *dylib* and *metallib*
```
xcodebuild -project MetalComputeBasic.xcodeproj -scheme MetalComputeBasic -configuration Debug
```

It will build the two files under *Build/Products/Debug/*:
- *default.metallib*
- *libMetalComputeBasic* (dylib)

## Racket FFI

Those are the main ffi bindings to my functions. Together with dylib and metallib mentioned above, they are all that is needed to create simple vectors/matrices and make really basic operations.  
```
racket ./metal-ffi.rkt
```


## Tests

```
raco test test.rkt
```


## Benchmarks

Those are not very rigorous. The kernels are not optimized, but just to see how does it compare to CPU-optimized operations, here it is.
To run execute that:

```
racket -l racket/base -e '(require (submod "benchmark.rkt" benchmark))'
```

Some example results for [1e5, 1e3]x[1e3, 1]:

>       Flomat: 195.611083984375
>       Vector: 181.384033203125
>       Metal:   30.556884765625

>       Flomat: 179.22509765625
>       Vector: 167.153076171875
>       Metal:   52.55712890625

>       Flomat: 173.863037109375
>       Vector: 168.3330078125
>       Metal:   27.2109375

Some example results for [1e3, 1e5]x[1e5, 1]:
>       Flomat: 322.506103515625
>       Vector: 331.7861328125
>       Metal:   40.25390625

>       Flomat: 326.198974609375
>       Vector: 329.2919921875
>       Metal:   44.015869140625

>       Flomat: 297.712890625
>       Vector: 245.10302734375
>       Metal:   35.764892578125

One might expect that to be orders of magnitude better.  
They hugely depend on what are the exact operations and dimensions.  
I suspect it's because my kernels aren't optimized at all. I just use a really simple one for multiplication.  
I'm gonna have to read more about the specifics of the metal language at some point, but it's really to get a grasp of what it's all about.  
