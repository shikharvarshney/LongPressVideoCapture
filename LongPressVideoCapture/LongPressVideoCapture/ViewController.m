//
//  ViewController.m
//  LongPressVideoCapture
//
//  Created by Shikhar Varshney on 30/03/15.
//  Copyright (c) 2015 Shikhar Varshney. All rights reserved.
//

#import "ViewController.h"
#import "PBJVision.h"
#import "PBJVisionUtilities.h"
#import "PBJStrobeView.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ExtendedHitButton : UIButton

+ (instancetype)extendedHitButton;

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;

@end

@implementation ExtendedHitButton

+ (instancetype)extendedHitButton
{
    return (ExtendedHitButton *)[ExtendedHitButton buttonWithType:UIButtonTypeCustom];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect relativeFrame = self.bounds;
    UIEdgeInsets hitTestEdgeInsets = UIEdgeInsetsMake(-35, -35, -35, -35);
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, hitTestEdgeInsets);
    return CGRectContainsPoint(hitFrame, point);
}

@end


@interface ViewController ()<UIGestureRecognizerDelegate, PBJVisionDelegate, UIAlertViewDelegate>{
    
    PBJStrobeView *_strobeView;
    UIButton *_doneButton;
    
    UIView *_previewView;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    UIView *_gestureView;
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
    UITapGestureRecognizer *_tapGesture;
    
    UIButton * btn_capture;
//    CAShapeLayer *circle;
//    CABasicAnimation *drawAnimation;
   
    
    BOOL _recording;
    
    int counter;
    NSTimer * timer;
    NSInteger int_timeElapsed;
    
    BOOL isFingerLifted;
    
    ALAssetsLibrary *_assetLibrary;
    __block NSDictionary *_currentVideo;
    __block NSDictionary *_currentPhoto;
}

@end

@implementation ViewController

#pragma mark - init

- (void)dealloc
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    _longPressGestureRecognizer.delegate = nil;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.view.backgroundColor = [UIColor blackColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    
    
    
    // preview and AV layer
    _previewView = [[UIView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor blackColor];
    CGRect previewFrame = CGRectMake(0, 0.0f, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    _previewView.frame = previewFrame;
    _previewLayer = [[PBJVision sharedInstance] previewLayer];
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer addSublayer:_previewLayer];
    
   

    
    // touch to record
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressGestureRecognizer:)];
    _longPressGestureRecognizer.delegate = self;
    _longPressGestureRecognizer.minimumPressDuration = 0.5f;
    _longPressGestureRecognizer.allowableMovement = 10.0f;
    
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected:)];
    _tapGesture.numberOfTapsRequired = 1;
    _tapGesture.numberOfTouchesRequired = 1;
    _tapGesture.delegate = self;
    
    // gesture view to record
    _gestureView = [[UIView alloc] initWithFrame:CGRectZero];
    CGRect gestureFrame = self.view.bounds;
    gestureFrame.origin = CGPointMake(0, 60.0f);
    gestureFrame.size.height -= (40.0f + 85.0f);
    _gestureView.frame = gestureFrame;
    [self.view addSubview:_gestureView];
    
    btn_capture = [[UIButton alloc] initWithFrame:CGRectMake(120, 450, 100,100)];
    [btn_capture setImage:[UIImage imageNamed:@"camera.png"] forState:UIControlStateNormal];
    
    // Animation Definition
    int radius = 50;
    self.circle = [CAShapeLayer layer];
    // Make a circular shape
    self.circle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 2.0*radius, 2.0*radius)
                                                  cornerRadius:radius].CGPath;
    // Center the shape in self.view
    //CGRectGetMidX(self.view.frame)-radius,
    //CGRectGetMidY(self.view.frame)-radius
    self.circle.position = CGPointMake(btn_capture.frame.origin.x, btn_capture.frame.origin.y);
    
    // Configure the apperence of the circle
    self.circle.fillColor = [UIColor clearColor].CGColor;
    self.circle.strokeColor = [UIColor redColor].CGColor;
    self.circle.lineWidth = 5;
    
    self.circle.strokeEnd = 0.0f;
    
    // Add to parent layer
    [self.view.layer addSublayer:_circle];
    
    // Target for touch down (hold down)
    //[btn_capture addTarget:self action:@selector(startCircleAnimation) forControlEvents:UIControlEventTouchDown];
    
    // Target for release
    //[btn_capture addTarget:self action:@selector(endCircleAnimation) forControlEvents:UIControlEventTouchUpInside];
    
    //[_gestureView addGestureRecognizer:_longPressGestureRecognizer];
    //[_gestureView addGestureRecognizer:_tapGesture];
    
    
}

