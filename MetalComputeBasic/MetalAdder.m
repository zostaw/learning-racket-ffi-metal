/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to manage all of the Metal objects this app creates.
*/

#import "MetalAdder.h"

// The number of floats in each array, and the size of the arrays in bytes.
const unsigned int arrayLength = 1 << 24;
const unsigned int bufferSize = arrayLength * sizeof(float);





enum metal_data_type {
    METAL_FLOAT,
    METAL_INT32,
};

struct metal_vector {
              id<MTLBuffer> buffer_ptr;
              size_t buffer_len;
              enum metal_data_type data_type;
              id<MTLDevice> device;
};


void encodeAddCommand(id<MTLComputeCommandEncoder> computeEncoder,
                      id<MTLComputePipelineState> pipelineState,
                      id<MTLBuffer> bufferA,
                      id<MTLBuffer> bufferB,
                      id<MTLBuffer> bufferResult) {

    // Encode the pipeline state object and its parameters.
    [computeEncoder setComputePipelineState:pipelineState];
    [computeEncoder setBuffer:bufferA offset:0 atIndex:0];
    [computeEncoder setBuffer:bufferB offset:0 atIndex:1];
    [computeEncoder setBuffer:bufferResult offset:0 atIndex:2];

    MTLSize gridSize = MTLSizeMake(arrayLength, 1, 1);

    // Calculate a threadgroup size.
    NSUInteger threadGroupSize = pipelineState.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > arrayLength)
    {
        threadGroupSize = arrayLength;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    // Encode the compute command.
    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
}

__attribute__((visibility("default")))
bool computeAddObsolete(void* device, void*library, void* bufferA, void* bufferB, void* bufferResult) {

    NSError* error = nil;

    id<MTLDevice>  _mDevice       = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> _mLibrary      = (__bridge id<MTLLibrary>)library;
    id<MTLBuffer>  _mBufferA      = (__bridge id<MTLBuffer>)bufferA;
    id<MTLBuffer>  _mBufferB      = (__bridge id<MTLBuffer>)bufferB;
    id<MTLBuffer>  _mBufferResult = (__bridge id<MTLBuffer>)bufferResult;
    // id<MTLBuffer>  _mBufferResult = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    // Validate casted objects
    if (!_mDevice || !_mLibrary || !_mBufferA || !_mBufferB || !_mBufferResult) {
        NSLog(@"Error: One or more Metal objects are invalid.");
        return false;
    }



    
    id<MTLFunction> addFunction = [_mLibrary newFunctionWithName:@"add_arrays"];
    if (addFunction == nil)
    {
        NSLog(@"Failed to find the adder function.");
        return false;
    }

    // Create a compute pipeline state object.
    id<MTLComputePipelineState> _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
    if (_mAddFunctionPSO == nil)
    {
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode)
        NSLog(@"Failed to created pipeline state object, error %@.", error);
        return false;
    }

    id<MTLCommandQueue> _mCommandQueue = [_mDevice newCommandQueue];
    if (_mCommandQueue == nil)
    {
        NSLog(@"Failed to find the command queue.");
        return false;
    }

    NSLog(@"Sending:");
    // Create a command buffer to hold commands.
    id<MTLCommandBuffer> _mCommandBuffer = [_mCommandQueue commandBuffer];
    assert(_mCommandBuffer != nil);

    // Start a compute pass.
    id<MTLComputeCommandEncoder> _mComputeEncoder = [_mCommandBuffer computeCommandEncoder];
    assert(_mComputeEncoder != nil);

    encodeAddCommand(_mComputeEncoder, _mAddFunctionPSO, _mBufferA, _mBufferB, _mBufferResult);

    // End the compute pass.
    [_mComputeEncoder endEncoding];

    // Execute the command.
    [_mCommandBuffer commit];

    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    [_mCommandBuffer waitUntilCompleted];


    float *result = _mBufferResult.contents;

    int numResultsToPrint = 10;
    NSLog(@"Results:");
    for (int i = 0; i<numResultsToPrint; i++) {
        NSLog(@"%f", result[i]);
    }

    return true;
}











