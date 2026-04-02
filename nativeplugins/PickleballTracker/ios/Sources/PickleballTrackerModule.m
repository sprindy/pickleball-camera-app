#import "PickleballTrackerModule.h"

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <math.h>
#import <Photos/Photos.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>

static NSString *const kPickleballTrackingEvent = @"PickleballTrackingUpdate";
static NSString *const kPickleballRecordingFinishedEvent = @"PickleballRecordingFinished";
static NSInteger const kTrailWindowPoints = 30;
static NSTimeInterval const kTemporaryLossThreshold = 0.3;
static NSTimeInterval const kResetLossThreshold = 1.0;
static CGFloat const kTrackingSmoothingAlpha = 0.6;
static CGFloat const kOutlierDistanceThreshold = 0.28;

static NSString *const kRecordingStateIdle = @"idle";
static NSString *const kRecordingStateRecording = @"recording";
static NSString *const kRecordingStateProcessingExport = @"processing_export";
static NSString *const kRecordingStateReviewReady = @"review_ready";
static NSString *const kRecordingStateError = @"error";

static NSString *const kTrackingStateNotStarted = @"not_started";
static NSString *const kTrackingStateSearching = @"searching";
static NSString *const kTrackingStateTracking = @"tracking";
static NSString *const kTrackingStateTemporarilyLost = @"temporarily_lost";
static NSString *const kTrackingStateLost = @"lost";

@interface PickleballTrackerModule () <AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) CAShapeLayer *trailLayer;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) dispatch_queue_t visionQueue;

@property (nonatomic, strong) VNSequenceRequestHandler *visionHandler;
@property (nonatomic, strong) VNDetectTrajectoriesRequest *trajectoryRequest;
@property (nonatomic, assign) BOOL isProcessingVision;

@property (nonatomic, strong) NSMutableArray<NSValue *> *liveTrailPoints;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *recordingSessions;
@property (nonatomic, strong) NSMutableDictionary *activeRecordingSession;

@property (nonatomic, copy) UniModuleKeepAliveCallback pendingPhotoCallback;
@property (nonatomic, copy) UniModuleKeepAliveCallback pendingStopCallback;

@property (nonatomic, assign) BOOL autoRotateEnabled;
@property (nonatomic, assign) BOOL orientationObserverInstalled;
@property (nonatomic, assign) BOOL trackBall;
@property (nonatomic, assign) BOOL hasRecordingStartTime;
@property (nonatomic, assign) Float64 recordingStartSeconds;
@property (nonatomic, assign) NSTimeInterval lastTrackingEventTime;
@property (nonatomic, assign) NSTimeInterval lastDetectedRelativeTime;
@property (nonatomic, assign) NSUInteger frameIndex;
@property (nonatomic, assign) CGPoint previousSmoothedPoint;
@property (nonatomic, assign) BOOL hasPreviousSmoothedPoint;
@property (nonatomic, copy) NSString *recordingState;
@property (nonatomic, copy) NSString *trackingState;
@end

@implementation PickleballTrackerModule

UNI_EXPORT_METHOD(@selector(initCamera:callback:))
UNI_EXPORT_METHOD(@selector(startPreview:callback:))
UNI_EXPORT_METHOD(@selector(stopPreview:callback:))
UNI_EXPORT_METHOD(@selector(takePhoto:callback:))
UNI_EXPORT_METHOD(@selector(startRecording:callback:))
UNI_EXPORT_METHOD(@selector(stopRecording:callback:))
UNI_EXPORT_METHOD(@selector(getRecordingStatus:callback:))
UNI_EXPORT_METHOD(@selector(onTrackingUpdate:callback:))
UNI_EXPORT_METHOD(@selector(onRecordingFinished:callback:))
UNI_EXPORT_METHOD(@selector(exportVideoWithOverlay:callback:))

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionQueue = dispatch_queue_create("com.openclaw.pickleball.camera.session", DISPATCH_QUEUE_SERIAL);
        _visionQueue = dispatch_queue_create("com.openclaw.pickleball.camera.vision", DISPATCH_QUEUE_SERIAL);
        _liveTrailPoints = [NSMutableArray array];
        _recordingSessions = [NSMutableDictionary dictionary];
        _autoRotateEnabled = YES;
        _trackBall = YES;
        _lastTrackingEventTime = 0;
        _lastDetectedRelativeTime = -1;
        _frameIndex = 0;
        _hasPreviousSmoothedPoint = NO;
        _recordingState = kRecordingStateIdle;
        _trackingState = kTrackingStateNotStarted;
    }
    return self;
}

- (void)dealloc {
    [self uninstallOrientationObserver];
    if (self.captureSession.isRunning) {
        [self.captureSession stopRunning];
    }
}

#pragma mark - Exported API

- (void)initCamera:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSError *error = nil;
        if (![self ensureCaptureSessionConfigured:&error]) {
            [self replyError:[self errorMessage:error fallback:@"Failed to configure camera session"] callback:callback];
            return;
        }

        [self installOrientationObserverIfNeeded];
        [self startSessionIfNeeded];
        [self replySuccess:@{ @"ready": @YES } callback:callback];
    });
}

- (void)startPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    if ([options isKindOfClass:[NSDictionary class]]) {
        NSNumber *autoRotate = options[@"autoRotate"];
        if ([autoRotate isKindOfClass:[NSNumber class]]) {
            self.autoRotateEnabled = autoRotate.boolValue;
        }
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSError *error = nil;
        if (![self ensureCaptureSessionConfigured:&error]) {
            [self replyError:[self errorMessage:error fallback:@"Failed to configure camera session"] callback:callback];
            return;
        }
        [self startSessionIfNeeded];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *hostView = [self hostView];
            if (!hostView) {
                [self replyError:@"Unable to attach preview layer" callback:callback];
                return;
            }

            [self ensurePreviewLayerInHostView:hostView];
            [self refreshPreviewFrameAndOrientation];
            [self replySuccess:@{ @"previewing": @YES } callback:callback];
        });
    });
}

- (void)stopPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (self.movieOutput.isRecording) {
            [self.movieOutput stopRecording];
        }

        if (self.captureSession.isRunning) {
            [self.captureSession stopRunning];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.previewLayer removeFromSuperlayer];
            [self.trailLayer removeFromSuperlayer];
            [self.liveTrailPoints removeAllObjects];
            self.previewLayer = nil;
            self.trailLayer = nil;
            self.recordingState = kRecordingStateIdle;
            self.trackingState = kTrackingStateNotStarted;
            [self replySuccess:@{ @"previewing": @NO } callback:callback];
        });
    });
}

