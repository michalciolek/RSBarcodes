//
//  RSScannerViewController.m
//  RSBarcodes
//
//  Created by R0CKSTAR on 12/19/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSScannerViewController.h"

#import "RSCornersView.h"

#import <AVFoundation/AVFoundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000

NSString *const AVMetadataObjectTypeFace = @"face";

#endif

@interface RSScannerViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession           *session;
@property (nonatomic, strong) AVCaptureDevice            *device;
@property (nonatomic, strong) AVCaptureDeviceInput       *input;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *layer;
@property (nonatomic, strong) AVCaptureMetadataOutput    *output;

@end

@implementation RSScannerViewController

#pragma mark - Private

- (void)__applicationWillEnterForeground:(NSNotification *)notification {
    [self __startRunning];
}

- (void)__applicationDidEnterBackground:(NSNotification *)notification {
    [self __stopRunning];
}

- (void)__handleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer {
    CGPoint tapPoint = [tapGestureRecognizer locationInView:self.view];
    CGPoint focusPoint= CGPointMake(tapPoint.x / self.view.bounds.size.width, tapPoint.y / self.view.bounds.size.height);
    
    if (!self.device
        || ![self.device isFocusPointOfInterestSupported]
        || ![self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        return;
    } else if ([self.device lockForConfiguration:nil]) {
        [self.device setFocusPointOfInterest:focusPoint];
        [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        [self.device unlockForConfiguration];
        
        if (self.isFocusMarkVisible) {
            self.highlightView.focusPoint = tapPoint;
        }
        
        if (self.tapGestureHandler) {
            self.tapGestureHandler(tapPoint);
        }
    }
}

- (void)__setup {
    self.isCornersVisible = YES;
    self.isBorderRectsVisible = NO;
    self.isFocusMarkVisible = YES;
    
    if (self.session) {
        return;
    }
    
    //OWN
    if(self.preferredCameraPosition)
    {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == self.preferredCameraPosition) {
                self.device = device;
            }
        }
    }
    else
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!self.device) {
            NSLog(@"No video camera on this device!");
            return;
        }
    }
    //OWN
    
    self.session = [[AVCaptureSession alloc] init];
    NSError *error = nil;
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    self.layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.layer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.layer];
    
    self.output = [[AVCaptureMetadataOutput alloc] init];
    dispatch_queue_t queue = dispatch_queue_create("com.pdq.RSBarcodes.metadata", 0);
    [self.output setMetadataObjectsDelegate:self queue:queue];
    if ([self.session canAddOutput:self.output]) {
        [self.session addOutput:self.output];
        if (!self.barcodeObjectTypes) {
            NSMutableArray *codeObjectTypes = [NSMutableArray arrayWithArray:self.output.availableMetadataObjectTypes];
            [codeObjectTypes removeObject:AVMetadataObjectTypeFace];
            self.barcodeObjectTypes = [NSArray arrayWithArray:codeObjectTypes];
        }
        self.output.metadataObjectTypes = self.barcodeObjectTypes;
    }
    
    [self.view bringSubviewToFront:self.highlightView];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(__handleTapGesture:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)__startRunning {
    if (self.session.isRunning) {
        return;
    }
    [self.session startRunning];
}

- (void)__stopRunning {
    if (!self.session.isRunning) {
        return;
    }
    [self.session stopRunning];
    
    self.highlightView.cornersArray = nil;
    self.highlightView.borderRectArray = nil;
    [self.highlightView setNeedsDisplay];
}

#pragma mark - View lifecycle

