#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "PickleballTrackerModule.h"

@interface PickleballTrackerModule (StandaloneAPI)
- (void)initCamera:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)startPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)stopPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)takePhoto:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)startRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)stopRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)exportVideoWithOverlay:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
@end

@interface ViewController ()
@property (nonatomic, strong) PickleballTrackerModule *tracker;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSString *currentSessionId;
@property (nonatomic, assign) BOOL isPreviewing;
@property (nonatomic, assign) BOOL isRecording;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    self.tracker = [[PickleballTrackerModule alloc] init];

    [self buildInterface];
    [self setStatusText:@"Ready"];
}

- (void)buildInterface {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Pickleball Camera Standalone";
    titleLabel.font = [UIFont boldSystemFontOfSize:24.0];
    titleLabel.numberOfLines = 0;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor darkGrayColor];
    self.statusLabel.numberOfLines = 0;

    NSArray<UIButton *> *buttons = @[
        [self buttonWithTitle:@"Init + Preview" action:@selector(onInitPreviewTapped)],
        [self buttonWithTitle:@"Take Photo" action:@selector(onTakePhotoTapped)],
        [self buttonWithTitle:@"Start Recording" action:@selector(onStartRecordingTapped)],
        [self buttonWithTitle:@"Stop Recording + Export" action:@selector(onStopRecordingTapped)],
        [self buttonWithTitle:@"Stop Preview" action:@selector(onStopPreviewTapped)]
    ];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.alignment = UIStackViewAlignmentFill;

    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.88];
    panel.layer.cornerRadius = 14.0;

    [panel addSubview:titleLabel];
    [panel addSubview:self.statusLabel];
    [panel addSubview:stack];

    [self.view addSubview:panel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [panel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [panel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16.0],
        [titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:16.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],

        [stack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:16.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-16.0]
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
    button.backgroundColor = [UIColor colorWithRed:0.13 green:0.42 blue:0.93 alpha:1.0];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.layer.cornerRadius = 10.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)onInitPreviewTapped {
    [self prepareCameraIfNeededWithCompletion:^(BOOL ok) {
        if (ok) {
            [self setStatusText:@"Preview started"];
        }
    }];
}

- (void)onTakePhotoTapped {
    __weak typeof(self) weakSelf = self;
    [self prepareCameraIfNeededWithCompletion:^(BOOL ok) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !ok) {
            return;
        }

        [self.tracker takePhoto:@{} callback:^(NSDictionary *result, BOOL keepAlive) {
            [self handleResult:result success:^(NSDictionary *payload) {
                NSString *photoPath = [payload[@"photoFilePath"] isKindOfClass:[NSString class]] ? payload[@"photoFilePath"] : @"";
                [self setStatusText:[NSString stringWithFormat:@"Photo saved: %@", photoPath.length > 0 ? photoPath : @"(unknown path)"]];
            }];
        }];
    }];
}

- (void)onStartRecordingTapped {
    if (self.isRecording) {
        [self setStatusText:@"Recording already in progress"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self prepareCameraIfNeededWithCompletion:^(BOOL ok) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !ok) {
            return;
        }

        [self.tracker startRecording:@{ @"trackBall": @YES } callback:^(NSDictionary *result, BOOL keepAlive) {
            [self handleResult:result success:^(NSDictionary *payload) {
                self.isRecording = YES;
                NSString *sessionId = [payload[@"sessionId"] isKindOfClass:[NSString class]] ? payload[@"sessionId"] : @"";
                self.currentSessionId = sessionId;
                [self setStatusText:[NSString stringWithFormat:@"Recording started (session: %@)", sessionId.length > 0 ? sessionId : @"n/a"]];
            }];
        }];
    }];
}