-(void)viewWillAppear:(BOOL)animated{
    
    [[PBJVision sharedInstance] unfreezePreview];
    //iOS 6 support
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    [self _resetCapture];
    [[PBJVision sharedInstance] startPreview];
}

-(void)startCircleAnimation{
    if (_drawAnimation) {
        [self resumeLayer:_circle];
    } else {
        [self circleAnimation];
    }
}

-(void)endCircleAnimation{
    [self pauseLayer:_circle];
}

- (void)circleAnimation
{
    // Configure animation
    self.drawAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    self.drawAnimation.duration            = 10.0;
    self.drawAnimation.repeatCount         = 1.0; // Animate only once..
    
    
    // Animate from no part of the stroke being drawn to the entire stroke being drawn
    self.drawAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    
    // Set your to value to one to complete animation
   self.drawAnimation.toValue   = [NSNumber numberWithFloat:1.0f];
    
    // Experiment with timing to get the appearence to look the way you want
    self.drawAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    
    // Add to parent layer
    [self.view.layer addSublayer:self.circle];
    
    // Add the animation to the circle
    [self.circle addAnimation:_drawAnimation forKey:@"draw"];
}

- (void)pauseLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

- (void)resumeLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[PBJVision sharedInstance] stopPreview];
    
    // iOS 6 support
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
}


#pragma mark - private start/stop helper methods

- (void)_startCapture
{
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    
    [[PBJVision sharedInstance] startVideoCapture];
}

- (void)_pauseCapture
{
    
    
    [[PBJVision sharedInstance] pauseVideoCapture];
    //_effectsViewController.view.hidden = !_onionButton.selected;
}

- (void)_resumeCapture
{
    [[PBJVision sharedInstance] resumeVideoCapture];
    //_effectsViewController.view.hidden = YES;
}

- (void)_endCapture
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[PBJVision sharedInstance] endVideoCapture];
    
    [self _resetCapture];
    //_effectsViewController.view.hidden = YES;
}

- (void)_resetCapture
{
    
    [[PBJVision sharedInstance] startPreview];
    [_strobeView stop];
    _longPressGestureRecognizer.enabled = YES;
    
    PBJVision *vision = [PBJVision sharedInstance];
    vision.delegate = self;
    
    if ([vision isCameraDeviceAvailable:PBJCameraDeviceBack]) {
        vision.cameraDevice = PBJCameraDeviceBack;
        //_flipButton.hidden = NO;
    } else {
        vision.cameraDevice = PBJCameraDeviceFront;
        //_flipButton.hidden = YES;
    }
    
    //vision.cameraMode = PBJCameraModeVideo;
    vision.cameraMode = PBJCameraModePhoto; // PHOTO: uncomment to test photo capture
    vision.cameraOrientation = PBJCameraOrientationPortrait;
    vision.focusMode = PBJFocusModeContinuousAutoFocus;
    vision.outputFormat = PBJOutputFormatSquare;
    vision.videoRenderingEnabled = YES;
    vision.additionalCompressionProperties = @{AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline30}; // AVVideoProfileLevelKey requires specific captureSessionPreset
    
    // specify a maximum duration with the following property
     vision.maximumCaptureDuration = CMTimeMakeWithSeconds(15, 600); // ~ 15 seconds
}

- (void)_handleDoneButton:(UIButton *)button
{
    // resets long press
    _longPressGestureRecognizer.enabled = NO;
    _longPressGestureRecognizer.enabled = YES;
    
    [self _endCapture];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self _resetCapture];
}

#pragma mark - UIGestureRecognizer

- (void)_handleLongPressGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    // PHOTO: uncomment to test photo capture
    //    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    //
    //        [[PBJVision sharedInstance] capturePhoto];
    //        return;
    //    }
    PBJVision *vision = [PBJVision sharedInstance];
    vision.delegate = self;
    vision.cameraMode = PBJCameraModeVideo;
    
    
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            
            [self startCircleAnimation];
//            counter = 0;
//            timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementCounter) userInfo:nil repeats:YES];
//            //isFingerLifted = FALSE;
//            [self startCircularAnimation];
            //if (!_recording)
                [self _startCapture];
            //else
               // [self _resumeCapture];
            NSLog(@"State began");
            break;
        }
        case UIGestureRecognizerStateEnded:{
            NSLog(@"State ended");
            [self endCircleAnimation];
//             [timer invalidate];
//            isFingerLifted = TRUE;
//            [self startCircularAnimation];
            [self _endCapture];
            break;
        }
        case UIGestureRecognizerStateCancelled:{
            NSLog(@"State cancelled");
            break;
        }
        case UIGestureRecognizerStateFailed:
        {
            //[self _pauseCapture];
            break;
        }
        default:
            break;
    }
}