- (void)takePhoto:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    if (self.pendingPhotoCallback) {
        [self replyError:@"Photo capture already in progress" callback:callback];
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSError *error = nil;
        if (![self ensureCaptureSessionConfigured:&error]) {
            [self replyError:[self errorMessage:error fallback:@"Camera unavailable"] callback:callback];
            return;
        }
        [self startSessionIfNeeded];

        AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
        AVCaptureConnection *connection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoOrientationSupported) {
            connection.videoOrientation = [self currentVideoOrientation];
        }

        self.pendingPhotoCallback = callback;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.photoOutput capturePhotoWithSettings:settings delegate:self];
        });
    });
}

- (void)startRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    BOOL trackBall = YES;
    if ([options isKindOfClass:[NSDictionary class]]) {
        NSNumber *trackBallValue = options[@"trackBall"];
        if ([trackBallValue isKindOfClass:[NSNumber class]]) {
            trackBall = trackBallValue.boolValue;
        }
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (self.movieOutput.isRecording) {
            [self replyError:@"Recording already in progress" callback:callback];
            return;
        }

        NSError *error = nil;
        if (![self ensureCaptureSessionConfigured:&error]) {
            [self replyError:[self errorMessage:error fallback:@"Camera unavailable"] callback:callback];
            return;
        }
        [self startSessionIfNeeded];

        NSString *timestamp = [self timestampString];
        NSString *sessionId = [NSString stringWithFormat:@"session_%@", timestamp];
        NSURL *rawURL = [self mediaFileURLWithName:[NSString stringWithFormat:@"video_raw_%@.mp4", timestamp]];
        if (!rawURL) {
            [self replyError:@"Unable to allocate raw video path" callback:callback];
            return;
        }

        [[NSFileManager defaultManager] removeItemAtURL:rawURL error:nil];

        long long nowMs = (long long)llround([[NSDate date] timeIntervalSince1970] * 1000.0);
        NSMutableDictionary *session = [@{
            @"id": sessionId,
            @"sessionId": sessionId,
            @"timestamp": timestamp,
            @"videoFilePath": rawURL.path ?: @"",
            @"rawVideoPath": rawURL.path ?: @"",
            @"outputVideoFilePath": @"",
            @"trailVideoPath": @"",
            @"startedAt": @(nowMs),
            @"endedAt": @0,
            @"videoWidth": @0,
            @"videoHeight": @0,
            @"fps": @30,
            @"trackPoints": [NSMutableArray array]
        } mutableCopy];

        self.recordingSessions[sessionId] = session;
        self.activeRecordingSession = session;
        self.trackBall = trackBall;
        self.hasRecordingStartTime = NO;
        self.recordingStartSeconds = 0;
        self.lastTrackingEventTime = 0;
        self.lastDetectedRelativeTime = -1;
        self.frameIndex = 0;
        self.hasPreviousSmoothedPoint = NO;
        self.recordingState = kRecordingStateRecording;
        self.trackingState = kTrackingStateSearching;

        [self configureTrajectoryRequest];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.liveTrailPoints removeAllObjects];
            self.trailLayer.path = nil;
            [self refreshPreviewFrameAndOrientation];
        });

        AVCaptureConnection *movieConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        if (movieConnection.isVideoOrientationSupported) {
            movieConnection.videoOrientation = [self currentVideoOrientation];
        }

        [self.movieOutput startRecordingToOutputFileURL:rawURL recordingDelegate:self];
        [self replySuccess:@{
            @"sessionId": sessionId,
            @"videoFilePath": rawURL.path ?: @"",
            @"recordingState": self.recordingState,
            @"trackingState": self.trackingState
        } callback:callback];
    });
}

- (void)stopRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    NSString *requestedSessionId = @"";
    if ([options isKindOfClass:[NSDictionary class]]) {
        id sessionId = options[@"sessionId"];
        if ([sessionId isKindOfClass:[NSString class]]) {
            requestedSessionId = (NSString *)sessionId;
        }
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (self.pendingStopCallback) {
            [self replyError:@"Another stop request is in progress" callback:callback];
            return;
        }

        NSMutableDictionary *session = self.activeRecordingSession;
        if (!session || (requestedSessionId.length > 0 && ![session[@"sessionId"] isEqualToString:requestedSessionId])) {
            if (requestedSessionId.length > 0) {
                session = self.recordingSessions[requestedSessionId];
            }
            if (!session) {
                [self replyError:@"No recording session found" callback:callback];
                return;
            }
        }

        if (!self.movieOutput.isRecording) {
            [self replySuccess:@{
                @"sessionId": session[@"sessionId"] ?: @"",
                @"videoFilePath": session[@"videoFilePath"] ?: session[@"rawVideoPath"] ?: @"",
                @"recordingState": self.recordingState ?: kRecordingStateIdle,
                @"trackingState": self.trackingState ?: kTrackingStateNotStarted
            } callback:callback];
            return;
        }

        self.pendingStopCallback = callback;
        [self.movieOutput stopRecording];
    });
}

- (void)getRecordingStatus:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    NSMutableDictionary *payload = [@{
        @"recordingState": self.recordingState ?: kRecordingStateIdle,
        @"trackingState": self.trackingState ?: kTrackingStateNotStarted,
        @"isRecording": @(self.movieOutput.isRecording),
        @"sessionId": self.activeRecordingSession[@"sessionId"] ?: @""
    } mutableCopy];

    if (self.activeRecordingSession) {
        payload[@"session"] = [self.activeRecordingSession copy];
    }
    [self replySuccess:payload callback:callback];
}

- (void)onTrackingUpdate:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    [self replySuccess:@{ @"subscribed": @YES } callback:callback];
}

- (void)onRecordingFinished:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    [self replySuccess:@{ @"subscribed": @YES } callback:callback];
}

