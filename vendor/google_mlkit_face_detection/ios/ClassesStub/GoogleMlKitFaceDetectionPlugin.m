#import "GoogleMlKitFaceDetectionPlugin.h"

#define channelName @"google_mlkit_face_detector"
#define startFaceDetector @"vision#startFaceDetector"
#define closeFaceDetector @"vision#closeFaceDetector"

@implementation GoogleMlKitFaceDetectionPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:channelName
                                     binaryMessenger:[registrar messenger]];
    GoogleMlKitFaceDetectionPlugin* instance = [[GoogleMlKitFaceDetectionPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:startFaceDetector]) {
        result(@[]);
    } else if ([call.method isEqualToString:closeFaceDetector]) {
        result(NULL);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
