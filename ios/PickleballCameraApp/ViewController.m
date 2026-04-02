#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

#import "PickleballTrackerModule.h"

typedef NS_ENUM(NSInteger, CaptureMode) {
    CaptureModePhoto = 0,
    CaptureModeVideo = 1
};

@interface PickleballTrackerModule (StandaloneAPI)
- (void)initCamera:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)startPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)stopPreview:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)takePhoto:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)startRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)stopRecording:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)getRecordingStatus:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
- (void)exportVideoWithOverlay:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback;
@end

@interface ViewController ()
@property (nonatomic, strong) PickleballTrackerModule *tracker;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *photoModeButton;
@property (nonatomic, strong) UIButton *videoModeButton;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIView *captureInnerView;

@property (nonatomic, assign) CaptureMode mode;
@property (nonatomic, assign) BOOL bootstrapped;
@property (nonatomic, assign) BOOL isReady;
@property (nonatomic, assign) BOOL isBusy;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, copy) NSString *currentSessionId;
@property (nonatomic, copy) NSString *lastRawVideoPath;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    self.tracker = [[PickleballTrackerModule alloc] init];
    self.mode = CaptureModePhoto;
    self.currentSessionId = @"";
    self.lastRawVideoPath = @"";

    [self buildInterface];
    [self registerForTrackerEvents];
    [self updateStatus:@"Initializing..."];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.bootstrapped) {
        self.bootstrapped = YES;
        [self bootstrapCamera];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.tracker stopPreview:@{} callback:nil];
}

- (void)buildInterface {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.layer.cornerRadius = 10.0;
    self.statusLabel.layer.masksToBounds = YES;

    UIView *modePill = [[UIView alloc] init];
    modePill.translatesAutoresizingMaskIntoConstraints = NO;
    modePill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    modePill.layer.cornerRadius = 20.0;
    modePill.layer.masksToBounds = YES;

    self.photoModeButton = [self modeButtonWithTitle:@"PHOTO" action:@selector(onPhotoModeTapped)];
    self.videoModeButton = [self modeButtonWithTitle:@"VIDEO" action:@selector(onVideoModeTapped)];

    UIStackView *modeStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.photoModeButton, self.videoModeButton]];
    modeStack.translatesAutoresizingMaskIntoConstraints = NO;
    modeStack.axis = UILayoutConstraintAxisHorizontal;
    modeStack.distribution = UIStackViewDistributionFillEqually;
    modeStack.spacing = 8.0;

    [modePill addSubview:modeStack];

    self.captureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.captureButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.captureButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16];
    self.captureButton.layer.cornerRadius = 40.0;
    self.captureButton.layer.borderColor = UIColor.whiteColor.CGColor;
    self.captureButton.layer.borderWidth = 5.0;
    [self.captureButton addTarget:self action:@selector(onCaptureTapped) forControlEvents:UIControlEventTouchUpInside];

    self.captureInnerView = [[UIView alloc] init];
    self.captureInnerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.captureInnerView.backgroundColor = UIColor.whiteColor;
    self.captureInnerView.layer.cornerRadius = 28.0;
    self.captureInnerView.layer.masksToBounds = YES;
    self.captureInnerView.userInteractionEnabled = NO;
    [self.captureButton addSubview:self.captureInnerView];

    [self.view addSubview:self.statusLabel];
    [self.view addSubview:modePill];
    [self.view addSubview:self.captureButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [self.statusLabel.heightAnchor constraintEqualToConstant:32.0],

        [modePill.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [modePill.bottomAnchor constraintEqualToAnchor:self.captureButton.topAnchor constant:-18.0],
        [modePill.widthAnchor constraintEqualToConstant:230.0],
        [modePill.heightAnchor constraintEqualToConstant:40.0],

        [modeStack.topAnchor constraintEqualToAnchor:modePill.topAnchor constant:4.0],
        [modeStack.bottomAnchor constraintEqualToAnchor:modePill.bottomAnchor constant:-4.0],
        [modeStack.leadingAnchor constraintEqualToAnchor:modePill.leadingAnchor constant:6.0],
        [modeStack.trailingAnchor constraintEqualToAnchor:modePill.trailingAnchor constant:-6.0],

        [self.captureButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.captureButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-18.0],
        [self.captureButton.widthAnchor constraintEqualToConstant:80.0],
        [self.captureButton.heightAnchor constraintEqualToConstant:80.0],

        [self.captureInnerView.centerXAnchor constraintEqualToAnchor:self.captureButton.centerXAnchor],
        [self.captureInnerView.centerYAnchor constraintEqualToAnchor:self.captureButton.centerYAnchor],
        [self.captureInnerView.widthAnchor constraintEqualToConstant:56.0],
        [self.captureInnerView.heightAnchor constraintEqualToConstant:56.0]
    ]];

    [self refreshControlStyles];
}