- (void)exportVideoWithOverlay:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    NSString *sessionId = @"";
    if ([options isKindOfClass:[NSDictionary class]]) {
        id value = options[@"sessionId"];
        if ([value isKindOfClass:[NSString class]]) {
            sessionId = (NSString *)value;
        }
    }

    NSMutableDictionary *session = nil;
    if (sessionId.length > 0) {
        session = self.recordingSessions[sessionId];
    }
    if (!session && self.activeRecordingSession) {
        session = self.activeRecordingSession;
    }
    if (!session) {
        [self replyError:@"Recording session not found" callback:callback];
        return;
    }
    self.recordingState = kRecordingStateProcessingExport;

    NSString *rawPath = [session[@"videoFilePath"] isKindOfClass:[NSString class]] ? session[@"videoFilePath"] : @"";
    if (rawPath.length == 0) {
        rawPath = [session[@"rawVideoPath"] isKindOfClass:[NSString class]] ? session[@"rawVideoPath"] : @"";
    }
    if (rawPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:rawPath]) {
        self.recordingState = kRecordingStateError;
        [self replyError:@"Raw video file is missing" callback:callback];
        return;
    }

    NSArray<NSDictionary *> *points = [session[@"trackPoints"] isKindOfClass:[NSArray class]] ? session[@"trackPoints"] : @[];
    if (points.count == 0) {
        [self finalizeVideoForSession:session
                           outputPath:rawPath
                             hasTrail:NO
                              warning:nil
                             callback:callback];
        return;
    }

    NSString *timestamp = [session[@"timestamp"] isKindOfClass:[NSString class]] ? session[@"timestamp"] : @"";
    if (timestamp.length == 0) {
        timestamp = [self timestampString];
    }

    NSURL *trailURL = [self mediaFileURLWithName:[NSString stringWithFormat:@"video_trail_%@.mp4", timestamp]];
    if (!trailURL) {
        [self finalizeVideoForSession:session
                           outputPath:rawPath
                             hasTrail:NO
                              warning:@"Unable to allocate export path. Kept raw recording."
                             callback:callback];
        return;
    }
    [[NSFileManager defaultManager] removeItemAtURL:trailURL error:nil];

    NSURL *rawURL = [NSURL fileURLWithPath:rawPath];
    AVAsset *asset = [AVAsset assetWithURL:rawURL];

    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        [self finalizeVideoForSession:session
                           outputPath:rawPath
                             hasTrail:NO
                              warning:@"Video track missing. Kept raw recording."
                             callback:callback];
        return;
    }
    session[@"videoWidth"] = @(llround(videoTrack.naturalSize.width));
    session[@"videoHeight"] = @(llround(videoTrack.naturalSize.height));

    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                  preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError *insertError = nil;
    CMTimeRange fullRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    if (![compositionVideoTrack insertTimeRange:fullRange ofTrack:videoTrack atTime:kCMTimeZero error:&insertError]) {
        NSString *warning = [NSString stringWithFormat:@"Export composition failed: %@", [self errorMessage:insertError fallback:@"unknown error"]];
        [self finalizeVideoForSession:session
                           outputPath:rawPath
                             hasTrail:NO
                              warning:warning
                             callback:callback];
        return;
    }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (audioTrack) {
        AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:fullRange ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    }

    CGAffineTransform preferredTransform = videoTrack.preferredTransform;
    CGSize naturalSize = videoTrack.naturalSize;
    CGRect transformedRect = CGRectApplyAffineTransform(CGRectMake(0, 0, naturalSize.width, naturalSize.height), preferredTransform);
    CGSize renderSize = CGSizeMake(fabs(transformedRect.size.width), fabs(transformedRect.size.height));

    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = fullRange;

    AVMutableVideoCompositionLayerInstruction *layerInstruction =
        [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    [layerInstruction setTransform:preferredTransform atTime:kCMTimeZero];
    instruction.layerInstructions = @[layerInstruction];

    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[instruction];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderSize = renderSize;

    [self attachTrailAnimationForPoints:points
                               duration:CMTimeGetSeconds(asset.duration)
                             renderSize:renderSize
                     toVideoComposition:videoComposition];

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition
                                                                             presetName:AVAssetExportPresetHighestQuality];
    if (!exportSession) {
        [self finalizeVideoForSession:session
                           outputPath:rawPath
                             hasTrail:NO
                              warning:@"Unable to start export. Kept raw recording."
                             callback:callback];
        return;
    }

    exportSession.outputURL = trailURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.videoComposition = videoComposition;

    __weak typeof(self) weakSelf = self;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted: {
                session[@"trailVideoPath"] = trailURL.path ?: @"";
                [self finalizeVideoForSession:session
                                   outputPath:trailURL.path ?: rawPath
                                     hasTrail:YES
                                      warning:nil
                                     callback:callback];
                break;
            }
            case AVAssetExportSessionStatusFailed: {
                NSString *warning = [NSString stringWithFormat:@"Overlay export failed: %@. Kept raw recording.",
                                     [self errorMessage:exportSession.error fallback:@"unknown error"]];
                [self finalizeVideoForSession:session
                                   outputPath:rawPath
                                     hasTrail:NO
                                      warning:warning
                                     callback:callback];
                break;
            }
            case AVAssetExportSessionStatusCancelled: {
                [self finalizeVideoForSession:session
                                   outputPath:rawPath
                                     hasTrail:NO
                                      warning:@"Overlay export cancelled. Kept raw recording."
                                     callback:callback];
                break;
            }
            default: {
                [self finalizeVideoForSession:session
                                   outputPath:rawPath
                                     hasTrail:NO
                                      warning:@"Overlay export did not complete. Kept raw recording."
                                     callback:callback];
                break;
            }
        }
    }];
}

#pragma mark - AVCapture delegates

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    UniModuleKeepAliveCallback callback = self.pendingPhotoCallback;
    self.pendingPhotoCallback = nil;

    if (!callback) {
        return;
    }

    if (error) {
        [self replyError:[self errorMessage:error fallback:@"Photo capture failed"] callback:callback];
        return;
    }

    NSData *imageData = [photo fileDataRepresentation];
    if (imageData.length == 0) {
        [self replyError:@"Photo data is empty" callback:callback];
        return;
    }

    NSURL *photoURL = [self mediaFileURLWithName:[NSString stringWithFormat:@"photo_%@.jpg", [self timestampString]]];
    if (!photoURL) {
        [self replyError:@"Unable to allocate photo path" callback:callback];
        return;
    }

    NSError *writeError = nil;
    if (![imageData writeToURL:photoURL options:NSDataWritingAtomic error:&writeError]) {
        [self replyError:[self errorMessage:writeError fallback:@"Failed to save photo"] callback:callback];
        return;
    }

    [self saveFileToPhotosAtPath:photoURL.path
                         isVideo:NO
                      completion:^(BOOL saved, NSString *warning) {
        NSMutableDictionary *payload = [@{
            @"photoFilePath": photoURL.path ?: @"",
            @"savedToPhotos": @(saved)
        } mutableCopy];

        if (warning.length > 0) {
            payload[@"saveWarning"] = warning;
        }

        [self replySuccess:payload callback:callback];
    }];
}

- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections {
    // Start response is returned immediately from startRecording.
}

- (void)captureOutput:(AVCaptureFileOutput *)output
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
       fromConnections:(NSArray<AVCaptureConnection *> *)connections
                 error:(NSError *)error {
    UniModuleKeepAliveCallback stopCallback = self.pendingStopCallback;
    self.pendingStopCallback = nil;

    NSMutableDictionary *session = self.activeRecordingSession;
    self.activeRecordingSession = nil;
    self.trackBall = NO;
    self.hasRecordingStartTime = NO;
    self.isProcessingVision = NO;
    self.hasPreviousSmoothedPoint = NO;
    self.lastDetectedRelativeTime = -1;
    self.frameIndex = 0;
    self.trackingState = kTrackingStateNotStarted;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.liveTrailPoints removeAllObjects];
        self.trailLayer.path = nil;
    });

    if (error) {
        self.recordingState = kRecordingStateError;
        if (stopCallback) {
            [self replyError:[self errorMessage:error fallback:@"Failed to stop recording"] callback:stopCallback];
        }
        return;
    }

    NSString *sessionId = [session[@"sessionId"] isKindOfClass:[NSString class]] ? session[@"sessionId"] : @"";
    NSString *rawPath = outputFileURL.path ?: @"";
    if (session) {
        long long endedAtMs = (long long)llround([[NSDate date] timeIntervalSince1970] * 1000.0);
        session[@"endedAt"] = @(endedAtMs);
        session[@"videoFilePath"] = rawPath;
        session[@"rawVideoPath"] = rawPath;
        if (sessionId.length > 0) {
            self.recordingSessions[sessionId] = session;
        }
    }

    self.recordingState = kRecordingStateIdle;

    NSDictionary *payload = @{
        @"sessionId": sessionId,
        @"videoFilePath": rawPath,
        @"recordingState": self.recordingState,
        @"trackingState": self.trackingState
    };

    [self emitEvent:kPickleballRecordingFinishedEvent payload:payload];

    if (stopCallback) {
        [self replySuccess:payload callback:stopCallback];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (!self.movieOutput.isRecording || !self.trackBall || !self.activeRecordingSession) {
        return;
    }

    if (@available(iOS 14.0, *)) {
        if (self.isProcessingVision || !self.trajectoryRequest || !self.visionHandler) {
            return;
        }

        self.isProcessingVision = YES;

        CMTime sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        Float64 sampleSeconds = CMTimeGetSeconds(sampleTime);
        if (!self.hasRecordingStartTime && sampleSeconds >= 0) {
            self.recordingStartSeconds = sampleSeconds;
            self.hasRecordingStartTime = YES;
        }

        NSError *error = nil;
        CGImagePropertyOrientation orientation = [self visionOrientationForVideoOrientation:[self currentVideoOrientation]];
        BOOL ok = [self.visionHandler performRequests:@[self.trajectoryRequest]
                                     onCMSampleBuffer:sampleBuffer
                                          orientation:orientation
                                                error:&error];

        BOOL detected = NO;
        CGFloat confidence = 0;
        CGPoint normalizedPoint = CGPointZero;

        if (ok && !error) {
            VNTrajectoryObservation *observation = [self strongestTrajectory];
            if (observation && observation.detectedPoints.count > 0) {
                VNPoint *point = observation.detectedPoints.lastObject;
                normalizedPoint = point.location;
                confidence = observation.confidence;
                detected = (confidence >= 0.12);
            }
        }

        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (imageBuffer && self.activeRecordingSession) {
            size_t width = CVPixelBufferGetWidth(imageBuffer);
            size_t height = CVPixelBufferGetHeight(imageBuffer);
            self.activeRecordingSession[@"videoWidth"] = @(width);
            self.activeRecordingSession[@"videoHeight"] = @(height);
        }

        NSTimeInterval relativeTime = 0;
        if (self.hasRecordingStartTime && sampleSeconds >= self.recordingStartSeconds) {
            relativeTime = sampleSeconds - self.recordingStartSeconds;
        }
        self.frameIndex += 1;

        if (detected) {
            CGPoint smoothed = [self smoothedPointForDetectedPoint:normalizedPoint];
            self.lastDetectedRelativeTime = relativeTime;
            self.trackingState = kTrackingStateTracking;
            NSDictionary *pointPayload = [self appendDetectedPoint:smoothed
                                                        confidence:confidence
                                                            atTime:relativeTime
                                                        frameIndex:self.frameIndex];
            [self emitTrackingPayloadForPoint:pointPayload detected:YES atTime:relativeTime];
        } else {
            [self updateTrackingStateForMissAtTime:relativeTime];
            [self emitTrackingPayloadForPoint:nil detected:NO atTime:relativeTime];
        }

        self.isProcessingVision = NO;
    }
}

#pragma mark - Internals

