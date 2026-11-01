#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const NKStatusPath =
    @"/var/mobile/Library/Preferences/com.nk.topstatus.status";

static const NSTimeInterval NKPollInterval = 0.35;
static const NSTimeInterval NKAutoHideSeconds = 15.0;

@interface NKTopStatusManager : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *rootController;
@property (nonatomic, strong) UIVisualEffectView *pill;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *track;
@property (nonatomic, strong) UIView *progress;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *lastModified;
@property (nonatomic, strong) NSDate *lastUpdate;
@property (nonatomic, assign) NSInteger percent;
@property (nonatomic, assign) BOOL visible;
+ (instancetype)shared;
- (void)start;
@end

@implementation NKTopStatusManager

+ (instancetype)shared {
    static NKTopStatusManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [NKTopStatusManager new];
    });
    return manager;
}

- (UIWindowScene *)activeWindowScene API_AVAILABLE(ios(13.0)) {
    NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;

    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        if (scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }

    for (UIScene *scene in scenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            return (UIWindowScene *)scene;
        }
    }

    return nil;
}

- (void)ensureWindow {
    if (self.window) {
        return;
    }

    CGRect bounds = UIScreen.mainScreen.bounds;
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeWindowScene];

        if (scene) {
            window = [[UIWindow alloc] initWithWindowScene:scene];
            window.frame = bounds;
        }
    }

    if (!window) {
        window = [[UIWindow alloc] initWithFrame:bounds];
    }

    window.backgroundColor = UIColor.clearColor;
    window.windowLevel = UIWindowLevelStatusBar + 100.0;
    window.userInteractionEnabled = NO;

    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.clearColor;
    window.rootViewController = controller;

    UIBlurEffect *blur =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];

    UIVisualEffectView *pill =
        [[UIVisualEffectView alloc] initWithEffect:blur];

    pill.clipsToBounds = YES;
    pill.layer.cornerRadius = 20.0;
    pill.alpha = 0.0;
    pill.userInteractionEnabled = NO;

    UILabel *label = [UILabel new];
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:13.0
                                   weight:UIFontWeightSemibold];
    label.numberOfLines = 1;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.75;
    label.userInteractionEnabled = NO;

    UIView *track = [UIView new];
    track.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.16];
    track.layer.cornerRadius = 1.0;
    track.userInteractionEnabled = NO;

    UIView *progress = [UIView new];
    progress.backgroundColor = UIColor.whiteColor;
    progress.layer.cornerRadius = 1.0;
    progress.userInteractionEnabled = NO;

    [pill.contentView addSubview:label];
    [pill.contentView addSubview:track];
    [pill.contentView addSubview:progress];
    [controller.view addSubview:pill];

    self.window = window;
    self.rootController = controller;
    self.pill = pill;
    self.label = label;
    self.track = track;
    self.progress = progress;
    self.percent = 0;
    self.visible = NO;

    window.hidden = NO;

    [self layoutOverlay];
}

- (CGFloat)topInset {
    CGFloat top = self.window.safeAreaInsets.top;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.window.windowScene;
        CGFloat statusHeight =
            scene.statusBarManager.statusBarFrame.size.height;

        if (statusHeight > top) {
            top = statusHeight;
        }
    }

    if (top < 20.0) {
        top = 20.0;
    }

    return top;
}

- (void)layoutOverlay {
    if (!self.window || !self.pill) {
        return;
    }

    CGRect bounds = UIScreen.mainScreen.bounds;

    if (!CGRectEqualToRect(self.window.frame, bounds)) {
        self.window.frame = bounds;
    }

    CGFloat width = MIN(CGRectGetWidth(bounds) - 24.0, 330.0);
    CGFloat height = 40.0;
    CGFloat x = (CGRectGetWidth(bounds) - width) / 2.0;

    // Ngay dưới vùng status bar/notch, cách mép an toàn 4pt.
    CGFloat y = [self topInset] + 4.0;

    self.pill.frame = CGRectMake(x, y, width, height);

    self.label.frame =
        CGRectMake(12.0, 5.0, width - 24.0, 27.0);

    self.track.frame =
        CGRectMake(12.0, height - 5.0, width - 24.0, 2.0);

    CGFloat fraction =
        MAX(0.0, MIN(1.0, ((CGFloat)self.percent / 100.0)));

    self.progress.frame =
        CGRectMake(12.0,
                   height - 5.0,
                   (width - 24.0) * fraction,
                   2.0);
}

