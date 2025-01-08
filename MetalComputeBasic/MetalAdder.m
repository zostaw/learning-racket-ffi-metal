/*
A class to manage all of the Metal objects this app creates.
*/

#import "MetalAdder.h"
#include <stddef.h>
#include <stdio.h>


typedef enum {
    METAL_FLOAT = 0,
    METAL_INT32 = 1,
} metal_data_type;



typedef enum {
    METAL_ADD = 0,
    METAL_MULT = 1,
} metal_operation;



struct metal_config {
              id<MTLDevice> device;
              id<MTLLibrary> library;
};



struct metal_vector {
              id<MTLBuffer> data_ptr;
              size_t data_len; // this one is doubled actually, because MTLBuffer is pointer itself
              metal_data_type data_type;
              struct metal_config metal_config;
};



void print_offsets() {
    printf("Offset of data_ptr: %zu\n", offsetof(struct metal_vector, data_ptr));
    printf("Offset of data_len: %zu\n", offsetof(struct metal_vector, data_len));
    printf("Offset of data_type: %zu\n", offsetof(struct metal_vector, data_type));
    printf("Offset of metal_config: %zu\n", offsetof(struct metal_vector, metal_config));
}



void encodeCompCommand(id<MTLComputeCommandEncoder> computeEncoder,
                      id<MTLComputePipelineState> pipelineState,
                      id<MTLBuffer> bufferA,
                      id<MTLBuffer> bufferB,
                      id<MTLBuffer> bufferResult,
                      size_t arrayLength) {

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
bool computeWithAllocatedResultBuffer(struct metal_config* metal_config, struct metal_vector* bufferA, struct metal_vector* bufferB, struct metal_vector* bufferResult, metal_operation operation) {

    NSError* error = nil;

    id<MTLDevice>  _mDevice = metal_config->device;
    id<MTLLibrary>  _mLibrary = metal_config->library;

    id<MTLBuffer>  _mBufferA      = bufferA->data_ptr;
    id<MTLBuffer>  _mBufferB      = bufferB->data_ptr;
    id<MTLBuffer>  _mBufferResult = bufferResult->data_ptr;
    size_t bufferSize = bufferA->data_len;

    // Validate casted objects
    if (!_mDevice || !_mLibrary || !_mBufferA || !_mBufferB || !_mBufferResult) {
        NSLog(@"Error: One or more Metal objects are invalid.");
        return false;
    }



    id<MTLFunction> compFunction;
    if (operation == METAL_ADD) {
        compFunction = [_mLibrary newFunctionWithName:@"add_arrays"];
    } else if (operation == METAL_MULT) {
        compFunction = [_mLibrary newFunctionWithName:@"mult_arrays"];
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Unknown operation. Use one of: METAL_ADD METAL_MULT." userInfo:nil];
    }
    
    if (compFunction == nil)
    {
        NSLog(@"Failed to find the adder function.");
        return false;
    }

    // Create a compute pipeline state object.
    id<MTLComputePipelineState> _mCompFunctionPSO = [_mDevice newComputePipelineStateWithFunction: compFunction error:&error];
    if (_mCompFunctionPSO == nil)
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

    encodeCompCommand(_mComputeEncoder, _mCompFunctionPSO, _mBufferA, _mBufferB, _mBufferResult, bufferSize);

    // End the compute pass.
    [_mComputeEncoder endEncoding];

    // Execute the command.
    [_mCommandBuffer commit];

    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    [_mCommandBuffer waitUntilCompleted];


    // float *result = _mBufferResult.contents;

    // int numResultsToPrint = 10;
    // NSLog(@"Results:");
    // for (int i = 0; i<numResultsToPrint; i++) {
    //     NSLog(@"%f", result[i]);
    // }

    return true;
}



__attribute__((visibility("default")))
struct metal_vector compute(struct metal_config* metal_config, struct metal_vector* bufferA, struct metal_vector* bufferB, metal_operation operation) {

    NSError* error = nil;


    struct metal_vector* bufferResult = malloc(sizeof(struct metal_vector));

    if (bufferA->data_len != bufferB->data_len) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vectors are different sizes." userInfo:nil];
    }

    if (bufferA->data_type != bufferB->data_type) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vectors have different types." userInfo:nil];
    }

    if (bufferA->metal_config.device != bufferB->metal_config.device) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vectors seem to be allocated on different devices." userInfo:nil];
    }

    if (bufferA->metal_config.library != bufferB->metal_config.library) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vectors seem to be allocated on different devices." userInfo:nil];
    }

    id<MTLDevice>  _mDevice = bufferA->metal_config.device;
    id<MTLLibrary>  _mLibrary = bufferA->metal_config.library;


    if (bufferA->data_ptr == NULL) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"First vector is NULL." userInfo:nil];
    }

    if (bufferB->data_ptr == NULL) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Second vector is NULL." userInfo:nil];
    }

    size_t bufferSize = bufferA->data_len;
    metal_data_type data_type = bufferA->data_type;

    // Allocate buffer
    id<MTLBuffer>  _mBufferA      = bufferA->data_ptr;
    id<MTLBuffer>  _mBufferB      = bufferB->data_ptr;
    id<MTLBuffer>  _mBufferResult = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    // Validate casted objects
    if (!_mDevice || !_mLibrary || !_mBufferA || !_mBufferB || !_mBufferResult) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }


    id<MTLFunction> compFunction;
    if (operation == METAL_ADD) {
        compFunction = [_mLibrary newFunctionWithName:@"add_arrays"];
    } else if (operation == METAL_MULT) {
        compFunction = [_mLibrary newFunctionWithName:@"mult_arrays"];
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Unknown operation. Use one of: METAL_ADD METAL_MULT." userInfo:nil];
    }
    
    if (compFunction == nil)
    {
        NSLog(@"Failed to find the function.");
    }

    // Create a compute pipeline state object.
    id<MTLComputePipelineState> _mCompFunctionPSO = [_mDevice newComputePipelineStateWithFunction: compFunction error:&error];
    if (_mCompFunctionPSO == nil)
    {
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode)
        NSLog(@"Failed to created pipeline state object, error %@.", error);
    }

    id<MTLCommandQueue> _mCommandQueue = [_mDevice newCommandQueue];
    if (_mCommandQueue == nil)
    {
        NSLog(@"Failed to find the command queue.");
    }

    NSLog(@"Sending:");
    // Create a command buffer to hold commands.
    id<MTLCommandBuffer> _mCommandBuffer = [_mCommandQueue commandBuffer];
    assert(_mCommandBuffer != nil);

    // Start a compute pass.
    id<MTLComputeCommandEncoder> _mComputeEncoder = [_mCommandBuffer computeCommandEncoder];
    assert(_mComputeEncoder != nil);

    encodeCompCommand(_mComputeEncoder, _mCompFunctionPSO, _mBufferA, _mBufferB, _mBufferResult, bufferSize);

    // End the compute pass.
    [_mComputeEncoder endEncoding];

    // Execute the command.
    [_mCommandBuffer commit];

    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    [_mCommandBuffer waitUntilCompleted];


    // float *result = _mBufferResult.contents;

    // int numResultsToPrint = 10;
    // NSLog(@"Results:");
    // for (int i = 0; i<numResultsToPrint; i++) {
    //     NSLog(@"%f", result[i]);
    // }

    bufferResult->data_ptr = _mBufferResult;
    bufferResult->data_len = bufferSize;
    bufferResult->data_type = data_type;
    bufferResult->metal_config.device = _mDevice;

    return *bufferResult;
}