- (BOOL)ensureCaptureSessionConfigured:(NSError **)error {
    if (self.captureSession && self.videoInput && self.photoOutput && self.movieOutput && self.videoDataOutput) {
        return YES;
    }

    AVCaptureSession *session = self.captureSession ?: [[AVCaptureSession alloc] init];

    [session beginConfiguration];
    if ([session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        session.sessionPreset = AVCaptureSessionPresetHigh;
    }

    AVCaptureDevice *rearCamera = [self rearCameraDevice];
    if (!rearCamera) {
        if (error) {
            *error = [NSError errorWithDomain:@"PickleballTracker"
                                         code:-100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Rear camera not available"}];
        }
        [session commitConfiguration];
        return NO;
    }

    [self lockRearCameraNoZoom:rearCamera];

    if (!self.videoInput) {
        NSError *videoError = nil;
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:rearCamera error:&videoError];
        if (!videoInput || videoError) {
            if (error) {
                *error = videoError ?: [NSError errorWithDomain:@"PickleballTracker"
                                                            code:-101
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Unable to create rear camera input"}];
            }
            [session commitConfiguration];
            return NO;
        }
        if ([session canAddInput:videoInput]) {
            [session addInput:videoInput];
            self.videoInput = videoInput;
        }
    }

    if (!self.audioInput) {
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if (audioDevice) {
            AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
            if (audioInput && [session canAddInput:audioInput]) {
                [session addInput:audioInput];
                self.audioInput = audioInput;
            }
        }
    }

    if (!self.photoOutput) {
        AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([session canAddOutput:photoOutput]) {
            [session addOutput:photoOutput];
            self.photoOutput = photoOutput;
        }
    }

    if (!self.movieOutput) {
        AVCaptureMovieFileOutput *movieOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([session canAddOutput:movieOutput]) {
            [session addOutput:movieOutput];
            self.movieOutput = movieOutput;
        }
    }

    if (!self.videoDataOutput) {
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        videoDataOutput.videoSettings = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        };

        if ([session canAddOutput:videoDataOutput]) {
            [session addOutput:videoDataOutput];
            [videoDataOutput setSampleBufferDelegate:self queue:self.visionQueue];
            self.videoDataOutput = videoDataOutput;
        }
    }

    self.captureSession = session;
    [session commitConfiguration];
    [self applyCurrentVideoOrientation];

    return YES;
}

- (void)startSessionIfNeeded {
    if (!self.captureSession.isRunning) {
        [self.captureSession startRunning];
    }
}

- (void)ensurePreviewLayerInHostView:(UIView *)hostView {
    if (!self.previewLayer) {
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    } else {
        self.previewLayer.session = self.captureSession;
    }

    if (self.previewLayer.superlayer != hostView.layer) {
        [self.previewLayer removeFromSuperlayer];
        [hostView.layer insertSublayer:self.previewLayer atIndex:0];
    }

    if (!self.trailLayer) {
        self.trailLayer = [CAShapeLayer layer];
        self.trailLayer.strokeColor = [self trailColor].CGColor;
        self.trailLayer.fillColor = UIColor.clearColor.CGColor;
        self.trailLayer.lineWidth = 5.0;
        self.trailLayer.lineJoin = kCALineJoinRound;
        self.trailLayer.lineCap = kCALineCapRound;
    }

    if (self.trailLayer.superlayer != hostView.layer) {
        [self.trailLayer removeFromSuperlayer];
        [hostView.layer addSublayer:self.trailLayer];
    }
}

- (void)refreshPreviewFrameAndOrientation {
    UIView *hostView = [self hostView];
    if (!hostView) {
        return;
    }

    CGRect bounds = hostView.bounds;
    if (CGRectIsEmpty(bounds)) {
        bounds = UIScreen.mainScreen.bounds;
    }

    self.previewLayer.frame = bounds;
    self.trailLayer.frame = bounds;
    [self applyCurrentVideoOrientation];
}

- (void)applyCurrentVideoOrientation {
    AVCaptureVideoOrientation orientation = [self currentVideoOrientation];

    AVCaptureConnection *previewConnection = self.previewLayer.connection;
    if (previewConnection.isVideoOrientationSupported) {
        previewConnection.videoOrientation = orientation;
    }

    AVCaptureConnection *movieConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
    if (movieConnection.isVideoOrientationSupported) {
        movieConnection.videoOrientation = orientation;
    }

    AVCaptureConnection *videoDataConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (videoDataConnection.isVideoOrientationSupported) {
        videoDataConnection.videoOrientation = orientation;
    }
}

- (void)configureTrajectoryRequest {
    if (@available(iOS 14.0, *)) {
        self.visionHandler = [[VNSequenceRequestHandler alloc] init];
        self.trajectoryRequest = [[VNDetectTrajectoriesRequest alloc] initWithFrameAnalysisSpacing:CMTimeMake(1, 30)
                                                                                   trajectoryLength:6
                                                                                  completionHandler:nil];
        self.trajectoryRequest.objectMinimumNormalizedRadius = 0.002;
        self.trajectoryRequest.objectMaximumNormalizedRadius = 0.06;
        self.isProcessingVision = NO;
    }
}

- (VNTrajectoryObservation *)strongestTrajectory API_AVAILABLE(ios(14.0)) {
    NSArray<VNTrajectoryObservation *> *results = self.trajectoryRequest.results;
    if (results.count == 0) {
        return nil;
    }

    VNTrajectoryObservation *best = nil;
    for (VNTrajectoryObservation *candidate in results) {
        if (!best || candidate.confidence > best.confidence) {
            best = candidate;
        }
    }
    return best;
}

- (CGPoint)smoothedPointForDetectedPoint:(CGPoint)point {
    point.x = MIN(MAX(point.x, 0.0), 1.0);
    point.y = MIN(MAX(point.y, 0.0), 1.0);

    if (!self.hasPreviousSmoothedPoint) {
        self.previousSmoothedPoint = point;
        self.hasPreviousSmoothedPoint = YES;
        return point;
    }

    CGFloat dx = point.x - self.previousSmoothedPoint.x;
    CGFloat dy = point.y - self.previousSmoothedPoint.y;
    CGFloat distance = hypot(dx, dy);

    CGFloat alpha = kTrackingSmoothingAlpha;
    if (distance > kOutlierDistanceThreshold) {
        alpha = 0.22;
    }

    CGPoint smoothed = CGPointMake(alpha * point.x + (1.0 - alpha) * self.previousSmoothedPoint.x,
                                   alpha * point.y + (1.0 - alpha) * self.previousSmoothedPoint.y);
    self.previousSmoothedPoint = smoothed;
    return smoothed;
}

- (NSDictionary *)appendDetectedPoint:(CGPoint)normalizedPoint
                           confidence:(CGFloat)confidence
                               atTime:(NSTimeInterval)relativeTime
                           frameIndex:(NSUInteger)frameIndex {
    NSMutableArray *points = [self.activeRecordingSession[@"trackPoints"] isKindOfClass:[NSMutableArray class]]
        ? self.activeRecordingSession[@"trackPoints"]
        : [NSMutableArray array];
    self.activeRecordingSession[@"trackPoints"] = points;

    long long startedAtMs = [self.activeRecordingSession[@"startedAt"] respondsToSelector:@selector(longLongValue)]
        ? [self.activeRecordingSession[@"startedAt"] longLongValue]
        : (long long)llround([[NSDate date] timeIntervalSince1970] * 1000.0);
    long long timestampMs = startedAtMs + (long long)llround(MAX(relativeTime, 0) * 1000.0);

    NSDictionary *entry = @{
        @"timestampMs": @(timestampMs),
        @"frameIndex": @(frameIndex),
        @"x": @(normalizedPoint.x),
        @"y": @(normalizedPoint.y),
        @"confidence": @(confidence),
        @"t": @(MAX(relativeTime, 0))
    };

    [points addObject:entry];

    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *hostView = [self hostView];
        if (!hostView || !self.trailLayer) {
            return;
        }

        CGPoint viewPoint = CGPointMake(normalizedPoint.x * CGRectGetWidth(hostView.bounds),
                                        (1.0 - normalizedPoint.y) * CGRectGetHeight(hostView.bounds));
        [self.liveTrailPoints addObject:[NSValue valueWithCGPoint:viewPoint]];
        if (self.liveTrailPoints.count > kTrailWindowPoints) {
            NSRange range = NSMakeRange(0, self.liveTrailPoints.count - kTrailWindowPoints);
            [self.liveTrailPoints removeObjectsInRange:range];
        }

        UIBezierPath *path = [self smoothedPathForCGPointValues:self.liveTrailPoints];
        self.trailLayer.path = path.CGPath;
    });

    return entry;
}