- (void)showPercent:(NSInteger)percent message:(NSString *)message {
    [self ensureWindow];

    if (!self.window) {
        return;
    }

    percent = MAX(0, MIN(100, percent));
    self.percent = percent;
    self.lastUpdate = [NSDate date];

    NSString *symbol = percent >= 100 ? @"✓" : @"●";

    self.label.text =
        [NSString stringWithFormat:@"%@  %ld%%  %@",
         symbol,
         (long)percent,
         message ?: @""];

    [self layoutOverlay];

    CGFloat fullWidth = CGRectGetWidth(self.track.frame);
    CGFloat targetWidth =
        fullWidth * ((CGFloat)percent / 100.0);

    [UIView animateWithDuration:0.22
                     animations:^{
        CGRect f = self.progress.frame;
        f.size.width = targetWidth;
        self.progress.frame = f;
    }];

    if (!self.visible) {
        self.visible = YES;
        self.pill.transform =
            CGAffineTransformMakeScale(0.96, 0.96);

        [UIView animateWithDuration:0.20
                         animations:^{
            self.pill.alpha = 1.0;
            self.pill.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.pill.alpha = 1.0;
    }
}

- (void)hide {
    if (!self.visible || !self.pill) {
        return;
    }

    self.visible = NO;

    [UIView animateWithDuration:0.18
                     animations:^{
        self.pill.alpha = 0.0;
        self.pill.transform =
            CGAffineTransformMakeScale(0.98, 0.98);
    } completion:^(BOOL finished) {
        self.pill.transform = CGAffineTransformIdentity;
    }];
}

- (void)consumeStatus:(NSString *)content {
    if (!content) {
        return;
    }

    NSString *trimmed =
        [content stringByTrimmingCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (trimmed.length == 0) {
        return;
    }

    if ([trimmed caseInsensitiveCompare:@"HIDE"] == NSOrderedSame) {
        [self hide];
        return;
    }

    NSRange sep = [trimmed rangeOfString:@"|"];

    if (sep.location == NSNotFound) {
        return;
    }

    NSString *percentString =
        [trimmed substringToIndex:sep.location];

    NSString *message =
        [trimmed substringFromIndex:sep.location + 1];

    NSInteger percent = percentString.integerValue;

    [self showPercent:percent message:message];
}

- (void)poll {
    [self ensureWindow];
    [self layoutOverlay];

    NSError *error = nil;
    NSDictionary *attrs =
        [[NSFileManager defaultManager]
         attributesOfItemAtPath:NKStatusPath
         error:&error];

    NSDate *modified =
        attrs[NSFileModificationDate];

    if (modified &&
        (!self.lastModified ||
         [modified compare:self.lastModified] == NSOrderedDescending)) {

        self.lastModified = modified;

        NSString *content =
            [NSString stringWithContentsOfFile:NKStatusPath
                                      encoding:NSUTF8StringEncoding
                                         error:nil];

        [self consumeStatus:content];
    }

    if (self.visible &&
        self.lastUpdate &&
        [[NSDate date] timeIntervalSinceDate:self.lastUpdate] >
            NKAutoHideSeconds) {

        [self hide];
    }
}

- (void)start {
    [self ensureWindow];

    if (self.timer) {
        return;
    }

    self.timer =
        [NSTimer scheduledTimerWithTimeInterval:NKPollInterval
                                         target:self
                                       selector:@selector(poll)
                                       userInfo:nil
                                        repeats:YES];

    [[NSRunLoop mainRunLoop]
     addTimer:self.timer
      forMode:NSRunLoopCommonModes];
}

@end

%ctor {
    @autoreleasepool {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(1.0 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                [[NKTopStatusManager shared] start];
            }
        );
    }
}