- (id)initWithCornerView:(BOOL)showCornerView controlView:(BOOL)showControlsView barcodesHandler:(RSBarcodesHandler)barcodesHandler {
    
    if(!self.highlightView && showCornerView)
    {
        RSCornersView *cornerView = [[RSCornersView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:cornerView];
        [self.view bringSubviewToFront:cornerView];
        
        self.highlightView = cornerView;
        
        self.isControlsVisible = showCornerView;
    }
    
    if(!self.controlsView && showControlsView)
    {
        UIView *controlsView = [[UIView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:controlsView];
        [self.view bringSubviewToFront:controlsView];
        
        self.controlsView = controlsView;
        self.isControlsVisible = showControlsView;
        
        [self updateView];
    }
    
    if (self) {
        self.barcodesHandler = barcodesHandler;
        
        self.tapGestureHandler = ^(CGPoint tapPoint) { };
    }
    
    return self;
}

- (id)initWithCornerView:(BOOL)showCornerView controlView:(BOOL)showControlsView barcodesHandler:(RSBarcodesHandler)barcodesHandler preferredCameraPosition:(AVCaptureDevicePosition)cameraDevicePosition {
    
    self.preferredCameraPosition = cameraDevicePosition;
    
    return [self initWithCornerView:showCornerView controlView:showControlsView barcodesHandler:barcodesHandler];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self __setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(__applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(__applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [self __startRunning];
    [self updateView];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    
    [self __stopRunning];
}

- (BOOL)shouldAutorotate {
    [self updateView];
    return NO;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSMutableArray *barcodeObjects  = nil;
    NSMutableArray *cornersArray    = nil;
    NSMutableArray *borderRectArray = nil;
    
    for (AVMetadataObject *metadataObject in metadataObjects) {
        AVMetadataObject *transformedMetadataObject = [self.layer transformedMetadataObjectForMetadataObject:metadataObject];
        if ([transformedMetadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            AVMetadataMachineReadableCodeObject *barcodeObject = (AVMetadataMachineReadableCodeObject *)transformedMetadataObject;
            if (!barcodeObjects) {
                barcodeObjects = [[NSMutableArray alloc] init];
            }
            [barcodeObjects addObject:barcodeObject];
            
            if (self.isCornersVisible) {
                if ([barcodeObject respondsToSelector:@selector(corners)]) {
                    if (!cornersArray) {
                        cornersArray = [[NSMutableArray alloc] init];
                    }
                    [cornersArray addObject:barcodeObject.corners];
                }
            }
            
            if (self.isBorderRectsVisible) {
                if ([barcodeObject respondsToSelector:@selector(bounds)]) {
                    if (!borderRectArray) {
                        borderRectArray = [[NSMutableArray alloc] init];
                    }
                    [borderRectArray addObject:[NSValue valueWithCGRect:barcodeObject.bounds]];
                }
            }
        }
    }
    
    if (self.isCornersVisible) {
        self.highlightView.cornersArray = cornersArray ? [NSArray arrayWithArray:cornersArray] : nil;
    }
    
    if (self.isBorderRectsVisible) {
        self.highlightView.borderRectArray = borderRectArray ? [NSArray arrayWithArray:borderRectArray] : nil;
    }
    
    if (self.barcodesHandler) {
        self.barcodesHandler([NSArray arrayWithArray:barcodeObjects]);
    }
}

- (void)switchCamera {
    CATransition *animation = [CATransition animation];
    animation.duration = .5f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = @"oglFlip";
    if (self.device.position == AVCaptureDevicePositionFront) {
        animation.subtype = kCATransitionFromRight;
    }
    else if(self.device.position == AVCaptureDevicePositionBack){
        animation.subtype = kCATransitionFromLeft;
    }
    [self.layer addAnimation:animation forKey:nil];
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if(d.position != _device.position)
        {
            [self __stopRunning];
            _device = d;
            
            [_session removeInput:_input];
            
            _input = [[AVCaptureDeviceInput alloc]
                      initWithDevice:_device error:nil];
            
            if ([_session canAddInput:_input]) {
                [_session addInput:_input];
            }
            
            [self __startRunning];
            break;
        }
    }
}

- (void)exit {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:true completion:nil];
    });
}

- (void)toggleTorch {
    static BOOL torchstate;
    torchstate = !torchstate;
    
    [self torchOnOff:torchstate];
}

- (void)torchOnOff: (BOOL) onOff {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        [device setTorchMode: onOff ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
        [device unlockForConfiguration];
    }
}

# pragma mark - Interface

- (void)updateView {
    if(!self.isControlsVisible)
    {
        return;
    }
    
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    CGRect flipButtonRect;
    CGRect cancelButtonRect;
    CGRect torchButtonRect;
    CGRect sidebarRect;
    
    CGFloat rotationAngle = 0;
    
    CGSize viewSize = self.view.frame.size;
    
    if(!self.sidebarView)
    {
        self.sidebarView = [[UIView alloc] init];
        [self.sidebarView setBackgroundColor:[UIColor blackColor]];
        
        [self.view addSubview:self.sidebarView];
        [self.view bringSubviewToFront:self.sidebarView];
    }
    
    if(!self.cancelButton)
    {
        self.cancelButton = [[UIButton alloc] init];
        [self.cancelButton setTitle:@"cancel" forState:UIControlStateNormal];
        [self.cancelButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [self.cancelButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        [self.cancelButton addTarget:self action:@selector(exit) forControlEvents:UIControlEventTouchDown];
        
        [self.view addSubview:self.cancelButton];
        [self.view bringSubviewToFront:self.cancelButton];
    }
    
    if(!self.flipButton)
    {
        self.flipButton = [[UIButton alloc] init];
        [self.flipButton setTitle:@"flip" forState:UIControlStateNormal];
        [self.flipButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        //[self.switchButton setImage:[UIImage imageNamed:@"CAMFlipButton"] forState:UIControlStateNormal];
        [self.flipButton addTarget:self action:@selector(switchCamera) forControlEvents:UIControlEventTouchDown];
        
        [self.view addSubview:self.flipButton];
        [self.view bringSubviewToFront:self.flipButton];
    }
    
    if(!self.torchButton && [self.device hasTorch])
    {
        self.torchButton = [[UIButton alloc] init];
        [self.torchButton setTitle:@"torch" forState:UIControlStateNormal];
        [self.torchButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        [self.torchButton addTarget:self action:@selector(toggleTorch) forControlEvents:UIControlEventTouchDown];
        
        
        [self.view addSubview:self.torchButton];
        [self.view bringSubviewToFront:self.torchButton];
    }
    
    switch (UI_USER_INTERFACE_IDIOM()) {
        case UIUserInterfaceIdiomPad:
        {
            sidebarRect = CGRectMake(self.view.frame.size.width - 110, 0, 110, self.view.frame.size.height);
            flipButtonRect = CGRectMake(viewSize.width - 70, 20, 56, 30);
            cancelButtonRect = CGRectMake(self.view.frame.size.width - 80, viewSize.height - 40, 56, 30);
            
            if (orientation == 0) //Default orientation
            {
                //failsafe
            }
            else if (orientation == UIInterfaceOrientationPortrait)
            {
            }
            else if (orientation == UIInterfaceOrientationPortraitUpsideDown)
            {
            }
            else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
            {
                cancelButtonRect = CGRectMake(self.view.frame.size.width - 80, viewSize.height - 50, 56, 42);
            }
            
        }
            break;
            
        case UIUserInterfaceIdiomPhone:
        {
            const int marginToTop = 15;
            
            sidebarRect = CGRectMake(0, 0, viewSize.width, 50);
            flipButtonRect = CGRectMake(viewSize.width - 40, marginToTop, 30, 30);
            torchButtonRect = CGRectMake(viewSize.width/2 - 20, marginToTop, 30, 30);
            cancelButtonRect = CGRectMake(5, marginToTop, 50, 30);
            
            if (orientation == 0) //Default orientation
            {
                //failsafe
            }
            else if (orientation == UIInterfaceOrientationPortrait)
            {
            }
            else if (orientation == UIInterfaceOrientationPortraitUpsideDown)
            {
            }
            else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
            {
                sidebarRect = CGRectMake(0, 0, viewSize.width, 80);
                
                const int rotateMargin = 15;
                flipButtonRect = CGRectMake(viewSize.width - 40, marginToTop + rotateMargin, 30, 30);
                torchButtonRect = CGRectMake(viewSize.width/2 - 18, marginToTop + rotateMargin, 30, 30);
                cancelButtonRect = CGRectMake(5, marginToTop + rotateMargin, 30, 30);
            }
        }
            break;
            
        default:
            break;
    }
    
    if (orientation == UIDeviceOrientationPortraitUpsideDown) rotationAngle = M_PI;
    else if (orientation == UIDeviceOrientationLandscapeLeft) rotationAngle = M_PI_2;
    else if (orientation == UIDeviceOrientationLandscapeRight) rotationAngle = -M_PI_2;
    [UIView animateWithDuration:0.5 animations:^{
        self.cancelButton.transform = CGAffineTransformMakeRotation(rotationAngle);
        self.torchButton.transform = CGAffineTransformMakeRotation(rotationAngle);
        self.flipButton.transform = CGAffineTransformMakeRotation(rotationAngle);
        
        [self.sidebarView setFrame:sidebarRect];
        [self.flipButton setFrame:flipButtonRect];
        [self.cancelButton setFrame:cancelButtonRect];
        [self.torchButton setFrame:torchButtonRect];
        
    } completion:nil];
    
    [self.flipButton sizeToFit];
    [self.cancelButton sizeToFit];
    [self.torchButton sizeToFit];
}

- (UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    //	(iOS 6)
    //	Force to portrait
    return UIInterfaceOrientationPortrait;
}

- (BOOL)isModal {
    if([self presentingViewController])
        return YES;
    if([[self presentingViewController] presentedViewController] == self)
        return YES;
    if([[[self navigationController] presentingViewController] presentedViewController] == [self navigationController])
        return YES;
    if([[[self tabBarController] presentingViewController] isKindOfClass:[UITabBarController class]])
        return YES;
    
    return NO;
}

@end
