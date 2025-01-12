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
    METAL_MUL = 1,
    METAL_MAT_ADD = 2,
    METAL_MAT_MUL = 3,
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


struct metal_matrix {
              id<MTLBuffer> data_ptr;
              size_t data_len;
              size_t data_rows;
              size_t data_cols;
              id<MTLBuffer> data_rows_ptr;
              id<MTLBuffer> data_cols_ptr;
              metal_data_type data_type;
              struct metal_config metal_config;
};

void print_offsets(void) {
    printf("Offset of data_ptr: %zu\n", offsetof(struct metal_vector, data_ptr));
    printf("Offset of data_len: %zu\n", offsetof(struct metal_vector, data_len));
    printf("Offset of data_type: %zu\n", offsetof(struct metal_vector, data_type));
    printf("Offset of metal_config: %zu\n", offsetof(struct metal_vector, metal_config));
}












/***************************** Compute Arrays *****************************

   Functions in this section are responsible for operations on Arrays.
   Buffers should generally have the same number of elements.
   arrayLength is common for both arrays/vectors, provided as single argument..
*/



/* encodeCompCommand
   
   Sets up a kernel and prepares buffers for operations.
*/
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



/* computeWithAllocatedResultBuffer
 
   This function implements operation according to metal_operation enum value.
   You can notice it takes bufferResult as argument. 
   There is another function called simply *compute*. 
   They both do exactly the same, the only difference is that this function here takes result buffer as argument and fills it with output, the *compute* function doesn't take this argument, but returns NEW buffer.
   This is to allow flexibility. 

   In general if you just want to make an operation once and get the result, you might wanna use *compute*, 
    but if you want to optimize operations and re-use result buffer, then it's probably better to use *computeWithAllocatedResultBuffer*, because it doens't allocate buffer again and again which might be costly.

   That being said, this is all just learning, it's probably better to go for MPS if you care about performance.
*/
__attribute__((visibility("default")))
bool computeWithAllocatedResultBuffer(struct metal_config* metal_config,
                                      struct metal_vector* bufferA,
                                      struct metal_vector* bufferB,
                                      struct metal_vector* bufferResult,
                                      metal_operation operation) {

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
    } else if (operation == METAL_MUL) {
        compFunction = [_mLibrary newFunctionWithName:@"mult_arrays"];
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Unknown operation. Use one of: METAL_ADD METAL_MUL." userInfo:nil];
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

    //NSLog(@"Sending:");
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



/* compute
   Calculates array operation according to *operation*.
   See *computeWithAllocatedResultBuffer* description for more details.
*/
__attribute__((visibility("default")))
struct metal_vector compute(struct metal_config* metal_config,
                            struct metal_vector* bufferA,
                            struct metal_vector* bufferB,
                            metal_operation operation) {

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
    } else if (operation == METAL_MUL) {
        compFunction = [_mLibrary newFunctionWithName:@"mult_arrays"];
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Unknown operation. Use one of: METAL_ADD METAL_MUL." userInfo:nil];
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

    //NSLog(@"Sending:");
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















/***************************** Compute Matrices *****************************

   Functions in this section are responsible for operations on Matrices.
   Bufers are flattened matrices and of course their lengths should be set accordingly to the requirements of the operation.
   For instance for matmul operation you want vectors A and B be such that A is shape m by n and B n by k.
*/



/* encodeMatrixCompCommand
   
   Sets up a kernel and prepares buffers for operations.
   arrayLength is a total length of the longest matrix (flattened ofc).

   And then the specific dimensions should be following the requirements of the operation. Use following args to provide them:
   - bufferArows
   - bufferAcols
   - bufferBrows
   - bufferBcols
*/
void encodeMatrixCompCommand(id<MTLComputeCommandEncoder> computeEncoder,
                             id<MTLComputePipelineState> pipelineState,
                             id<MTLBuffer> bufferA,
                             id<MTLBuffer> bufferB,
                             id<MTLBuffer> bufferResult,
                             id<MTLBuffer> bufferArows,
                             id<MTLBuffer> bufferAcols,
                             id<MTLBuffer> bufferBrows,
                             id<MTLBuffer> bufferBcols,
                             size_t arrayLength) {

    // Encode the pipeline state object and its parameters.
    [computeEncoder setComputePipelineState:pipelineState];
    [computeEncoder setBuffer:bufferA offset:0 atIndex:0];
    [computeEncoder setBuffer:bufferB offset:0 atIndex:1];
    [computeEncoder setBuffer:bufferResult offset:0 atIndex:2];
    [computeEncoder setBuffer:bufferArows offset:0 atIndex:3];
    [computeEncoder setBuffer:bufferAcols offset:0 atIndex:4];
    [computeEncoder setBuffer:bufferBrows offset:0 atIndex:5];
    [computeEncoder setBuffer:bufferBcols offset:0 atIndex:6];

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
struct metal_matrix computeMatrix(struct metal_config* metal_config,
                                  struct metal_matrix* bufferA,
                                  struct metal_matrix* bufferB,
                                  metal_operation operation) {

    NSError* error = nil;


    struct metal_matrix* bufferResult = malloc(sizeof(struct metal_matrix));
    size_t *dataRowsA = (size_t *)bufferA->data_rows_ptr.contents;
    size_t *dataColsA = (size_t *)bufferA->data_cols_ptr.contents;
    size_t *dataRowsB = (size_t *)bufferB->data_rows_ptr.contents;
    size_t *dataColsB = (size_t *)bufferB->data_cols_ptr.contents;

    size_t rows;
    size_t cols;

    if (operation == METAL_MAT_ADD) {
        if (bufferA->data_rows != bufferB->data_rows || bufferA->data_cols != bufferB->data_cols) {
            printf("Different sizes in Add function. A rows %zu, cols %zu\nB rows %zu, cols %zu\n\n", bufferA->data_rows, bufferA->data_cols, bufferB->data_rows, bufferB->data_cols);
            @throw [NSException exceptionWithName:@"MyException" reason:@"matrices are different sizes." userInfo:nil];
        }
    } else if (operation == METAL_MAT_MUL) {
        if (bufferA->data_cols != bufferB->data_rows) {
            printf("A rows %zu, cols %zu\nB rows %zu, cols %zu\n\n", bufferA->data_rows, bufferA->data_cols, bufferB->data_rows, bufferB->data_cols);
            @throw [NSException exceptionWithName:@"MyException" reason:@"matrices have different common dimension for matmul." userInfo:nil];
        }
    } else {
            @throw [NSException exceptionWithName:@"MyException" reason:@"Operation not supported." userInfo:nil];
    }


    if (bufferA->data_type != bufferB->data_type) {
        NSString *errorMessage = [NSString stringWithFormat:@"Matrices have different types: %u and %u.", bufferA->data_type, bufferB->data_type];
        @throw [NSException exceptionWithName:@"MyException" reason:errorMessage userInfo:nil];
    }

    if (bufferA->metal_config.device != bufferB->metal_config.device) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"matrices seem to be allocated on different devices." userInfo:nil];
    }

    if (bufferA->metal_config.library != bufferB->metal_config.library) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"matrices seem to be allocated on different devices." userInfo:nil];
    }

    id<MTLDevice>  _mDevice = bufferA->metal_config.device;
    id<MTLLibrary>  _mLibrary = bufferA->metal_config.library;


    if (bufferA->data_ptr == NULL) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"First matrix is NULL." userInfo:nil];
    }

    if (bufferB->data_ptr == NULL) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Second matrix is NULL." userInfo:nil];
    }




    size_t resultBufferSize;
    if (operation == METAL_MAT_ADD) {
        rows = bufferA->data_rows;
        cols = bufferA->data_cols;
        resultBufferSize = bufferA->data_len;
    } else if (operation == METAL_MAT_MUL) {
        rows = bufferA->data_rows;
        cols = bufferB->data_cols;
        //resultBufferSize = *dataRowsA * *dataColsB;
        resultBufferSize = rows * cols;
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Operation not supported." userInfo:nil];
    }



    metal_data_type data_type = bufferA->data_type;

    // Allocate buffer
    id<MTLBuffer>  _mBufferA      = bufferA->data_ptr;
    id<MTLBuffer>  _mBufferB      = bufferB->data_ptr;
    id<MTLBuffer>  _mBufferResult = [_mDevice newBufferWithLength:resultBufferSize 
                                                          options:MTLResourceStorageModeShared];
    id<MTLBuffer>  bufferArows = bufferA->data_rows_ptr;
    id<MTLBuffer>  bufferAcols = bufferA->data_cols_ptr;
    id<MTLBuffer>  bufferBrows = bufferB->data_rows_ptr;
    id<MTLBuffer>  bufferBcols = bufferB->data_cols_ptr;

    // Validate casted objects
    if (!_mDevice || !_mLibrary || !_mBufferA || !_mBufferB || !_mBufferResult) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }


    id<MTLFunction> compFunction;
    if (operation == METAL_MAT_ADD) {
        compFunction = [_mLibrary newFunctionWithName:@"add_matrices"];
    } else if (operation == METAL_MAT_MUL) {
        compFunction = [_mLibrary newFunctionWithName:@"matmul"];
    } else {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Unknown operation. Use one of: METAL_MAT_ADD METAL_MAT_MUL." userInfo:nil];
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

    //NSLog(@"Sending:");
    // Create a command buffer to hold commands.
    id<MTLCommandBuffer> _mCommandBuffer = [_mCommandQueue commandBuffer];
    assert(_mCommandBuffer != nil);

    // Start a compute pass.
    id<MTLComputeCommandEncoder> _mComputeEncoder = [_mCommandBuffer computeCommandEncoder];
    assert(_mComputeEncoder != nil);

    encodeMatrixCompCommand(_mComputeEncoder, _mCompFunctionPSO, _mBufferA, _mBufferB, _mBufferResult, bufferArows, bufferAcols, bufferBrows, bufferBcols, resultBufferSize);


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

    id<MTLBuffer>  bufferResultrows = [_mDevice newBufferWithBytes:&dataRowsA
                                                       length:sizeof(size_t)
                                                      options:MTLResourceStorageModeShared];
    id<MTLBuffer>  bufferResultcols = [_mDevice newBufferWithBytes:&dataColsB
                                                       length:sizeof(size_t)
                                                      options:MTLResourceStorageModeShared];
    bufferResult->data_ptr = _mBufferResult;
    bufferResult->data_len = resultBufferSize;
    bufferResult->data_type = data_type;
    bufferResult->data_rows = rows;
    bufferResult->data_cols = cols;
    bufferResult->data_rows_ptr = bufferResultrows;
    bufferResult->data_cols_ptr = bufferResultcols;
    bufferResult->metal_config.device = _mDevice;
    bufferResult->metal_config.library = _mLibrary;

    return *bufferResult;
}















