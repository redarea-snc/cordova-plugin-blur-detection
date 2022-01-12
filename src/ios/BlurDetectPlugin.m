#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "BlurDetectPlugin.h"

@implementation BlurDetectPlugin

- (void)checkImage:(CDVInvokedUrlCommand*)command {
    NSString* config = [command argumentAtIndex:0];
    NSData *data = [config dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&e];
    NSString *imgPath = [dictionary objectForKey:@"uri"];

    [self.commandDelegate runInBackground:^{
        @autoreleasepool {
            NSLog(@"Reading contents of image %@", imgPath);
            UIImage *loadedImg = [UIImage imageWithContentsOfFile:imgPath];

            if(loadedImg == nil){
                NSLog(@"Image file %@ not available", imgPath);
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Image not available"] callbackId:command.callbackId];
                return;
            }

            //Code found here https://appleglitz.com/italy/rilevamento-della-nitidezza-dellimmagine-per-ios-in-objective-c/
            //Attenzione! la foto va convertita in scala di grigi, se no la trasformata di Laplace non funziona
            //Il codice completo è in questo thread: https://stackoverflow.com/questions/65834934/image-blur-detection-for-ios-in-objective-c
            // commento di Stephan Schlecht del 29/01/2021
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            id<MTLCommandQueue> queue = [device newCommandQueue];
            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];

            MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
            id<MTLTexture> sourceTexture = [textureLoader newTextureWithCGImage:loadedImg.CGImage options:nil error:nil];


            CGColorSpaceRef srcColorSpace = CGColorSpaceCreateDeviceRGB();
            CGColorSpaceRef dstColorSpace = CGColorSpaceCreateDeviceGray();
            CGColorConversionInfoRef conversionInfo = CGColorConversionInfoCreate(srcColorSpace, dstColorSpace);
            MPSImageConversion *conversion = [[MPSImageConversion alloc] initWithDevice:device
                                                                               srcAlpha:MPSAlphaTypeAlphaIsOne
                                                                              destAlpha:MPSAlphaTypeAlphaIsOne
                                                                        backgroundColor:nil
                                                                         conversionInfo:conversionInfo];
            MTLTextureDescriptor *grayTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Unorm
                                                                                                             width:sourceTexture.width
                                                                                                            height:sourceTexture.height
                                                                                                         mipmapped:false];
            grayTextureDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
            id<MTLTexture> grayTexture = [device newTextureWithDescriptor:grayTextureDescriptor];
            [conversion encodeToCommandBuffer:commandBuffer sourceTexture:sourceTexture destinationTexture:grayTexture];


            MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:grayTexture.pixelFormat
                                                                                                         width:sourceTexture.width
                                                                                                        height:sourceTexture.height
                                                                                                     mipmapped:false];
            textureDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
            id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];

            MPSImageLaplacian *imageKernel = [[MPSImageLaplacian alloc] initWithDevice:device];
            [imageKernel encodeToCommandBuffer:commandBuffer sourceTexture:grayTexture destinationTexture:texture];


            MPSImageStatisticsMeanAndVariance *meanAndVariance = [[MPSImageStatisticsMeanAndVariance alloc] initWithDevice:device];
            MTLTextureDescriptor *varianceTextureDescriptor = [MTLTextureDescriptor
                                                               texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                               width:2
                                                               height:1
                                                               mipmapped:NO];
            varianceTextureDescriptor.usage = MTLTextureUsageShaderWrite;
            id<MTLTexture> varianceTexture = [device newTextureWithDescriptor:varianceTextureDescriptor];
            [meanAndVariance encodeToCommandBuffer:commandBuffer sourceTexture:texture destinationTexture:varianceTexture];


            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];

            union {
                float f[2];
                unsigned char bytes[8];
            } u;

            MTLRegion region = MTLRegionMake2D(0, 0, 2, 1);
            [varianceTexture getBytes:u.bytes bytesPerRow:2 * 4 fromRegion:region mipmapLevel: 0];

            //NSLog(@"mean: %f", u.f[0] * 255);
            //NSLog(@"variance: %f", u.f[1] * 255 * 255);
            float variance = u.f[1] * 255 * 255;
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%f", variance]] callbackId:command.callbackId];
        }
    }];
}
@end