- (void)onStopRecordingTapped {
    if (!self.isRecording) {
        [self setStatusText:@"No active recording"];
        return;
    }

    NSString *sessionId = self.currentSessionId ?: @"";
    __weak typeof(self) weakSelf = self;
    [self.tracker stopRecording:@{ @"sessionId": sessionId } callback:^(NSDictionary *result, BOOL keepAlive) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self handleResult:result success:^(NSDictionary *payload) {
            self.isRecording = NO;
            NSString *resolvedSessionId = [payload[@"sessionId"] isKindOfClass:[NSString class]] ? payload[@"sessionId"] : sessionId;
            self.currentSessionId = resolvedSessionId;
            [self setStatusText:@"Recording stopped. Exporting trail overlay..."];

            [self.tracker exportVideoWithOverlay:@{ @"sessionId": resolvedSessionId ?: @"" } callback:^(NSDictionary *exportResult, BOOL keepAliveInner) {
                [self handleResult:exportResult success:^(NSDictionary *exportPayload) {
                    NSString *outputPath = [exportPayload[@"outputVideoFilePath"] isKindOfClass:[NSString class]] ? exportPayload[@"outputVideoFilePath"] : @"";
                    [self setStatusText:[NSString stringWithFormat:@"Export complete: %@", outputPath.length > 0 ? outputPath : @"(unknown path)"]];
                }];
            }];
        }];
    }];
}

- (void)onStopPreviewTapped {
    [self.tracker stopPreview:@{} callback:^(NSDictionary *result, BOOL keepAlive) {
        [self handleResult:result success:^(NSDictionary *payload) {
            self.isPreviewing = NO;
            [self setStatusText:@"Preview stopped"];
        }];
    }];
}

- (void)prepareCameraIfNeededWithCompletion:(void (^)(BOOL ok))completion {
    if (self.isPreviewing) {
        if (completion) {
            completion(YES);
        }
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self ensurePermissions:^(BOOL granted) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (!granted) {
            [self setStatusText:@"Camera and microphone access are required"];
            if (completion) {
                completion(NO);
            }
            return;
        }

        [self.tracker initCamera:@{} callback:^(NSDictionary *initResult, BOOL keepAlive) {
            [self handleResult:initResult success:^(NSDictionary *payload) {
                [self.tracker startPreview:@{ @"autoRotate": @YES } callback:^(NSDictionary *previewResult, BOOL keepAliveInner) {
                    [self handleResult:previewResult success:^(NSDictionary *previewPayload) {
                        self.isPreviewing = YES;
                        if (completion) {
                            completion(YES);
                        }
                    }];
                }];
            }];
        }];
    }];
}

- (void)ensurePermissions:(void (^)(BOOL granted))completion {
    dispatch_group_t group = dispatch_group_create();
    __block BOOL cameraGranted = NO;
    __block BOOL micGranted = NO;

    dispatch_group_enter(group);
    [self requestAccessForMediaType:AVMediaTypeVideo completion:^(BOOL granted) {
        cameraGranted = granted;
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [self requestAccessForMediaType:AVMediaTypeAudio completion:^(BOOL granted) {
        micGranted = granted;
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(cameraGranted && micGranted);
        }
    });
}

- (void)requestAccessForMediaType:(AVMediaType)mediaType completion:(void (^)(BOOL granted))completion {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if (status == AVAuthorizationStatusAuthorized) {
        completion(YES);
        return;
    }

    if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted);
            });
        }];
        return;
    }

    completion(NO);
}

- (void)handleResult:(NSDictionary *)result success:(void (^)(NSDictionary *payload))successBlock {
    NSDictionary *payload = [result isKindOfClass:[NSDictionary class]] ? result : @{};
    NSString *error = [payload[@"error"] isKindOfClass:[NSString class]] ? payload[@"error"] : @"";
    if (error.length > 0) {
        [self setStatusText:[NSString stringWithFormat:@"Error: %@", error]];
        return;
    }

    if (successBlock) {
        successBlock(payload);
    }
}

- (void)setStatusText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"Status: %@", text ?: @""];
    });
}

@end