- (UIButton *)modeButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 14.0;
    button.layer.masksToBounds = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)registerForTrackerEvents {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onTrackingEvent:)
                                                 name:@"PickleballTrackingUpdate"
                                               object:nil];
}

- (void)onTrackingEvent:(NSNotification *)note {
    if (!self.isRecording) {
        return;
    }

    NSDictionary *payload = [note.userInfo isKindOfClass:[NSDictionary class]] ? note.userInfo : @{};
    NSString *state = [payload[@"state"] isKindOfClass:[NSString class]] ? payload[@"state"] : @"searching";
    if ([state isEqualToString:@"tracking"]) {
        [self updateStatus:@"Tracking ball..."];
        return;
    }
    if ([state isEqualToString:@"temporarily_lost"] || [state isEqualToString:@"lost"]) {
        [self updateStatus:@"Ball lost"];
        return;
    }
    [self updateStatus:@"Recording..."];
}

- (void)bootstrapCamera {
    __weak typeof(self) weakSelf = self;
    [self ensurePermissions:^(BOOL granted) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (!granted) {
            [self updateStatus:@"Permission required"];
            return;
        }

        [self.tracker initCamera:@{ @"position": @"rear", @"zoom": @NO } callback:^(NSDictionary *result, BOOL keepAlive) {
            [self handleResult:result success:^(NSDictionary *payload) {
                [self.tracker startPreview:@{
                    @"rearOnly": @YES,
                    @"autoRotate": @YES,
                    @"enableZoom": @NO
                } callback:^(NSDictionary *previewResult, BOOL keepAliveInner) {
                    [self handleResult:previewResult success:^(NSDictionary *previewPayload) {
                        self.isReady = YES;
                        [self updateStatus:@"Ready"];
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
    __block BOOL photosGranted = NO;

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

    dispatch_group_enter(group);
    [self requestPhotoLibraryAddAccess:^(BOOL granted) {
        photosGranted = granted;
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(cameraGranted && micGranted && photosGranted);
        }
    });
}

- (void)requestPhotoLibraryAddAccess:(void (^)(BOOL granted))completion {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            completion(YES);
            return;
        }
        if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
            completion(NO);
            return;
        }

        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus newStatus) {
            BOOL granted = (newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted);
            });
        }];
        return;
    }

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        completion(YES);
        return;
    }
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        completion(NO);
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
        BOOL granted = (newStatus == PHAuthorizationStatusAuthorized);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted);
        });
    }];
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

- (void)onPhotoModeTapped {
    if (self.isRecording || self.isBusy) {
        return;
    }
    self.mode = CaptureModePhoto;
    [self refreshControlStyles];
    [self updateStatus:@"Ready"];
}

- (void)onVideoModeTapped {
    if (self.isRecording || self.isBusy) {
        return;
    }
    self.mode = CaptureModeVideo;
    [self refreshControlStyles];
    [self updateStatus:@"Ready"];
}

- (void)onCaptureTapped {
    if (!self.isReady || self.isBusy) {
        return;
    }

    if (self.mode == CaptureModePhoto) {
        [self capturePhoto];
        return;
    }

    if (self.isRecording) {
        [self stopRecordingAndExport];
    } else {
        [self startRecording];
    }
}

- (void)capturePhoto {
    self.isBusy = YES;
    [self refreshControlStyles];
    [self updateStatus:@"Ready"];

    __weak typeof(self) weakSelf = self;
    [self.tracker takePhoto:@{} callback:^(NSDictionary *result, BOOL keepAlive) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isBusy = NO;
        [self refreshControlStyles];
        [self handleResult:result success:^(NSDictionary *payload) {
            NSString *warning = [payload[@"saveWarning"] isKindOfClass:[NSString class]] ? payload[@"saveWarning"] : @"";
            [self updateStatus:(warning.length > 0 ? warning : @"Saved")];
        }];
    }];
}