__attribute__((visibility(("default"))))
void* createMetalDevice(const char *metallib_full_path) {
    printf("%s\n", metallib_full_path);

    id<MTLDevice> mDevice = MTLCreateSystemDefaultDevice();

    return (__bridge_retained void*)mDevice;
}


__attribute__((visibility(("default"))))
void* createMetalLibrary(void* device, const char *metallib_full_path) {

    id<MTLDevice> mDevice = (__bridge id<MTLDevice>)device;

    // 
    NSString *customLibraryPath = [NSString stringWithUTF8String:metallib_full_path];
    NSURL *libraryURL = [NSURL fileURLWithPath:customLibraryPath];  // Convert the file path to an NSURL
    id<MTLLibrary> mLibrary = [mDevice newLibraryWithURL:libraryURL error:nil];  // Use newLibraryWithURL instead of newLibraryWithFile

    if (mLibrary == nil)
    {
        NSLog(@"Failed to find the library.");
        return nil;
    }

    return (__bridge_retained void*)mLibrary;
}





__attribute__((visibility("default")))
void* makeMetalVectorObsolete(void* device, size_t data_type, size_t numElements) {
    size_t bufferSize;
    switch (data_type) {
        case 0:
            bufferSize = numElements * sizeof(float);
        case 1:
            bufferSize = numElements * sizeof(int);
            break;
        default:
            printf("Wrong type, choose one from:\n - 0 (for float)\n- 1 (for int32)");
            return NULL;
    }

    id<MTLDevice> mDevice = (__bridge id<MTLDevice>)device;

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    if (!mBufferA) {
        return NULL;
    }
    
    return (__bridge_retained void*)mBufferA;
}


__attribute__((visibility("default")))
struct metal_vector* createMetalVector(id<MTLDevice> mDevice, float* dataA, size_t numElements, enum metal_data_type data_type) {

    struct metal_vector* vec = malloc(sizeof(struct metal_vector));
    if (!vec) return NULL;

    
    size_t bufferSize = 0;
    switch (data_type) {
        case METAL_FLOAT:
            bufferSize = numElements * sizeof(float);
            break;
        case METAL_INT32:
            bufferSize = numElements * sizeof(int);
            break;
        default:
            printf("Wrong type, choose one from:\n - METAL_FLOAT\n- METAL_INT32\n");
            free(vec);
            return NULL;
    }
    // id<MTLDevice> mDevice = (__bridge_retained id<MTLDevice>)device;

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    if (!mBufferA) {
        free(vec);
        return NULL;
    }
    
    // Copy data into the Metal buffer
    void* bufferContentsA = [mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    // vec->buffer_ptr = (__bridge_retained void*)mBufferA;
    vec->buffer_ptr = mBufferA;
    vec->buffer_len = numElements;
    vec->data_type = data_type;
    vec->device = mDevice;

    return vec;
}

void destroyMetalVector(struct metal_vector* vec) {
    if (vec) {
        free(vec);
    }
}


__attribute__((visibility("default")))
void* metalVectorObsolete(void* device, float* dataA, size_t numElements) {

    size_t bufferSize = numElements * sizeof(float);
    id<MTLDevice> mDevice = (__bridge id<MTLDevice>)device;

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    if (!mBufferA) {
        return NULL;
    }
    
    // Copy data into the Metal buffer
    void* bufferContentsA = [mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    return (__bridge_retained void*)mBufferA;
}



__attribute__((visibility("default")))
void* metalInt32Vector(void* device, int* dataA, size_t numElements) {

    size_t bufferSize = numElements * sizeof(int);
    id<MTLDevice> mDevice = (__bridge id<MTLDevice>)device;

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    if (!mBufferA) {
        return NULL;
    }
    
    // Copy data into the Metal buffer
    void* bufferContentsA = [mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    return (__bridge_retained void*)mBufferA;
}


__attribute__((visibility("default")))
float* getCVector(void* buffer) {


    id<MTLBuffer>  _mBuffer  = (__bridge id<MTLBuffer>)buffer;

    if (!_mBuffer) {
        NSLog(@"Error: One or more Metal objects are invalid.");
        return false;
    }

    float *result = _mBuffer.contents;

    return result;
}

