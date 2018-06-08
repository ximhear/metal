/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for our platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;
#import "MBEFontAtlas.h"

@class FontAtlasGenerator;
// Our platform independent render class
@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView atlas:(MBEFontAtlas*)atlas;
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView atlasGenerator:(FontAtlasGenerator*)atlasGenerator;

@end
