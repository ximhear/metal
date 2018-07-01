/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "AAPLRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "AAPLShaderTypes.h"
#import "sdfgenerator-Swift.h"

static float MBEFontAtlasSize = 64/*2048*/ * SCALE_FACTOR;
const int maxCount = 10;

@interface AAPLRenderer ()

@property (nonatomic, strong) id<MTLTexture> fontTexture;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (strong) id<MTLBuffer> vertexBuffer;
@property (strong) id<MTLBuffer> indexBuffer;

@end

// Main class performing the rendering
@implementation AAPLRenderer
{
    // The device (aka GPU) we're using to render
    id<MTLDevice> _device;

    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    id<MTLRenderPipelineState> _pipelineState;

    // The command Queue from which we'll obtain command buffers
    id<MTLCommandQueue> _commandQueue;

    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
    
    MBEFontAtlas* _atlas;
    FontAtlasGenerator* _atlasGenerator;
}

/// Initialize with the MetalKit view from which we'll obtain our Metal device
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView  atlas:(MBEFontAtlas*)atlas
{
    self = [super init];
    if(self)
    {
        NSError *error = NULL;

        _device = mtkView.device;
        _atlas = atlas;

        // Load all the shader files with a .metal file extension in the project
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Load the vertex function from the library
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Load the fragment function from the library
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Configure a pipeline descriptor that is used to create a pipeline state
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;

        pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_pipelineState)
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state, error %@", error);
            return nil;
        }

        MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToZero;
        samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToZero;
        _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        
        MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
                                             texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                             width:MBEFontAtlasSize
                                             height:MBEFontAtlasSize
                                             mipmapped:NO];
        textureDesc.usage = MTLTextureUsageShaderRead;
        MTLRegion region = MTLRegionMake2D(0, 0, MBEFontAtlasSize, MBEFontAtlasSize);
        _fontTexture = [_device newTextureWithDescriptor:textureDesc];
        [_fontTexture setLabel:@"Font Atlas"];
        NSLog(@"\n%@", atlas.textureData);
        [_fontTexture replaceRegion:region mipmapLevel:0 withBytes:atlas.textureData.bytes bytesPerRow:MBEFontAtlasSize];

        _uniformBuffer = [_device newBufferWithLength:sizeof(MBEUniforms)
                                              options:MTLResourceOptionCPUCacheModeDefault];
        [_uniformBuffer setLabel:@"Uniform Buffer"];

    }

    return self;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView atlasGenerator:(FontAtlasGenerator*)atlasGenerator {
    self = [super init];
    if(self)
    {
        NSError *error = NULL;
        
        _device = mtkView.device;
        _atlasGenerator = atlasGenerator;
        
        // Load all the shader files with a .metal file extension in the project
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        
        // Load the vertex function from the library
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        // Load the fragment function from the library
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
        
        // Configure a pipeline descriptor that is used to create a pipeline state
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        
        pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_pipelineState)
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state, error %@", error);
            return nil;
        }
        
        MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToZero;
        samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToZero;
        _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
        
        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        
        MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
                                             texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                             width:MBEFontAtlasSize
                                             height:MBEFontAtlasSize
                                             mipmapped:NO];
        textureDesc.usage = MTLTextureUsageShaderRead;
        MTLRegion region = MTLRegionMake2D(0, 0, MBEFontAtlasSize, MBEFontAtlasSize);
        _fontTexture = [_device newTextureWithDescriptor:textureDesc];
        [_fontTexture setLabel:@"Font Atlas"];
        NSLog(@"\n%@", _atlasGenerator.textureData);
        [_fontTexture replaceRegion:region mipmapLevel:0 withBytes:_atlasGenerator.textureData.bytes bytesPerRow:MBEFontAtlasSize];
        
        _uniformBuffer = [_device newBufferWithLength:sizeof(MBEUniforms)
                                              options:MTLResourceOptionCPUCacheModeDefault];
        [_uniformBuffer setLabel:@"Uniform Buffer"];
        
    }
    
    return self;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView string:(NSString*)string atlasGenerator:(FontAtlasGenerator*)atlasGenerator {
    self = [super init];
    if(self)
    {
        NSError *error = NULL;
        
        _device = mtkView.device;
        _atlasGenerator = atlasGenerator;
        
        // Load all the shader files with a .metal file extension in the project
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        
        // Load the vertex function from the library
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        // Load the fragment function from the library
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
        
        // Configure a pipeline descriptor that is used to create a pipeline state
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        
        pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_pipelineState)
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state, error %@", error);
            return nil;
        }
        
        MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToZero;
        samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToZero;
        _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
        
        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        
        MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
                                             texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                             width: _atlasGenerator.textureWidth
                                             height: _atlasGenerator.textureHeight
                                             mipmapped:NO];
        textureDesc.usage = MTLTextureUsageShaderRead;
        MTLRegion region = MTLRegionMake2D(0, 0, _atlasGenerator.textureWidth, _atlasGenerator.textureHeight);
        _fontTexture = [_device newTextureWithDescriptor:textureDesc];
        [_fontTexture setLabel:@"Font Atlas"];
        NSLog(@"\n%@", _atlasGenerator.textureData);
        [_fontTexture replaceRegion:region mipmapLevel:0 withBytes:_atlasGenerator.textureData.bytes bytesPerRow:_atlasGenerator.textureWidth];
        
        _uniformBuffer = [_device newBufferWithLength:sizeof(MBEUniforms)
                                              options:MTLResourceOptionCPUCacheModeDefault];
        [_uniformBuffer setLabel:@"Uniform Buffer"];

        
        float minS = 0;
        float maxS = 1;
        float minT = 0;
        float maxT = 1;
        float a = 1.0 / 1;
        float valueX = 0.95;
        float valueY = 0.95;
        AAPLVertex triangleVertices[4 * maxCount * maxCount];
        uint16_t triangleIndex[6 * maxCount * maxCount];
        float height = valueY * 2 / maxCount;
        for (int row = 0 ; row < maxCount ; row++) {
            float width = 0;
            float width1 = 0;
            
            float x = 0;
            float x1 = 0;
            
            if (a == 1) {
                width = valueX * 2 / maxCount;
                width1 = valueX * 2 / maxCount;
            }
            else {
                width = (2 * ((row * a * valueX) + (maxCount - row) * valueX) / maxCount) / maxCount;
                width1 = (2 * (((row+1) * a * valueX) + (maxCount - row -1) * valueX) / maxCount) / maxCount;
            }
            
            x = - width * maxCount / 2.0;
            x1 = - width1 * maxCount / 2.0;
            
            
            for (int col = 0 ; col < maxCount ; col++) {
                
                AAPLVertex a0 = { { x1 + width1 * (col+1), valueY - height * (row+1)}, { maxS / maxCount * (col + 1), maxT / maxCount * (row+1)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 0] = a0;
                
                AAPLVertex a1 = { { x1 + width1 * (col + 0), valueY - height * (row+1)}, { maxS / maxCount * (col + 0), maxT / maxCount * (row+1)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 1] = a1;
                
                AAPLVertex a2 = { { x + width * (col + 0), valueY - height * (row+0)}, { maxS / maxCount * (col + 0), maxT / maxCount * (row+0)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 2] = a2;
                
                AAPLVertex a4 = { { x + width * (col + 1), valueY - height * (row+0)}, { maxS / maxCount * (col + 1), maxT / maxCount * (row+0)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 3] = a4;
            }
        }

        for (int row = 0 ; row < maxCount ; row++) {
            for (int col = 0 ; col < maxCount ; col++) {
                triangleIndex[row * maxCount * 6 + col * 6 + 0] = row * maxCount * 4 + col * 4 + 0;
                triangleIndex[row * maxCount * 6 + col * 6 + 1] = row * maxCount * 4 + col * 4 + 1;
                triangleIndex[row * maxCount * 6 + col * 6 + 2] = row * maxCount * 4 + col * 4 + 2;
                triangleIndex[row * maxCount * 6 + col * 6 + 3] = row * maxCount * 4 + col * 4 + 2;
                triangleIndex[row * maxCount * 6 + col * 6 + 4] = row * maxCount * 4 + col * 4 + 3;
                triangleIndex[row * maxCount * 6 + col * 6 + 5] = row * maxCount * 4 + col * 4 + 0;
            }
        }

        _vertexBuffer = [_device newBufferWithBytes:triangleVertices
                                                 length:sizeof(triangleVertices)
                                                options:MTLResourceOptionCPUCacheModeDefault];
        [_vertexBuffer setLabel:@"Vertices"];
        
        _indexBuffer = [_device newBufferWithBytes:triangleIndex
                                                length:sizeof(triangleIndex)
                                               options:MTLResourceOptionCPUCacheModeDefault];
        [_indexBuffer setLabel:@"Indices"];

        
    }
    
    return self;
}

- (void)updateUniforms
{
    MBEUniforms uniforms;
    
    vector_float4 MBETextColor = { 0, 1, 0, 1 };
    uniforms.foregroundColor = MBETextColor;

    uniforms.projectionMatrix = [self matrix_float4x4_orthoWithleft:-2 right:2 bottom:-2 top:2 near:-1 far:1];

    memcpy([self.uniformBuffer contents], &uniforms, sizeof(MBEUniforms));
}

-(simd_float4x4)matrix_float4x4_orthoWithleft:(CGFloat)left right:(CGFloat)right bottom:(CGFloat)bottom top:(CGFloat)top near:(CGFloat)near far:(CGFloat)far {
    CGFloat ral = right + left;
    CGFloat rsl = right - left;
    CGFloat tab = top + bottom;
    CGFloat tsb = top - bottom;
    CGFloat fan = far + near;
    CGFloat fsn = far - near;
    
    simd_float4 P = simd_make_float4( 2.0 / rsl, 0, 0, 0 );
    simd_float4 Q = simd_make_float4( 0.0, 2.0 / tsb, 0.0, 0.0 );
    simd_float4 R = simd_make_float4( 0.0, 0.0, -2.0 / fsn, 0.0 );
    simd_float4 S = simd_make_float4( -ral / rsl, -tab / tsb, -fan / fsn, 1.0 );
    
    simd_float4x4 mat = simd_matrix(P, Q, R, S );
    return mat;
}


/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    
    float minS = 0;
    float maxS = 0;
    float minT = 0;
    float maxT = 0;
    if (_atlas != nil) {
        MBEGlyphDescriptor *glyphInfo = _atlas.glyphDescriptors[0];
        minS = glyphInfo.topLeftTexCoord.x;
        maxS = glyphInfo.bottomRightTexCoord.x;
        minT = glyphInfo.topLeftTexCoord.y;
        maxT = glyphInfo.bottomRightTexCoord.y;
    }
    else if (_atlasGenerator != nil) {
        GlyphDescriptor *glyphInfo = [_atlasGenerator glyphDescriptorAt:0];
        minS = glyphInfo.topLeftTexCoord.x;
        maxS = glyphInfo.bottomRightTexCoord.x;
        minT = glyphInfo.topLeftTexCoord.y;
        maxT = glyphInfo.bottomRightTexCoord.y;
    }

//    float value = 275;
    float valueX = _viewportSize.x * 0.95 / 2;
    float valueY = _viewportSize.y * 0.95 / 2;
    
    float aspect1 = valueY / valueX;
    float aspect2 = (float)_atlasGenerator.textureHeight / (float)_atlasGenerator.textureWidth;
    
    if (aspect1 < aspect2) {
        valueX = valueY / aspect2;
    }
    else {
        valueY = valueX * aspect2;
    }

//    AAPLVertex triangleVertices[] =
//    {
//        // 2D positions,    RGBA colors
//        { {  valueX / a,  -valueY }, { maxS, maxT} },
//        { { -valueX / a,  -valueY }, { minS, maxT} },
//        { { -valueX * a,   valueY }, { minS, minT} },
//        { { -valueX * a,   valueY }, { minS, minT} },
//        { {  valueX * a,   valueY }, { maxS, minT} },
//        { {  valueX / a,  -valueY }, { maxS, maxT} },
//    };
    
    CGSize drawableSize = view.drawableSize;
    if (self.depthTexture == nil || (self.depthTexture.width != drawableSize.width || self.depthTexture.height != drawableSize.height)) {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                              width:drawableSize.width
                                                                                             height:drawableSize.height
                                                                                          mipmapped:NO];
        descriptor.usage = MTLTextureUsageRenderTarget;
        descriptor.resourceOptions = MTLResourceStorageModePrivate;
        self.depthTexture = [_device newTextureWithDescriptor:descriptor];
        [self.depthTexture setLabel:@"Depth Texture"];
    }

    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {

        MTLClearColor MBEClearColor = { 1, 1, 1, 1 };
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDescriptor.colorAttachments[0].clearColor = MBEClearColor;
        
        renderPassDescriptor.depthAttachment.texture = self.depthTexture;
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
        renderPassDescriptor.depthAttachment.clearDepth = 1.0;

        [self updateUniforms];

        // Create a render command encoder so we can render into something
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to which we'll draw.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:_pipelineState];

        // We call -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:] to send data from our
        //   Application ObjC code here to our Metal 'vertexShader' function
        // This call has 3 arguments
        //   1) A pointer to the memory we want to pass to our shader
        //   2) The memory size of the data we want passed down
        //   3) An integer index which corresponds to the index of the buffer attribute qualifier
        //      of the argument in our 'vertexShader' function

        // You send a pointer to the `triangleVertices` array also and indicate its size
        // The `AAPLVertexInputIndexVertices` enum value corresponds to the `vertexArray`
        // argument in the `vertexShader` function because its buffer attribute also uses
        // the `AAPLVertexInputIndexVertices` enum value for its index
//        [renderEncoder setVertexBytes:triangleVertices
//                               length:sizeof(triangleVertices)
//                              atIndex:AAPLVertexInputIndexVertices];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:AAPLVertexInputIndexVertices];
        [renderEncoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:AAPLVertexInputIndexViewportSize];

        // You send a pointer to `_viewportSize` and also indicate its size
        // The `AAPLVertexInputIndexViewportSize` enum value corresponds to the
        // `viewportSizePointer` argument in the `vertexShader` function because its
        //  buffer attribute also uses the `AAPLVertexInputIndexViewportSize` enum value
        //  for its index
//        [renderEncoder setVertexBytes:&_viewportSize
//                               length:sizeof(_viewportSize)
//                              atIndex:AAPLVertexInputIndexViewportSize];

        [renderEncoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:self.fontTexture atIndex:0];
        [renderEncoder setFragmentSamplerState:self.sampler atIndex:0];

        // Draw the 3 vertices of our triangle
//        NSLog(@"%d", [self.indexBuffer length] / sizeof(uint16_t));
//        NSLog(@"hello");
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                  indexCount:[self.indexBuffer length] / sizeof(uint16_t)
                                   indexType:MTLIndexTypeUInt16
                                 indexBuffer:self.indexBuffer
                           indexBufferOffset:0];
//        for (int index = 0 ; index < maxCount * maxCount ; index++) {
//            [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
//                                      indexCount:6
//                                       indexType:MTLIndexTypeUInt16
//                                     indexBuffer:self.indexBuffer
//                               indexBufferOffset:index * 6];
////            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
////                              vertexStart:index * 6 + 0
////                              vertexCount:3];
////            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
////                              vertexStart:index * 6 + 3
////                              vertexCount:3];
//        }
        
        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

@end