- (void)updateTrackingStateForMissAtTime:(NSTimeInterval)relativeTime {
    if (self.lastDetectedRelativeTime < 0) {
        self.trackingState = kTrackingStateSearching;
        return;
    }

    NSTimeInterval elapsed = MAX(0, relativeTime - self.lastDetectedRelativeTime);
    if (elapsed <= kTemporaryLossThreshold) {
        self.trackingState = kTrackingStateTemporarilyLost;
        return;
    }

    if (elapsed <= kResetLossThreshold) {
        self.trackingState = kTrackingStateLost;
        return;
    }

    self.trackingState = kTrackingStateSearching;
    self.hasPreviousSmoothedPoint = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.liveTrailPoints removeAllObjects];
        self.trailLayer.path = nil;
    });
}

- (NSArray<NSDictionary *> *)recentTrackPayloadPoints {
    NSArray *points = [self.activeRecordingSession[@"trackPoints"] isKindOfClass:[NSArray class]]
        ? self.activeRecordingSession[@"trackPoints"]
        : @[];
    if (points.count == 0) {
        return @[];
    }

    NSInteger start = MAX(0, (NSInteger)points.count - kTrailWindowPoints);
    NSMutableArray<NSDictionary *> *recent = [NSMutableArray array];
    for (NSInteger idx = start; idx < points.count; idx += 1) {
        NSDictionary *item = [points[idx] isKindOfClass:[NSDictionary class]] ? points[idx] : @{};
        CGFloat x = [item[@"x"] respondsToSelector:@selector(doubleValue)] ? [item[@"x"] doubleValue] : 0;
        CGFloat y = [item[@"y"] respondsToSelector:@selector(doubleValue)] ? [item[@"y"] doubleValue] : 0;
        [recent addObject:@{ @"x": @(x), @"y": @(y) }];
    }
    return recent;
}

- (void)emitTrackingPayloadForPoint:(NSDictionary *)currentPoint detected:(BOOL)detected atTime:(NSTimeInterval)relativeTime {
    NSMutableDictionary *payload = [@{
        @"sessionId": self.activeRecordingSession[@"sessionId"] ?: @"",
        @"state": self.trackingState ?: kTrackingStateSearching,
        @"detected": @(detected),
        @"t": @(MAX(relativeTime, 0)),
        @"recentPoints": [self recentTrackPayloadPoints]
    } mutableCopy];

    if (currentPoint) {
        payload[@"x"] = currentPoint[@"x"] ?: @0;
        payload[@"y"] = currentPoint[@"y"] ?: @0;
        payload[@"confidence"] = currentPoint[@"confidence"] ?: @0;
        payload[@"timestampMs"] = currentPoint[@"timestampMs"] ?: @0;
        payload[@"frameIndex"] = currentPoint[@"frameIndex"] ?: @0;
        payload[@"currentPoint"] = @{
            @"x": currentPoint[@"x"] ?: @0,
            @"y": currentPoint[@"y"] ?: @0,
            @"confidence": currentPoint[@"confidence"] ?: @0
        };
    } else {
        payload[@"confidence"] = @0;
        payload[@"currentPoint"] = @{};
    }

    [self emitTrackingPayload:payload];
}

- (void)emitTrackingPayload:(NSDictionary *)payload {
    NSTimeInterval now = CACurrentMediaTime();
    NSString *state = [payload[@"state"] isKindOfClass:[NSString class]] ? payload[@"state"] : @"";
    BOOL activelyTracking = [state isEqualToString:kTrackingStateTracking];
    NSTimeInterval minInterval = activelyTracking ? 0.03 : 0.12;

    if ((now - self.lastTrackingEventTime) < minInterval) {
        return;
    }

    self.lastTrackingEventTime = now;
    [self emitEvent:kPickleballTrackingEvent payload:payload];
}

- (void)attachTrailAnimationForPoints:(NSArray<NSDictionary *> *)points
                             duration:(NSTimeInterval)duration
                           renderSize:(CGSize)renderSize
                   toVideoComposition:(AVMutableVideoComposition *)videoComposition {
    CALayer *parentLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, renderSize.width, renderSize.height);

    CALayer *videoLayer = [CALayer layer];
    videoLayer.frame = parentLayer.frame;
    [parentLayer addSublayer:videoLayer];

    CAShapeLayer *trailLayer = [CAShapeLayer layer];
    trailLayer.frame = parentLayer.frame;
    trailLayer.strokeColor = [self trailColor].CGColor;
    trailLayer.fillColor = UIColor.clearColor.CGColor;
    trailLayer.lineWidth = 5.0;
    trailLayer.lineJoin = kCALineJoinRound;
    trailLayer.lineCap = kCALineCapRound;
    [parentLayer addSublayer:trailLayer];

    NSMutableArray *pathValues = [NSMutableArray array];
    NSMutableArray<NSNumber *> *keyTimes = [NSMutableArray array];

    if (duration <= 0) {
        duration = 0.1;
    }

    [pathValues addObject:(__bridge_transfer id)CGPathCreateMutable()];
    [keyTimes addObject:@0.0];

    long long startTimestampMs = [points.firstObject[@"timestampMs"] respondsToSelector:@selector(longLongValue)]
        ? [points.firstObject[@"timestampMs"] longLongValue]
        : 0;

    for (NSInteger idx = 0; idx < points.count; idx += 1) {
        NSDictionary *pointInfo = points[idx];
        NSTimeInterval t = [pointInfo[@"t"] respondsToSelector:@selector(doubleValue)] ? [pointInfo[@"t"] doubleValue] : -1;
        if (t < 0 && [pointInfo[@"timestampMs"] respondsToSelector:@selector(longLongValue)] && startTimestampMs > 0) {
            long long ts = [pointInfo[@"timestampMs"] longLongValue];
            t = MAX(0, (NSTimeInterval)(ts - startTimestampMs) / 1000.0);
        }
        if (t < 0) {
            t = 0;
        }
        CGFloat normalizedTime = (CGFloat)(t / duration);
        normalizedTime = MAX(0.0, MIN(1.0, normalizedTime));

        CGPathRef pathRef = [self copiedPathForPointWindow:points upToIndex:idx renderSize:renderSize];
        [pathValues addObject:(__bridge_transfer id)pathRef];
        [keyTimes addObject:@(normalizedTime)];
    }

    NSNumber *lastKeyTime = keyTimes.lastObject ?: @0;
    if (lastKeyTime.doubleValue < 1.0 && pathValues.count > 0) {
        [pathValues addObject:pathValues.lastObject];
        [keyTimes addObject:@1.0];
    }

    CAKeyframeAnimation *pathAnimation = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    pathAnimation.values = pathValues;
    pathAnimation.keyTimes = keyTimes;
    pathAnimation.duration = duration;
    pathAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
    pathAnimation.fillMode = kCAFillModeForwards;
    pathAnimation.removedOnCompletion = NO;
    pathAnimation.calculationMode = kCAAnimationDiscrete;

    [trailLayer addAnimation:pathAnimation forKey:@"pickleballTrailPath"];

    videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool
        videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer
                                                                 inLayer:parentLayer];
}

