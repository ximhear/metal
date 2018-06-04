/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for our platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;
#import "MBEFontAtlas.h"

// Our platform independent render class
@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView atlas:(MBEFontAtlas*)atlas;

@end
