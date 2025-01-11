/*
A shader that multiplies two arrays of floats.
*/

#include <metal_stdlib>
using namespace metal;
kernel void mult_arrays(device const float* inA,
                        device const float* inB,
                        device float* result,
                        uint index [[thread_position_in_grid]]) {
    result[index] = inA[index] * inB[index];
}

kernel void matmul(device const float* A [[buffer(0)]],
                   device const float* B [[buffer(1)]],
                   device       float* C [[buffer(2)]],
                   constant uint &rows_A [[buffer(3)]],
                   constant uint &cols_A [[buffer(4)]],
                   constant uint &rows_B [[buffer(5)]],
                   constant uint &cols_B [[buffer(6)]],
                   uint2 tid [[thread_position_in_grid]]) {
    float result = 0.0f;
    for (uint i = 0; i < rows_A; i++) {
        result += A[tid.x * rows_A + i] * B[i * cols_A * tid.y];
    }
    C[tid.x * cols_A + tid.y] = result;
}