- (CGPathRef)copiedPathForPointWindow:(NSArray<NSDictionary *> *)points
                            upToIndex:(NSInteger)index
                           renderSize:(CGSize)renderSize CF_RETURNS_RETAINED {
    NSInteger start = MAX(0, index - (kTrailWindowPoints - 1));
    NSMutableArray<NSValue *> *windowPoints = [NSMutableArray array];
    for (NSInteger idx = start; idx <= index; idx += 1) {
        NSDictionary *pointInfo = points[idx];
        CGFloat x = [pointInfo[@"x"] respondsToSelector:@selector(doubleValue)] ? [pointInfo[@"x"] doubleValue] : 0;
        CGFloat y = [pointInfo[@"y"] respondsToSelector:@selector(doubleValue)] ? [pointInfo[@"y"] doubleValue] : 0;

        CGPoint p = CGPointMake(x * renderSize.width, (1.0 - y) * renderSize.height);
        [windowPoints addObject:[NSValue valueWithCGPoint:p]];
    }

    UIBezierPath *path = [self smoothedPathForCGPointValues:windowPoints];
    return CGPathCreateCopy(path.CGPath);
}

- (UIBezierPath *)smoothedPathForCGPointValues:(NSArray<NSValue *> *)pointValues {
    UIBezierPath *path = [UIBezierPath bezierPath];
    if (pointValues.count == 0) {
        return path;
    }

    CGPoint first = pointValues.firstObject.CGPointValue;
    [path moveToPoint:first];

    if (pointValues.count == 1) {
        return path;
    }

    if (pointValues.count == 2) {
        [path addLineToPoint:pointValues.lastObject.CGPointValue];
        return path;
    }

    for (NSInteger idx = 1; idx < pointValues.count; idx += 1) {
        CGPoint prev = pointValues[idx - 1].CGPointValue;
        CGPoint current = pointValues[idx].CGPointValue;
        CGPoint mid = CGPointMake((prev.x + current.x) * 0.5, (prev.y + current.y) * 0.5);
        [path addQuadCurveToPoint:mid controlPoint:prev];
    }
    [path addLineToPoint:pointValues.lastObject.CGPointValue];
    return path;
}

- (void)finalizeVideoForSession:(NSMutableDictionary *)session
                     outputPath:(NSString *)outputPath
                       hasTrail:(BOOL)hasTrail
                        warning:(NSString *)warning
                       callback:(UniModuleKeepAliveCallback)callback {
    NSString *sessionId = [session[@"sessionId"] isKindOfClass:[NSString class]] ? session[@"sessionId"] : @"";
    NSString *rawPath = [session[@"videoFilePath"] isKindOfClass:[NSString class]] ? session[@"videoFilePath"] : @"";
    if (rawPath.length == 0) {
        rawPath = [session[@"rawVideoPath"] isKindOfClass:[NSString class]] ? session[@"rawVideoPath"] : @"";
    }

    if (outputPath.length == 0) {
        outputPath = rawPath;
    }
    session[@"outputVideoFilePath"] = outputPath ?: @"";
    session[@"trailVideoPath"] = outputPath ?: @"";
    self.recordingState = kRecordingStateReviewReady;

    [self saveFileToPhotosAtPath:outputPath
                         isVideo:YES
                      completion:^(BOOL saved, NSString *saveWarning) {
        NSMutableDictionary *payload = [@{
            @"sessionId": sessionId,
            @"session": [session copy],
            @"outputVideoFilePath": outputPath ?: @"",
            @"videoFilePath": rawPath ?: @"",
            @"hasTrail": @(hasTrail),
            @"savedToPhotos": @(saved),
            @"usedRawFallback": @(!hasTrail),
            @"recordingState": self.recordingState ?: kRecordingStateReviewReady,
            @"trackingState": self.trackingState ?: kTrackingStateNotStarted
        } mutableCopy];

        NSString *combinedWarning = [self combinedWarning:warning with:saveWarning];
        if (combinedWarning.length > 0) {
            payload[@"warning"] = combinedWarning;
        }

        [self replySuccess:payload callback:callback];
    }];
}

- (void)saveFileToPhotosAtPath:(NSString *)path
                       isVideo:(BOOL)isVideo
                    completion:(void (^)(BOOL saved, NSString *warning))completion {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (completion) {
            completion(NO, @"Local media file is missing.");
        }
        return;
    }

    [self ensurePhotoLibraryAuthorization:^(BOOL granted, NSString *reason) {
        if (!granted) {
            if (completion) {
                completion(NO, reason.length > 0 ? reason : @"Photo Library permission denied.");
            }
            return;
        }

        NSURL *fileURL = [NSURL fileURLWithPath:path];
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (isVideo) {
                [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            } else {
                [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:fileURL];
            }
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            NSString *warning = nil;
            if (!success) {
                warning = [self errorMessage:error fallback:@"Could not save to Photos."];
            }
            if (completion) {
                completion(success, warning);
            }
        }];
    }];
}