-(void)tapDetected:(UIGestureRecognizer *)getsureRecognizer{
    
    
    PBJVision *vision = [PBJVision sharedInstance];
    vision.delegate = self;
    vision.cameraMode = PBJCameraModePhoto;
    [[PBJVision sharedInstance] capturePhoto];
    return;
    
    
    
}

//- (void)incrementCounter {
//     counter++;
//    NSLog(@"the seconds paased are %d", counter);
//}

//-(void)startCircularAnimation{
//    
//    int radius = 50;
//    circle = [CAShapeLayer layer];
//    // Make a circular shape
//    circle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 2.0*radius, 2.0*radius)
//                                             cornerRadius:radius].CGPath;
//    // Center the shape in self.view
//    //CGRectGetMidX(self.view.frame)-radius
//    circle.position = CGPointMake(120.0f,
//                                  450.0f);
//    
//    // Configure the apperence of the circle
//    circle.fillColor = [UIColor clearColor].CGColor;
//    circle.strokeColor = [UIColor redColor].CGColor;
//    circle.lineWidth = 5;
//    
//    // Add to parent layer
//    [self.view.layer addSublayer:circle];
//    
//    // Configure animation
//    CABasicAnimation *drawAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
//    drawAnimation.duration            = 15.0;
//    drawAnimation.repeatCount         = 1.0;  // Animate only once..
//    NSLog(@"the begin animation time is %f",drawAnimation.beginTime);
//    
//    // Animate from no part of the stroke being drawn to the entire stroke being drawn
//    if (!isFingerLifted) {
//        drawAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
//        drawAnimation.toValue   = [NSNumber numberWithFloat:1.0f];
//    }
//    else{
//        drawAnimation.fromValue = [NSNumber numberWithFloat:counter/drawAnimation.duration];
//        drawAnimation.toValue   = [NSNumber numberWithFloat:counter/drawAnimation.duration];
//    }
//    
//   
//    
//    // Experiment with timing to get the appearence to look the way you want
//    drawAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
//    
//    // Add the animation to the circle
//    [circle addAnimation:drawAnimation forKey:@"draw"];
//    
//}

#pragma mark - PBJVisionDelegate

// session

- (void)visionSessionWillStart:(PBJVision *)vision
{
}