__attribute__((visibility(("default"))))
void* createMetalDevice(const char *metallib_full_path) {
    // For debugging purposes:
    // printf("%s\n", metallib_full_path);

    id<MTLDevice> mDevice = MTLCreateSystemDefaultDevice();

    return (__bridge_retained void*)mDevice;
}


__attribute__((visibility(("default"))))
void* createMetalLibrary(id<MTLDevice> mDevice, const char *metallib_full_path) {

    NSString *customLibraryPath = [NSString stringWithUTF8String:metallib_full_path];
    NSURL *libraryURL = [NSURL fileURLWithPath:customLibraryPath];  // Convert the file path to an NSURL
    id<MTLLibrary> mLibrary = [mDevice newLibraryWithURL:libraryURL error:nil];  // Use newLibraryWithURL instead of newLibraryWithFile

    if (mLibrary == nil)
    {
        NSLog(@"Failed to find the library.");
        return nil;
    }

    // For debugging purposes:
    // NSArray<NSString *> *functionNames = [mLibrary functionNames];
    // NSLog(@"Available functions: %@", functionNames);

    return (__bridge_retained void*)mLibrary;
}


__attribute__((visibility(("default"))))
struct metal_config initializeMetal(const char *metallib_full_path) {
    struct metal_config* config = malloc(sizeof(struct metal_config));

    id<MTLDevice> mDevice = (__bridge id<MTLDevice>)createMetalDevice(metallib_full_path);
    id<MTLLibrary> mLibrary = (__bridge id<MTLLibrary>)createMetalLibrary(mDevice, metallib_full_path);

    config->device = mDevice;
    config->library = mLibrary;

    return *config;
}



__attribute__((visibility("default")))
struct metal_vector createMetalVector(struct metal_config* metal_config, float* dataA, size_t numElements, metal_data_type data_type) {

    id<MTLDevice>  mDevice = metal_config->device;
    struct metal_vector* vec = malloc(sizeof(struct metal_vector));

    if (!vec) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vector could not be allocated." userInfo:nil];
    }


    size_t bufferSize = 0;
    switch (data_type) {
        case METAL_FLOAT:
            bufferSize = numElements * sizeof(float);
            break;
        case METAL_INT32:
            bufferSize = numElements * sizeof(int);
            break;
        default:
            free(vec);
            @throw [NSException exceptionWithName:@"MyException" reason:@"Wrong type, choose one from:\n - METAL_FLOAT\n- METAL_INT32\n" userInfo:nil];
    }

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    if (!mBufferA) {
        free(vec);
        @throw [NSException exceptionWithName:@"MyException" reason:@"Vector's MTLBuffer could not be allocated." userInfo:nil];
    }
    
    // Copy data into the Metal buffer
    void* bufferContentsA = [mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    vec->data_ptr = mBufferA;
    vec->data_len = numElements;
    vec->data_type = data_type;
    vec->metal_config = *metal_config;

    return *vec;
}

void destroyMetalVector(struct metal_vector* vec) {
    if (vec) {
        free(vec);
    }
}




__attribute__((visibility("default")))
float* getCFloatVector(struct metal_vector vec) {

    id<MTLBuffer>  _mBuffer  = vec.data_ptr;

    if (!_mBuffer) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }

    if (vec.data_type != METAL_FLOAT) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Called getCFloatVector on metal_vector that is not METAL_FLOAT type." userInfo:nil];
    }

    float *result = _mBuffer.contents;

    return result;
}

__attribute__((visibility("default")))
int* getCInt32Vector(struct metal_vector vec) {

    id<MTLBuffer> _mBuffer  = vec.data_ptr;

    if (!_mBuffer) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }

    if (vec.data_type != METAL_INT32) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Called getCInt32Vector on metal_vector that is not METAL_INT32 type." userInfo:nil];
    }

    int *result = _mBuffer.contents;

    return result;
}