- (void)ensurePhotoLibraryAuthorization:(void (^)(BOOL granted, NSString *reason))completion {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            completion(YES, nil);
            return;
        }
        if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
            completion(NO, @"Photo Library access denied. Media kept locally.");
            return;
        }

        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus newStatus) {
            BOOL granted = (newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited);
            NSString *reason = granted ? nil : @"Photo Library access denied. Media kept locally.";
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted, reason);
            });
        }];
        return;
    }

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        completion(YES, nil);
        return;
    }
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        completion(NO, @"Photo Library access denied. Media kept locally.");
        return;
    }

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
        BOOL granted = (newStatus == PHAuthorizationStatusAuthorized);
        NSString *reason = granted ? nil : @"Photo Library access denied. Media kept locally.";
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted, reason);
        });
    }];
}

- (NSString *)combinedWarning:(NSString *)w1 with:(NSString *)w2 {
    NSString *a = [w1 isKindOfClass:[NSString class]] ? w1 : @"";
    NSString *b = [w2 isKindOfClass:[NSString class]] ? w2 : @"";

    if (a.length > 0 && b.length > 0) {
        return [NSString stringWithFormat:@"%@ %@", a, b];
    }
    if (a.length > 0) {
        return a;
    }
    if (b.length > 0) {
        return b;
    }
    return @"";
}

- (UIColor *)trailColor {
    return [UIColor colorWithRed:1.0 green:(212.0 / 255.0) blue:0 alpha:1.0];
}

- (NSURL *)mediaFileURLWithName:(NSString *)name {
    if (name.length == 0) {
        return nil;
    }

    NSError *error = nil;
    NSURL *directoryURL = [self mediaDirectoryURL:&error];
    if (!directoryURL || error) {
        return nil;
    }

    return [directoryURL URLByAppendingPathComponent:name];
}

- (NSURL *)mediaDirectoryURL:(NSError **)error {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                   inDomains:NSUserDomainMask] firstObject];
    if (!documentsURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"PickleballTracker"
                                         code:-200
                                     userInfo:@{NSLocalizedDescriptionKey: @"Documents directory unavailable"}];
        }
        return nil;
    }

    NSURL *mediaDirectory = [documentsURL URLByAppendingPathComponent:@"pickleball_media" isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:mediaDirectory.path]) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:mediaDirectory
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:error]) {
            return nil;
        }
    }
    return mediaDirectory;
}

- (NSString *)timestampString {
    long long millis = (long long)llround([[NSDate date] timeIntervalSince1970] * 1000.0);
    return [NSString stringWithFormat:@"%lld", millis];
}

- (UIView *)hostView {
    @try {
        id instance = [self currentUniInstance];
        if (instance) {
            id viewController = [instance valueForKey:@"viewController"];
            if ([viewController isKindOfClass:[UIViewController class]]) {
                UIView *vcView = ((UIViewController *)viewController).view;
                if (vcView) {
                    return vcView;
                }
            }
        }
    } @catch (NSException *exception) {
        // Fallback to key window below.
    }

    UIWindow *window = [self activeWindow];
    return window;
}

- (UIWindow *)activeWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
}

- (AVCaptureDevice *)rearCameraDevice {
    AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession
        discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                              mediaType:AVMediaTypeVideo
                               position:AVCaptureDevicePositionBack];
    return discovery.devices.firstObject;
}

- (void)lockRearCameraNoZoom:(AVCaptureDevice *)device {
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        CGFloat minZoom = MAX(1.0, device.minAvailableVideoZoomFactor);
        CGFloat maxZoom = MAX(minZoom, device.maxAvailableVideoZoomFactor);
        device.videoZoomFactor = MIN(MAX(1.0, minZoom), maxZoom);
        [device unlockForConfiguration];
    }
}

- (void)installOrientationObserverIfNeeded {
    if (self.orientationObserverInstalled) {
        return;
    }
    self.orientationObserverInstalled = YES;

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)uninstallOrientationObserver {
    if (!self.orientationObserverInstalled) {
        return;
    }
    self.orientationObserverInstalled = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (void)onDeviceOrientationChanged:(NSNotification *)notification {
    if (!self.autoRotateEnabled) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshPreviewFrameAndOrientation];
    });
}

- (AVCaptureVideoOrientation)currentVideoOrientation {
    UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;
    switch (orientation) {
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationPortrait:
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

- (CGImagePropertyOrientation)visionOrientationForVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    switch (videoOrientation) {
        case AVCaptureVideoOrientationLandscapeRight:
            return kCGImagePropertyOrientationDown;
        case AVCaptureVideoOrientationLandscapeLeft:
            return kCGImagePropertyOrientationUp;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            return kCGImagePropertyOrientationLeft;
        case AVCaptureVideoOrientationPortrait:
        default:
            return kCGImagePropertyOrientationRight;
    }
}

- (void)emitEvent:(NSString *)eventName payload:(NSDictionary *)payload {
    if (eventName.length == 0) {
        return;
    }

    NSDictionary *safePayload = payload ?: @{};
    dispatch_async(dispatch_get_main_queue(), ^{
        id instance = [self currentUniInstance];
        SEL eventSelector = NSSelectorFromString(@"fireGlobalEvent:params:");
        if (instance && [instance respondsToSelector:eventSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [instance performSelector:eventSelector withObject:eventName withObject:safePayload];
#pragma clang diagnostic pop
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:eventName object:nil userInfo:safePayload];
    });
}

- (id)currentUniInstance {
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"uniInstance")]) {
            return [self valueForKey:@"uniInstance"];
        }
    } @catch (NSException *exception) {
        return nil;
    }
    return nil;
}

- (void)replySuccess:(NSDictionary *)payload callback:(UniModuleKeepAliveCallback)callback {
    if (!callback) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        callback(payload ?: @{}, NO);
    });
}

- (void)replyError:(NSString *)message callback:(UniModuleKeepAliveCallback)callback {
    if (!callback) {
        return;
    }

    NSDictionary *payload = @{ @"error": message.length > 0 ? message : @"Unknown error" };
    dispatch_async(dispatch_get_main_queue(), ^{
        callback(payload, NO);
    });
}

- (NSString *)errorMessage:(NSError *)error fallback:(NSString *)fallback {
    if (error.localizedDescription.length > 0) {
        return error.localizedDescription;
    }
    if (fallback.length > 0) {
        return fallback;
    }
    return @"Unknown error";
}

@end
