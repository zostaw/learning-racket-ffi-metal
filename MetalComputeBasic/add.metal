/*
A shader that adds two arrays of floats.
*/

#include <metal_stdlib>
using namespace metal;
kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device       float* result,
                       uint index [[thread_position_in_grid]])
{
    result[index] = inA[index] + inB[index];
}


kernel void add_matrices(device const float* A [[buffer(0)]],
                         device const float* B [[buffer(1)]],
                         device       float* C [[buffer(2)]],
                         constant uint &rows_A [[buffer(3)]],
                         constant uint &cols_A [[buffer(4)]],
                         constant uint &rows_B [[buffer(5)]],
                         constant uint &cols_B [[buffer(6)]],
                         uint2 tid [[thread_position_in_grid]]) {
    C[tid.x * cols_A + tid.y] = A[tid.x * cols_A + tid.y] + B[tid.x * cols_A + tid.y];
}