__attribute__((visibility(("default"))))
void* createMetalDevice(const char *metallib_full_path) {
    // For debugging purposes:
    //printf("%s\n", metallib_full_path);

    id<MTLDevice> mDevice = MTLCreateSystemDefaultDevice();

    return (__bridge_retained void*)mDevice;
}


__attribute__((visibility(("default"))))
void* createMetalLibrary(id<MTLDevice> mDevice,
                         const char *metallib_full_path) {

    NSString *customLibraryPath = [NSString stringWithUTF8String:metallib_full_path];
    NSURL *libraryURL = [NSURL fileURLWithPath:customLibraryPath];  // Convert the file path to an NSURL
    id<MTLLibrary> mLibrary = [mDevice newLibraryWithURL:libraryURL error:nil];  // Use newLibraryWithURL instead of newLibraryWithFile

    if (mLibrary == nil)
    {
        NSLog(@"Failed to find the library.");
        return nil;
    }

    // For debugging purposes:
    NSArray<NSString *> *functionNames = [mLibrary functionNames];
    //NSLog(@"Available functions: %@", functionNames);

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
struct metal_vector createMetalVector(struct metal_config* metal_config,
                                      float* dataA,
                                      size_t numElements,
                                      metal_data_type data_type) {

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










/* Matrix
 
   Functions that implement matrices initialization and handling.
*/
__attribute__((visibility("default")))
struct metal_matrix createMetalMatrix(struct metal_config* metal_config,
                                      float* dataA,
                                      size_t numElements,
                                      size_t rows,
                                      size_t cols,
                                      metal_data_type data_type) {

    id<MTLDevice>  mDevice = metal_config->device;
    struct metal_matrix* mat = malloc(sizeof(struct metal_matrix));

    if (!mat) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Matrix could not be allocated." userInfo:nil];
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
            free(mat);
            @throw [NSException exceptionWithName:@"MyException" reason:@"Wrong type, choose one from:\n - METAL_FLOAT\n- METAL_INT32\n" userInfo:nil];
    }

    // Allocate buffer
    id<MTLBuffer> mBufferA = [mDevice newBufferWithLength:bufferSize
                                                  options:MTLResourceStorageModeShared];
    id<MTLBuffer>  bufferArows = [mDevice newBufferWithBytes:&rows
                                                       length:sizeof(size_t)
                                                      options:MTLResourceStorageModeShared];
    id<MTLBuffer>  bufferAcols = [mDevice newBufferWithBytes:&cols
                                                       length:sizeof(size_t)
                                                      options:MTLResourceStorageModeShared];

    if (!mBufferA || !bufferArows || !bufferAcols) {
        free(mat);
        @throw [NSException exceptionWithName:@"MyException" reason:@"Matrix's MTLBuffer could not be allocated." userInfo:nil];
    }

    
    // Copy data into the Metal buffer
    void* bufferContentsA = [mBufferA contents];
    memcpy(bufferContentsA, dataA, bufferSize);

    mat->data_ptr = mBufferA;
    mat->data_len = numElements;
    mat->data_rows = rows;
    mat->data_cols = cols;
    mat->data_rows_ptr = bufferArows;
    mat->data_cols_ptr = bufferAcols;
    mat->data_type = data_type;
    mat->metal_config = *metal_config;

    return *mat;
}





__attribute__((visibility("default")))
float* getCFloatMatrix(struct metal_matrix mat) {

    id<MTLBuffer>  _mBuffer  = mat.data_ptr;

    if (!_mBuffer) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }

    if (mat.data_type != METAL_FLOAT) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Called getCFloatMatrix on metal_matrix that is not METAL_FLOAT type." userInfo:nil];
    }


    float* result = (float* )_mBuffer.contents;
    return result;
}



__attribute__((visibility("default")))
int* getCInt32Matrix(struct metal_matrix mat) {

    id<MTLBuffer>  _mBuffer  = mat.data_ptr;

    if (!_mBuffer) {
        NSLog(@"Error: One or more Metal objects are invalid.");
    }

    if (mat.data_type != METAL_INT32) {
        @throw [NSException exceptionWithName:@"MyException" reason:@"Called getCInt32Matrix on metal_matrix that is not METAL_INT32 type." userInfo:nil];
    }


    int* result = (int* )_mBuffer.contents;
    return result;
}


