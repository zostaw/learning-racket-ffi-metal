/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to manage all of the Metal objects this app creates.
*/

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>


NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// Function to initialize the MetalAdder object
void* createMetalAdder(void);

// Function to perform computation on GPU
void performComputation(void* adder);

#ifdef __cplusplus
}
#endif


@interface MetalAdder : NSObject
- (instancetype) initWithDevice: (id<MTLDevice>) device;
- (void) prepareData;
- (void) sendComputeCommand;
@end

NS_ASSUME_NONNULL_END
