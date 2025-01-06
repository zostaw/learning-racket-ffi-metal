/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to manage all of the Metal objects this app creates.
*/

#import "MetalAdder.h"

// The number of floats in each array, and the size of the arrays in bytes.
const unsigned int arrayLength = 1 << 24;
const unsigned int bufferSize = arrayLength * sizeof(float);

@implementation MetalAdder
{
    id<MTLDevice> _mDevice;

    // The compute pipeline generated from the compute kernel in the .metal shader file.
    id<MTLComputePipelineState> _mAddFunctionPSO;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _mCommandQueue;

    // Buffers to hold data.
    id<MTLBuffer> _mBufferA;
    id<MTLBuffer> _mBufferB;
    id<MTLBuffer> _mBufferResult;

}

- (instancetype) initWithDevice: (id<MTLDevice>) device customLibraryPath: (NSString*) customLibraryPath
{
    self = [super init];
    if (self)
    {
        _mDevice = device;

        NSError* error = nil;

        // Load the shader files with a .metal file extension in the project
        id<MTLLibrary> defaultLibrary;
        
        if (customLibraryPath != nil) {
            NSLog(@"Trying mCustomLibrary");

            NSURL *libraryURL = [NSURL fileURLWithPath:customLibraryPath];  // Convert the file path to an NSURL

            defaultLibrary = [device newLibraryWithURL:libraryURL error:nil];  // Use newLibraryWithURL instead of newLibraryWithFile
        } else {
            NSLog(@"Trying newDefaultLibrary");
            defaultLibrary = [_mDevice newDefaultLibrary];
        }

        if (defaultLibrary == nil)
        {
            NSLog(@"Failed to find the default library.");
            return nil;
        }

        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (addFunction == nil)
        {
            NSLog(@"Failed to find the adder function.");
            return nil;
        }

        // Create a compute pipeline state object.
        _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (_mAddFunctionPSO == nil)
        {
            //  If the Metal API validation is enabled, you can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }

        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil)
        {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }
    }

    return self;
}

- (void) prepareData
{
    // Allocate three buffers to hold our initial data and the result.
    _mBufferA =      [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferB =      [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferResult = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    
    
    
    // Example: Define and initialize dataA
    size_t numElements = 1024;              // Number of floats
    size_t bufferSize = numElements * sizeof(float); // Total size in bytes

    // Allocate memory for the array
    float* dataA = (float*)malloc(bufferSize);
    float* dataB = (float*)malloc(bufferSize);

    // Fill the array with data
    for (size_t i = 0; i < numElements; ++i) {
        dataA[i] = (float)i; // Example: Fill with increasing values
        dataB[i] = (float)(i*2); // Example: Fill with increasing values
    }

    // Copy data into the Metal buffer
    void* bufferContentsA = [_mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);
    
    void* bufferContentsB = [_mBufferB contents];
    memcpy(bufferContentsB, dataB, bufferSize);

    // Free memory after use
    free(dataA);
    free(dataB);

}

- (void)prepareDataWithFloatInputs:(float*)dataA dataB:(float*)dataB numElements:(size_t)numElements {
    size_t bufferSize = numElements * sizeof(float);

    // Allocate three buffers to hold our initial data and the result.
    _mBufferA = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferB = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferResult = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    // Copy data into the Metal buffers
    void* bufferContentsA = [_mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    void* bufferContentsB = [_mBufferB contents];
    memcpy(bufferContentsB, dataB, bufferSize);
}




- (void) sendComputeCommand
{
    NSLog(@"Sending:");
    // Create a command buffer to hold commands.
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);

    // Start a compute pass.
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);

    [self encodeAddCommand:computeEncoder];

    // End the compute pass.
    [computeEncoder endEncoding];

    // Execute the command.
    [commandBuffer commit];

    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    [commandBuffer waitUntilCompleted];


    float *result = self.mBufferResult.contents;

    int numResultsToPrint = 10;
    NSLog(@"Results:");
    for (int i = 0; i<numResultsToPrint; i++) {
        NSLog(@"%f", result[i]);
    }

    [self verifyResults];
}


enum metal_data_type {
    FLOAT,
    INT32,
};

struct metal_vector {
              void* buffer_ptr;
              int buffer_len;
              enum metal_data_type data_type;
};


__attribute__((visibility("default")))
bool computeAdd(void* device, void*library, void* bufferA, void* bufferB, void* bufferResult) {

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

- (void)encodeAddCommand:(id<MTLComputeCommandEncoder>)computeEncoder {

    // Encode the pipeline state object and its parameters.
    [computeEncoder setComputePipelineState:_mAddFunctionPSO];
    [computeEncoder setBuffer:_mBufferA offset:0 atIndex:0];
    [computeEncoder setBuffer:_mBufferB offset:0 atIndex:1];
    [computeEncoder setBuffer:_mBufferResult offset:0 atIndex:2];

    MTLSize gridSize = MTLSizeMake(arrayLength, 1, 1);

    // Calculate a threadgroup size.
    NSUInteger threadGroupSize = _mAddFunctionPSO.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > arrayLength)
    {
        threadGroupSize = arrayLength;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    // Encode the compute command.
    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
}

- (void) generateRandomFloatData: (id<MTLBuffer>) buffer
{
    float* dataPtr = buffer.contents;

    for (unsigned long index = 0; index < arrayLength; index++)
    {
        dataPtr[index] = (float)rand()/(float)(RAND_MAX);
    }
}
- (void) verifyResults
{
    float* a = _mBufferA.contents;
    float* b = _mBufferB.contents;
    float* result = _mBufferResult.contents;

    for (unsigned long index = 0; index < arrayLength; index++)
    {
        if (result[index] != (a[index] + b[index]))
        {
            printf("Compute ERROR: index=%lu result=%g vs %g=a+b\n",
                   index, result[index], a[index] + b[index]);
            assert(result[index] == (a[index] + b[index]));
        }
    }
    printf("Compute results as expected\n");
}



// Expose the creation function for FFI
__attribute__((visibility(("default"))))
void* createMetalAdder(const char *metallib_full_path) {
    printf("%s\n", metallib_full_path);

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();

    NSString *customLibraryPath = [NSString stringWithUTF8String:metallib_full_path];

    MetalAdder* adder = [[MetalAdder alloc] initWithDevice:device customLibraryPath:customLibraryPath];

    return (__bridge_retained void*)adder;  // Return a raw pointer to the MetalAdder object
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



// Expose the computation function for FFI
__attribute__((visibility(("default"))))
void performComputation(void* adder) {
    MetalAdder* metalAdder = (__bridge MetalAdder*)adder;
    [metalAdder prepareData];
    [metalAdder sendComputeCommand];
    NSLog(@"Execution finished");
}



__attribute__((visibility("default")))
void performComputationWithFloatInputs(void* adder, float* dataA, size_t numElements, float* dataB, size_t _numElementsB) {
    MetalAdder* metalAdder = (__bridge MetalAdder*)adder;
    [metalAdder prepareDataWithFloatInputs:dataA dataB:dataB numElements:numElements];
    [metalAdder sendComputeCommand];
    NSLog(@"Execution finished");
}




__attribute__((visibility("default")))
void* makeMetalVector(void* device, size_t data_type, size_t numElements) {
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
void* metalVector(void* device, float* dataA, size_t numElements) {

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

@end