- (void)visionSessionDidStart:(PBJVision *)vision
{
    if (![_previewView superview]) {
        [self.view addSubview:_previewView];
        [self.view bringSubviewToFront:_gestureView];
        
        // elapsed time and red dot
        _strobeView = [[PBJStrobeView alloc] initWithFrame:CGRectZero];
        CGRect strobeFrame = _strobeView.frame;
        strobeFrame.origin = CGPointMake(15.0f, 15.0f);
        _strobeView.frame = strobeFrame;
        [self.view addSubview:_strobeView];
        
        // done button
        _doneButton = [ExtendedHitButton extendedHitButton];
        _doneButton.frame = CGRectMake(self.view.frame.size.width - 25.0f - 15.0f, 18.0f, 25.0f, 25.0f);
        UIImage *buttonImage = [UIImage imageNamed:@"capture_done"];
        [_doneButton setImage:buttonImage forState:UIControlStateNormal];
        [_doneButton addTarget:self action:@selector(_handleDoneButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_doneButton];
        
        
        
        [btn_capture addGestureRecognizer:_longPressGestureRecognizer];
        [btn_capture addGestureRecognizer:_tapGesture];
        
        [self.view addSubview:btn_capture];
    }
}

- (void)visionSessionDidStop:(PBJVision *)vision
{
    [_previewView removeFromSuperview];
}

// preview

- (void)visionSessionDidStartPreview:(PBJVision *)vision
{
    NSLog(@"Camera preview did start");
    
}

- (void)visionSessionDidStopPreview:(PBJVision *)vision
{
    NSLog(@"Camera preview did stop");
}

// device

- (void)visionCameraDeviceWillChange:(PBJVision *)vision
{
    NSLog(@"Camera device will change");
}

- (void)visionCameraDeviceDidChange:(PBJVision *)vision
{
    NSLog(@"Camera device did change");
}

// mode

- (void)visionCameraModeWillChange:(PBJVision *)vision
{
    NSLog(@"Camera mode will change");
}

- (void)visionCameraModeDidChange:(PBJVision *)vision
{
    NSLog(@"Camera mode did change");
}

// format

- (void)visionOutputFormatWillChange:(PBJVision *)vision
{
    NSLog(@"Output format will change");
}

- (void)visionOutputFormatDidChange:(PBJVision *)vision
{
    NSLog(@"Output format did change");
}

- (void)vision:(PBJVision *)vision didChangeCleanAperture:(CGRect)cleanAperture
{
}

// focus / exposure

- (void)visionWillStartFocus:(PBJVision *)vision
{
}

//- (void)visionDidStopFocus:(PBJVision *)vision
//{
//    if (_focusView && [_focusView superview]) {
//        [_focusView stopAnimation];
//    }
//}

- (void)visionWillChangeExposure:(PBJVision *)vision
{
}

//- (void)visionDidChangeExposure:(PBJVision *)vision
//{
//    if (_focusView && [_focusView superview]) {
//        [_focusView stopAnimation];
//    }
//}

// flash

- (void)visionDidChangeFlashMode:(PBJVision *)vision
{
    NSLog(@"Flash mode did change");
}

// photo

- (void)visionWillCapturePhoto:(PBJVision *)vision
{
}

- (void)visionDidCapturePhoto:(PBJVision *)vision
{
    [[PBJVision sharedInstance] unfreezePreview];
}

- (void)vision:(PBJVision *)vision capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    if (error) {
        // handle error properly
        return;
    }
    _currentPhoto = photoDict;
    
    // save to library
    NSData *photoData = _currentPhoto[PBJVisionPhotoJPEGKey];
    NSDictionary *metadata = _currentPhoto[PBJVisionPhotoMetadataKey];
    [_assetLibrary writeImageDataToSavedPhotosAlbum:photoData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error1) {
        if (error1 || !assetURL) {
            // handle error properly
            return;
        }
        
        NSString *albumName = @"PBJVision";
        __block BOOL albumFound = NO;
        [_assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if ([albumName compare:[group valueForProperty:ALAssetsGroupPropertyName]] == NSOrderedSame) {
                albumFound = YES;
                [_assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                    [group addAsset:asset];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Photo Saved!" message: @"Saved to the camera roll."
                                                                   delegate:nil
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@"OK", nil];
                    [alert show];
                    //[self _resetCapture];
                } failureBlock:nil];
            }
            if (!group && !albumFound) {
                __weak ALAssetsLibrary *blockSafeLibrary = _assetLibrary;
                [_assetLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group1) {
                    [blockSafeLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                        [group1 addAsset:asset];
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Photo Saved!" message: @"Saved to the camera roll."
                                                                       delegate:nil
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil];
                        [alert show];
                    } failureBlock:nil];
                } failureBlock:nil];
            }
        } failureBlock:nil];
    }];
    
    _currentPhoto = nil;
}

// video capture

- (void)visionDidStartVideoCapture:(PBJVision *)vision
{
    [_strobeView start];
    _recording = YES;
}

- (void)visionDidPauseVideoCapture:(PBJVision *)vision
{
    [_strobeView stop];
}

- (void)visionDidResumeVideoCapture:(PBJVision *)vision
{
    [_strobeView start];
}

- (void)vision:(PBJVision *)vision capturedVideo:(NSDictionary *)videoDict error:(NSError *)error
{
    _recording = NO;
    
    if (error && [error.domain isEqual:PBJVisionErrorDomain] && error.code == PBJVisionErrorCancelled) {
        NSLog(@"recording session cancelled");
        return;
    } else if (error) {
        NSLog(@"encounted an error in video capture (%@)", error);
        return;
    }
    
    _currentVideo = videoDict;
    
    NSString *videoPath = [_currentVideo  objectForKey:PBJVisionVideoPathKey];
    [_assetLibrary writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:videoPath] completionBlock:^(NSURL *assetURL, NSError *error1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Video Saved!" message: @"Saved to the camera roll."
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
    }];
}

// progress

- (void)vision:(PBJVision *)vision didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //    NSLog(@"captured audio (%f) seconds", vision.capturedAudioSeconds);
}

- (void)vision:(PBJVision *)vision didCaptureAudioSample:(CMSampleBufferRef)sampleBuffer
{
    //    NSLog(@"captured video (%f) seconds", vision.capturedVideoSeconds);
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