- (void)startRecording {
    self.isBusy = YES;
    [self refreshControlStyles];
    [self updateStatus:@"Recording..."];

    __weak typeof(self) weakSelf = self;
    [self.tracker startRecording:@{ @"trackBall": @YES } callback:^(NSDictionary *result, BOOL keepAlive) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isBusy = NO;
        [self handleResult:result success:^(NSDictionary *payload) {
            self.isRecording = YES;
            self.currentSessionId = [payload[@"sessionId"] isKindOfClass:[NSString class]] ? payload[@"sessionId"] : @"";
            self.lastRawVideoPath = [payload[@"videoFilePath"] isKindOfClass:[NSString class]] ? payload[@"videoFilePath"] : @"";
            [self refreshControlStyles];
            [self updateStatus:@"Recording..."];
        }];
    }];
}

- (void)stopRecordingAndExport {
    self.isBusy = YES;
    [self refreshControlStyles];
    [self updateStatus:@"Recording..."];

    NSString *sessionId = self.currentSessionId ?: @"";
    __weak typeof(self) weakSelf = self;
    [self.tracker stopRecording:@{ @"sessionId": sessionId } callback:^(NSDictionary *result, BOOL keepAlive) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self handleResult:result success:^(NSDictionary *payload) {
            self.currentSessionId = [payload[@"sessionId"] isKindOfClass:[NSString class]] ? payload[@"sessionId"] : sessionId;
            self.lastRawVideoPath = [payload[@"videoFilePath"] isKindOfClass:[NSString class]] ? payload[@"videoFilePath"] : self.lastRawVideoPath;
            [self updateStatus:@"Processing video..."];

            [self.tracker exportVideoWithOverlay:@{ @"sessionId": self.currentSessionId ?: @"" } callback:^(NSDictionary *exportResult, BOOL keepAliveInner) {
                self.isBusy = NO;
                self.isRecording = NO;
                [self refreshControlStyles];

                [self handleResult:exportResult success:^(NSDictionary *exportPayload) {
                    NSString *warning = [exportPayload[@"warning"] isKindOfClass:[NSString class]] ? exportPayload[@"warning"] : @"";
                    if (warning.length > 0) {
                        [self updateStatus:warning];
                    } else {
                        [self updateStatus:@"Saved"];
                    }
                }];
            }];
        }];
    }];
}

- (void)refreshControlStyles {
    UIColor *activeText = [UIColor colorWithRed:1.0 green:(212.0 / 255.0) blue:0 alpha:1.0];
    UIColor *inactiveText = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
    UIColor *inactiveBg = UIColor.clearColor;
    UIColor *activeBg = [[UIColor colorWithRed:1.0 green:(212.0 / 255.0) blue:0 alpha:1.0] colorWithAlphaComponent:0.16];

    BOOL photoActive = (self.mode == CaptureModePhoto);
    self.photoModeButton.backgroundColor = photoActive ? activeBg : inactiveBg;
    self.videoModeButton.backgroundColor = photoActive ? inactiveBg : activeBg;
    [self.photoModeButton setTitleColor:(photoActive ? activeText : inactiveText) forState:UIControlStateNormal];
    [self.videoModeButton setTitleColor:(photoActive ? inactiveText : activeText) forState:UIControlStateNormal];

    self.captureButton.alpha = (self.isBusy || !self.isReady) ? 0.55 : 1.0;
    self.captureButton.userInteractionEnabled = !(self.isBusy || !self.isReady);

    if (self.mode == CaptureModePhoto) {
        self.captureInnerView.backgroundColor = UIColor.whiteColor;
        self.captureInnerView.layer.cornerRadius = 28.0;
        for (NSLayoutConstraint *constraint in self.captureInnerView.constraints) {
            if (constraint.firstAttribute == NSLayoutAttributeWidth || constraint.firstAttribute == NSLayoutAttributeHeight) {
                constraint.constant = 56.0;
            }
        }
        return;
    }

    self.captureInnerView.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    CGFloat side = self.isRecording ? 30.0 : 56.0;
    CGFloat corner = self.isRecording ? 7.0 : 28.0;
    self.captureInnerView.layer.cornerRadius = corner;
    for (NSLayoutConstraint *constraint in self.captureInnerView.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeWidth || constraint.firstAttribute == NSLayoutAttributeHeight) {
            constraint.constant = side;
        }
    }
}

- (void)handleResult:(NSDictionary *)result success:(void (^)(NSDictionary *payload))successBlock {
    NSDictionary *payload = [result isKindOfClass:[NSDictionary class]] ? result : @{};
    NSString *error = [payload[@"error"] isKindOfClass:[NSString class]] ? payload[@"error"] : @"";
    if (error.length > 0) {
        self.isBusy = NO;
        [self refreshControlStyles];
        [self updateStatus:error];
        return;
    }

    if (successBlock) {
        successBlock(payload);
    }
}

- (void)updateStatus:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = text ?: @"";
    });
}

@end
