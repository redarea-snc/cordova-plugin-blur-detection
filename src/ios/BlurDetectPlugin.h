#import <Cordova/CDVPlugin.h>

@interface BlurDetectPlugin : CDVPlugin

- (void)checkImage:(CDVInvokedUrlCommand*)command;

@end
