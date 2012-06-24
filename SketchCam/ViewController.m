//
//  ViewController.m
//  SketchCam
//
//  Created by Shi Forrest on 12-6-16.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "MKStoreManager.h"
#import "FSGPUImageFilterManager.h"

#define SWITCH_CAMERA_WIDTH     (IS_PAD() ? 80.0 : 60.)
#define SWITCH_CAMERA_HEIGHT    (IS_PAD() ? 60.0 : 45.)
#define GAP_X                   (IS_PAD() ? 30.0 : 20.)
#define GAP_Y                   (IS_PAD() ? 30.0 : 20.)


#define TAKE_PIC_BTN_WIDTH     (IS_PAD() ? 80.0 : 60.)
#define TAKE_PIC_BTN_HEIGHT    (IS_PAD() ? 60.0 : 45.)

#define BOTTOM_OFFSET_X        (IS_PAD() ? 10.0 : 6.)
#define BOTTOM_OFFSET_Y        (IS_PAD() ? 10.0 : 6.)

#define CAPTURED_THUMB_IMAGE_HEIGHT ((IS_PAD())? 102.4 *0.8 : 48 * 1.5 * 0.8)
//#define CAPTURED_THUMB_IMAGE_WIDTH  (CAPTURED_THUMB_IMAGE_HEIGHT * ( (IS_PAD()) ? 768.0/1024.0 : 320./480. ))

#define BOTTOM_SWITCH_WIDTH         ((IS_PAD()) ? 80.0 : 60.)
#define BOTTOM_SWITCH_HEIGHT        ((IS_PAD()) ? 20.0 : 15.)

static NSString *kSwitchFrontBackCamImage = @"button_blue_repeat@128.png";
static NSString *kStillCaptureImage = @"camera.png";
static NSString *kVideoStartRecordImage = @"media_record.png";
static NSString *kVideoStopRecordImage = @"button_stop_red.png";
static NSString *kBottomPanelTextureImage = @"fether.jpeg";


@interface ViewController () <UIImagePickerControllerDelegate , UIPopoverControllerDelegate>{
    GPUImageStillCamera *stillCamera;
    GPUImageOutput<GPUImageInput> *filter;
    
    GPUImageView *cameraView;
    UISlider *filterSettingsSlider;
    UILabel *timingLabel;
    UIButton *photoCaptureButton;
    UISwitch *photoSwitchVideo;
    UIButton *backButton;
    UIButton *switchFrontBackButton;
    
    UIImageView *thumbCapturedImageView;
    UIView *whiteFlashView ;
    UIView *bottomControlPanel;
    UIPopoverController *popoverCtr;
    BOOL            captureStillImageMode;
    BOOL            isRecording;
    NSTimer         *recordTimer;
    GPUImageMovieWriter* movieWriter;
    NSURL *movieURL ;
    
    NSUInteger      usedTimesOfCapture;
    
    __block BOOL                _atomicGestureUsedFlag;
    __block CGRect              _originalFrame;
    __block BOOL                _isTapped;
    __block BOOL                _viewIsFullScreenMode;
    
    NSUInteger                  _pageIndex;
    GPUImageShowcaseFilterType  _filterType;
    __unsafe_unretained UISlider *_filterSettingsSlider;
    BOOL                        isUsingFrontFacingCamera;
    
    NSMutableArray  *subViewsArray;
    NSMutableArray  *subViewFilterArray;
    
}

- (void)updateSliderValue:(id)sender;
- (void)takePhoto:(id)sender;

@end

@implementation ViewController


#define ROWS    3
#define COLS    3

- (void) hideFullScreenUI:(BOOL)hidden{

    [UIView animateWithDuration:1.0 animations:^{
        if (hidden) {
            filterSettingsSlider.alpha = 0.0;
            timingLabel.alpha = 0;
            photoCaptureButton.alpha = 0;
            bottomControlPanel.alpha =0;
            backButton.alpha =0;
            switchFrontBackButton.alpha = 0;
        }else {
            filterSettingsSlider.alpha = 1.0;
            timingLabel.alpha = 1;
            photoCaptureButton.alpha = 1;
            bottomControlPanel.alpha =1;
            backButton.alpha =1;
            switchFrontBackButton.alpha = 1;
            
        }

    }];
    
}

- (void) createFullScreenUI 
{
    [self hideFullScreenUI:NO];

    float viewWidth = [[UIScreen mainScreen] applicationFrame].size.width; //self.view.bounds.size.width;
    float viewHeight = [[UIScreen mainScreen] applicationFrame].size.height; //self.view.bounds.size.height;
    
#ifdef ARTCAM
    // back button 
    if (!backButton) {
        backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [backButton setImage:[UIImage imageNamed:@"left.png"] forState:UIControlStateNormal];
        
        backButton.frame = CGRectMake(GAP_X, 
                                                 GAP_Y/2 , 
                                                 IS_PAD()? 64.:48., 
                                                 IS_PAD() ? 64.:48.);
        backButton.userInteractionEnabled = YES;
        [backButton addTarget:self action:@selector(backToHome) forControlEvents:UIControlEventAllEvents];

    }

    [cameraView addSubview:backButton];

#endif
    
    // swich of front/back camera 
    if (!switchFrontBackButton) {
        switchFrontBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [switchFrontBackButton setImage:[UIImage imageNamed:kSwitchFrontBackCamImage] forState:UIControlStateNormal];
        
        switchFrontBackButton.frame = CGRectMake(viewWidth - 64. - GAP_X/2 , 
                                                 GAP_Y/2 , 
                                                 IS_PAD()? 64.:48., 
                                                 IS_PAD() ? 64.:48.);
        [switchFrontBackButton addTarget:self action:@selector(switchCameras:) forControlEvents:UIControlEventTouchDown];
    }
    [cameraView addSubview:switchFrontBackButton];

    // slider
    if (!filterSettingsSlider) {
        filterSettingsSlider = [[UISlider alloc] initWithFrame:CGRectMake(viewWidth*0.1,
                                                                          IS_PAD()? viewHeight*0.8 : viewHeight*.7, 
                                                                          viewWidth *.8, 
                                                                          viewHeight * .1)];
        
        [filterSettingsSlider setThumbTintColor:[UIColor orangeColor]];
        [filterSettingsSlider setMinimumTrackTintColor:[UIColor orangeColor]];
        [filterSettingsSlider setBackgroundColor:[UIColor clearColor]];
        [filterSettingsSlider addTarget:self action:@selector(updateSliderValue:) forControlEvents:UIControlEventValueChanged];
        filterSettingsSlider.minimumValue = 0.0;
        filterSettingsSlider.maximumValue = 3.0;
        filterSettingsSlider.value = 1.0; 
    }
    [cameraView addSubview:filterSettingsSlider];
    DLog(@"slider %@",NSStringFromCGRect(filterSettingsSlider.frame));
    
    //time label for recording 
    if (!timingLabel) {
        timingLabel = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth/3, GAP_Y, viewWidth/2, 20.)];
        timingLabel.backgroundColor = [UIColor clearColor];
        timingLabel.textColor = [UIColor redColor];
        timingLabel.textAlignment = UITextAlignmentLeft;
        timingLabel.hidden = YES;
    }
    [cameraView addSubview:timingLabel];

    
    
    //Bottom controller panel 
    CGRect bottomControlPanelFrame = CGRectMake(0, self.view.bounds.size.height - (IS_PAD()? 90.0 : 60.), 
                                                self.view.bounds.size.width,
                                                IS_PAD()? 90.0 : 60.);

    if (!bottomControlPanel) {

        bottomControlPanel = [[UIView alloc] initWithFrame:bottomControlPanelFrame];
        
        bottomControlPanel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:kBottomPanelTextureImage]];
        bottomControlPanel.layer.cornerRadius = 10.0;
        bottomControlPanel.layer.shadowOffset = CGSizeMake(-10, -8);
        bottomControlPanel.layer.shadowOpacity = 0.5;
        bottomControlPanel.layer.shadowColor = [UIColor blackColor].CGColor;
 
    }
    
    // thumb 
    if (!thumbCapturedImageView) {
        thumbCapturedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(BOTTOM_OFFSET_X, 
                                                                               BOTTOM_OFFSET_Y,  
                                                                               bottomControlPanelFrame.size.height - BOTTOM_OFFSET_Y*2., 
                                                                               bottomControlPanelFrame.size.height - BOTTOM_OFFSET_Y*2.)];
        
        DLog(@"thumb frame is %@", NSStringFromCGRect(thumbCapturedImageView.frame));
        thumbCapturedImageView.backgroundColor = [UIColor clearColor];
        
        //thumbCapturedImageView.layer.cornerRadius = 8.0;
        thumbCapturedImageView.layer.borderColor = [UIColor orangeColor].CGColor;
        thumbCapturedImageView.layer.borderWidth = 2.0;
        
        thumbCapturedImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapThumbImage:)];
        [thumbCapturedImageView addGestureRecognizer:tapGesture];
        [bottomControlPanel addSubview:thumbCapturedImageView];
    }
    
    //capture button
    if (!photoCaptureButton) {
        photoCaptureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        //DLog(@"TAKE_PIC_BTN_WIDTH %f and %f",TAKE_PIC_BTN_WIDTH , IS_PAD() ? 80.0 : 60. );

        photoCaptureButton.frame = CGRectMake(viewWidth/2 - TAKE_PIC_BTN_WIDTH/2, 
                                              3.0, TAKE_PIC_BTN_WIDTH, TAKE_PIC_BTN_HEIGHT);
        DLog(@"frame %@", NSStringFromCGRect(photoCaptureButton.frame));
        [photoCaptureButton setImage:[UIImage imageNamed:kStillCaptureImage] forState:UIControlStateNormal];
        //photoCaptureButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [photoCaptureButton addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchDown];
        [bottomControlPanel addSubview:photoCaptureButton];
    }

    
    // switch from photo and video 
    if (!photoSwitchVideo) {
        photoSwitchVideo = [[UISwitch alloc] initWithFrame:CGRectMake(viewWidth - BOTTOM_OFFSET_X*2 - BOTTOM_SWITCH_WIDTH, 
                                                                      MAX(0.f, bottomControlPanel.frame.size.height/2 - BOTTOM_SWITCH_HEIGHT/2),
                                                                      BOTTOM_SWITCH_WIDTH, 
                                                                      MIN(BOTTOM_SWITCH_HEIGHT,bottomControlPanel.frame.size.height))];
        [photoSwitchVideo setOnTintColor:[UIColor redColor]];
        photoSwitchVideo.backgroundColor = [UIColor clearColor];
        [photoSwitchVideo addTarget:self action:@selector(switchPhotoBetweenRecord:) forControlEvents:UIControlEventTouchUpInside];
        [bottomControlPanel addSubview:photoSwitchVideo];
        
    }

    
    
    [cameraView addSubview:bottomControlPanel];
    
    //white flash screen
    whiteFlashView = [[UIView alloc] initWithFrame:cameraView.bounds];
    whiteFlashView.backgroundColor = [UIColor whiteColor];
    whiteFlashView.alpha = 0;
    [cameraView addSubview:whiteFlashView];
}


- (void) viewEnterFullScreen:(UIView*)view{
        
    [UIView animateWithDuration:1.0 animations:^{
        _originalFrame = view.frame;
        cameraView.frame = self.view.bounds;
        
        DLog(@"_originalFrame %@", NSStringFromCGRect(_originalFrame));
        
    } completion:^(BOOL finished) {
        //
        if (finished) {
                            
            _viewIsFullScreenMode = YES;
                
            [self createFullScreenUI];            
            
        }
    }];
}

- (void) viewLeaveFullScreen:(UIView*)view{
    
    UIView *touchedView = view;
    [UIView animateWithDuration:1.0 animations:^{
        DLog(@"_originalFrame %@", NSStringFromCGRect(_originalFrame));
        touchedView.frame = _originalFrame;
        
        //[self hideFullScreenUI];
        [self hideFullScreenUI:YES];
        
    } completion:^(BOOL finished) {
        //
        _viewIsFullScreenMode = NO;
        
    }];
    
}


- (void) onTap:(UITapGestureRecognizer*)gesture{

    if ([gesture state] == UIGestureRecognizerStateEnded && !_isTapped ) {

        _isTapped = YES;
        
        CGPoint tapPoint = [gesture locationInView:self.view];
        int x = (int)floorf(tapPoint.x /(self.view.frame.size.width/ROWS));
        int y = (int)floorf(tapPoint.y /(self.view.frame.size.height/COLS));
        int filterIndex = y*ROWS + x;
        DLog(@"tap filter %d", filterIndex);
        _filterType = filterIndex;  
        filter = [subViewFilterArray objectAtIndex:filterIndex];
        
        cameraView = (GPUImageView*)[gesture view];      
        
        
        [self.view bringSubviewToFront:cameraView];

        [self viewEnterFullScreen:cameraView];
        
    }
}

- (void) backToHome{
    if (_isTapped) {
        [self viewLeaveFullScreen:cameraView];
        _isTapped = NO;
        _viewIsFullScreenMode = NO;
    }
}

- (void) createSubCameraViewsWithCamera:(AVCaptureDevicePosition)devicePosition{
    
    NSString *captureSessionSetup = AVCaptureSessionPreset640x480;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
	    captureSessionSetup = AVCaptureSessionPresetPhoto;
    
    stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];	
    CGFloat subViewWidth = roundf(mainScreenFrame.size.width/ ROWS );
    CGFloat subViewHeight = roundf(mainScreenFrame.size.height/ COLS );
    
    _pageIndex = 0;
    for (int i = 0 ; i < COLS; i++) {
        for (int j = 0 ; j < ROWS; j++) {
            // ( i, j) 
            GPUImageView *subView = [[GPUImageView alloc ] initWithFrame:CGRectMake(j*subViewWidth, i*subViewHeight, subViewWidth, subViewHeight)];
            [self.view addSubview:subView];
            
            if (!subViewsArray) {
                subViewsArray = [NSMutableArray array];
            }
            [subViewsArray addObject:subView];
            
            GPUImageFilter *subFilter = [[FSGPUImageFilterManager sharedFSGPUImageFilterManager] createGPUImageFilter:_pageIndex * ROWS *COLS + ROWS*i + j];
            if (!subViewFilterArray) {
                subViewFilterArray = [NSMutableArray array];
            }
            [subViewFilterArray addObject:subFilter];
            
            [subFilter forceProcessingAtSize:subView.sizeInPixels];
            [stillCamera addTarget:subFilter];
            [subFilter addTarget:subView];
        }
    }
    
    //tap gesture to get full screen 
    _isTapped = NO;
    _viewIsFullScreenMode = NO;
    
    //int count = 0; 
    for (UIView *subView in [self.view subviews]) {
        if ([subView isKindOfClass:[GPUImageView class]]) {
            //DLog(@"count %d subview %@", count++ , subView );
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
            
            //UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPinch:)];
            
            [subView addGestureRecognizer:tapGesture ];
            //[subView addGestureRecognizer:pinchGesture];
            
        }
    }
    
}

- (void) createFilterCameraViewWithCamera:(AVCaptureDevicePosition)devicePosition{
    
    NSString *captureSessionSetup = AVCaptureSessionPreset640x480;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
	    captureSessionSetup = AVCaptureSessionPresetPhoto;
    
    stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    
    CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];	    
    cameraView = [[GPUImageView alloc ] initWithFrame:mainScreenFrame];
        
    filter = [[FSGPUImageFilterManager sharedFSGPUImageFilterManager] createGPUImageFilter: _filterType ];

    [filter forceProcessingAtSize:cameraView.sizeInPixels];
    [stillCamera addTarget:filter];
    [filter addTarget:cameraView];
   
    [self.view addSubview:cameraView];
    
    [self createFullScreenUI];

}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
#ifdef ARTCAM
    
    [self createSubCameraViewsWithCamera:AVCaptureDevicePositionBack];
    
#elif SKETCHCAM
    _filterType = GPUIMAGE_SKETCH;
    [self createFilterCameraViewWithCamera:AVCaptureDevicePositionBack];
 
#elif SEPIACAM
    _filterType = GPUIMAGE_SEPIA;
    [self createFilterCameraViewWithCamera:AVCaptureDevicePositionBack];
#elif FUNCAM
    _filterType = GPUIMAGE_BULGE;
    [self createFilterCameraViewWithCamera:AVCaptureDevicePositionBack];
    
#endif
    captureStillImageMode = YES;
    isRecording = NO;
    [stillCamera startCameraCapture];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    DLog(@"DEBUG");
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
    
    [stillCamera resumeCameraCapture];
    [picker dismissModalViewControllerAnimated:YES];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    DLog(@"DEBUG");
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
    
    [stillCamera resumeCameraCapture];
    [picker dismissModalViewControllerAnimated:YES];
    
}

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
    
    if ([navigationController isKindOfClass:[UIImagePickerController class]] && 
        ((UIImagePickerController *)navigationController).sourceType == UIImagePickerControllerSourceTypeSavedPhotosAlbum) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
    }
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController{
    return YES;
}

/* Called on the delegate when the user has taken action to dismiss the popover. This is not called when -dismissPopoverAnimated: is called directly.
 */
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController{
    [stillCamera resumeCameraCapture];
    [popoverController dismissPopoverAnimated:YES];
}



#pragma mark - Actions of UI 

- (void) onTapThumbImage:(id)sender{
    DLog(@"DEBUG");
    UIImagePickerController *imgPickerVC = [[UIImagePickerController alloc] init];
    imgPickerVC.delegate = self;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];
    
    imgPickerVC.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    //imgPickerVC.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imgPickerVC.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imgPickerVC.sourceType];
    
    if (IS_PAD()) {
        popoverCtr = [[UIPopoverController alloc] initWithContentViewController:imgPickerVC];
        popoverCtr.delegate = self;
        
        [popoverCtr presentPopoverFromRect:thumbCapturedImageView.frame inView:thumbCapturedImageView permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
    }else {
        
        imgPickerVC.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        [self presentModalViewController:imgPickerVC animated:YES];
    }
    
    [stillCamera pauseCameraCapture];
    
}

// use front/back camera
- (void)switchCameras:(id)sender
{
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = 1.0;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    animation.type = @"cameraIris";
    //animation.type = @"flip";
    //animation.subtype = @"fromLeft";
    [cameraView.layer addAnimation:animation forKey:nil];
    
    [stillCamera rotateCamera];
}

- (void) switchPhotoBetweenRecord:(id)sender{
    captureStillImageMode = !captureStillImageMode;
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = 1.0;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    animation.type = captureStillImageMode ? @"fromRight" : @"fromLeft";
    animation.type = @"flip";
    [photoCaptureButton.layer addAnimation:animation forKey:@"image"];
    
    if (!captureStillImageMode) {
        [photoCaptureButton setImage:[UIImage imageNamed:kVideoStartRecordImage] forState:UIControlStateNormal];
    }else {
        [photoCaptureButton setImage:[UIImage imageNamed:kStillCaptureImage] forState:UIControlStateNormal];
    }
}

/*
 
 ISSUE: For the iPad2, there are some random noise when capturing photo 
 It is obvious for the back camera.
 */
- (void)takePhoto:(id)sender;
{
    
    if (!captureStillImageMode) {
        return [self recordVideo];     
    }
    
    [photoCaptureButton setEnabled:NO];
    
    //simulate white flash 
    [UIView animateWithDuration:.3 animations:^{
        whiteFlashView.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            whiteFlashView.alpha = 0;
        }];
    }];
    
    [stillCamera capturePhotoAsJPEGProcessedUpToFilter:filter withCompletionHandler:^(NSData *processedJPEG, NSError *error){
        
        // Save to assets library
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        //        report_memory(@"After asset library creation");
        
        [library writeImageDataToSavedPhotosAlbum:processedJPEG metadata:nil completionBlock:^(NSURL *assetURL, NSError *error2)
         {
             //             report_memory(@"After writing to library");
             if (error2) {
                 DLog(@"ERROR: the image failed to be written");
             }
             else {
                 DLog(@"PHOTO SAVED - assetURL: %@", assetURL);
             }
			 
             runOnMainQueueWithoutDeadlocking(^{
                 //                 report_memory(@"Operation completed");
                 [photoCaptureButton setEnabled:YES];
                 
                 [thumbCapturedImageView setImage:[UIImage imageWithData:processedJPEG]];
                 
             });
         }];
    }];
    
}

long recordingSeconds = 0;

- (void) updateRecordTime:(id)sender{
    recordingSeconds++;
    [timingLabel setText:[NSString stringWithFormat:@"Recording %d s", recordingSeconds]];
    
    // FREE VERSION LIMITATION 
    if (recordingSeconds >= 6 ) {
        [self stopRecording];
    }
}

- (void) recordVideo{
    if (isRecording) {
        [self stopRecording];
    }else {
        [self startRecording];
    }  
}

- (void) startRecording{
    
    [photoSwitchVideo setEnabled:NO];
    [switchFrontBackButton setEnabled:NO];
    
    isRecording = YES;    
    timingLabel.hidden = NO;
    
    recordTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateRecordTime:) userInfo:nil repeats:YES];
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = .5;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    //animation.subtype = @"fromLeft";
    animation.type = @"fade";
    [photoCaptureButton.layer addAnimation:animation forKey:@"image"];
    [photoCaptureButton setImage:[UIImage imageNamed:kVideoStopRecordImage] forState:UIControlStateNormal];
    
    [stillCamera pauseCameraCapture];
    
    NSString *tmpFileName = [NSString stringWithFormat:@"movie%d.m4v",rand()];
    NSString *pathToMovie = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat: @"%@",tmpFileName]];
    DLog(@"pathToMovie is %@", pathToMovie);
    
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    movieURL = [NSURL fileURLWithPath:pathToMovie];
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(480.0, 640.0)];
    //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(720.0, 1280.0)];
    //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1080.0, 1920.0)];
    [filter addTarget:movieWriter];
    
    [stillCamera resumeCameraCapture];
    
    double delayToStartRecording = 0.5;
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, delayToStartRecording * NSEC_PER_SEC);
    dispatch_after(startTime, dispatch_get_main_queue(), ^(void){
        DLog(@"Start recording");
        
        stillCamera.audioEncodingTarget = movieWriter;
        [movieWriter startRecording];
        
    });
    
}

- (void) stopRecording{
    
    [photoSwitchVideo setEnabled:YES];
    [switchFrontBackButton setEnabled:YES];
    
    isRecording = NO;
    if (recordTimer) {
        [recordTimer invalidate];
        recordTimer = nil;
        
        timingLabel.hidden = YES;
        timingLabel.text = @"";
        recordingSeconds = 0;
    }
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = .5;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    //animation.subtype = @"fromLeft";
    animation.type = @"fade";
    [photoCaptureButton.layer addAnimation:animation forKey:@"image"];
    
    [photoCaptureButton setImage:[UIImage imageNamed:kVideoStartRecordImage] forState:UIControlStateNormal];
    
    double delayInSeconds = .5;
    dispatch_time_t stopTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(stopTime, dispatch_get_main_queue(), ^(void){
        
        [filter removeTarget:movieWriter];
        stillCamera.audioEncodingTarget = nil;
        [movieWriter finishRecording];
        NSLog(@"Movie completed");
        
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        //        report_memory(@"After asset library creation");
        
        [library writeVideoAtPathToSavedPhotosAlbum:movieURL
                                    completionBlock:^(NSURL *assetURL, NSError *error2) {
                                        //
                                        if (error2) {
                                            DLog(@"ERROR: the video failed to be written");
                                        }
                                        else {
                                            DLog(@"VIDEO SAVED - assetURL: %@", assetURL);
                                        }
                                        
                                    }];
        
        
    });
    
}

#pragma mark -
#pragma mark Filter adjustments


- (void)updateSliderValue:(id)sender;
{
    switch(_filterType)
    {
        case GPUIMAGE_SKETCH:
        {
            float value = [(UISlider*)sender value] ;
            [(GPUImageSketchFilter *)filter setTexelHeight:(value / 480.0)];
            [(GPUImageSketchFilter *)filter setTexelWidth:(value / 360.0)];
            break;
        } 
        case GPUIMAGE_SEPIA: [(GPUImageSepiaFilter *)filter setIntensity:[(UISlider *)sender value]]; break;
        case GPUIMAGE_PIXELLATE: [(GPUImagePixellateFilter *)filter setFractionalWidthOfAPixel:[(UISlider *)sender value]]; break;
        case GPUIMAGE_POLARPIXELLATE: [(GPUImagePolarPixellateFilter *)filter setPixelSize:CGSizeMake([(UISlider *)sender value], [(UISlider *)sender value])]; break;
        case GPUIMAGE_SATURATION: [(GPUImageSaturationFilter *)filter setSaturation:[(UISlider *)sender value]]; break;
        case GPUIMAGE_CONTRAST: [(GPUImageContrastFilter *)filter setContrast:[(UISlider *)sender value]]; break;
        case GPUIMAGE_BRIGHTNESS: [(GPUImageBrightnessFilter *)filter setBrightness:[(UISlider *)sender value]]; break;
        case GPUIMAGE_EXPOSURE: [(GPUImageExposureFilter *)filter setExposure:[(UISlider *)sender value]]; break;
        case GPUIMAGE_RGB: [(GPUImageRGBFilter *)filter setGreen:[(UISlider *)sender value]]; break;
        case GPUIMAGE_SHARPEN: [(GPUImageSharpenFilter *)filter setSharpness:[(UISlider *)sender value]]; break;
        case GPUIMAGE_HISTOGRAM: [(GPUImageHistogramFilter *)filter setDownsamplingFactor:round([(UISlider *)sender value])]; break;
        case GPUIMAGE_UNSHARPMASK: [(GPUImageUnsharpMaskFilter *)filter setIntensity:[(UISlider *)sender value]]; break;
            //        case GPUIMAGE_UNSHARPMASK: [(GPUImageUnsharpMaskFilter *)filter setBlurSize:[(UISlider *)sender value]]; break;
        case GPUIMAGE_GAMMA: [(GPUImageGammaFilter *)filter setGamma:[(UISlider *)sender value]]; break;
        case GPUIMAGE_CROSSHATCH: [(GPUImageCrosshatchFilter *)filter setCrossHatchSpacing:[(UISlider *)sender value]]; break;
        case GPUIMAGE_POSTERIZE: [(GPUImagePosterizeFilter *)filter setColorLevels:round([(UISlider*)sender value])]; break;
		case GPUIMAGE_HAZE: [(GPUImageHazeFilter *)filter setDistance:[(UISlider *)sender value]]; break;
		case GPUIMAGE_THRESHOLD: [(GPUImageLuminanceThresholdFilter *)filter setThreshold:[(UISlider *)sender value]]; break;
        case GPUIMAGE_ADAPTIVETHRESHOLD: [(GPUImageAdaptiveThresholdFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
        case GPUIMAGE_DISSOLVE: [(GPUImageDissolveBlendFilter *)filter setMix:[(UISlider *)sender value]]; break;
        case GPUIMAGE_CHROMAKEY: [(GPUImageChromaKeyBlendFilter *)filter setThresholdSensitivity:[(UISlider *)sender value]]; break;
        case GPUIMAGE_KUWAHARA: [(GPUImageKuwaharaFilter *)filter setRadius:round([(UISlider *)sender value])]; break;
        case GPUIMAGE_SWIRL: [(GPUImageSwirlFilter *)filter setAngle:[(UISlider *)sender value]/16.]; break;
        case GPUIMAGE_EMBOSS: [(GPUImageEmbossFilter *)filter setIntensity:[(UISlider *)sender value]]; break;
        case GPUIMAGE_CANNYEDGEDETECTION: [(GPUImageCannyEdgeDetectionFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
            //        case GPUIMAGE_CANNYEDGEDETECTION: [(GPUImageCannyEdgeDetectionFilter *)filter setLowerThreshold:[(UISlider*)sender value]]; break;
        case GPUIMAGE_HARRISCORNERDETECTION: [(GPUImageHarrisCornerDetectionFilter *)filter setThreshold:[(UISlider*)sender value]]; break;
        case GPUIMAGE_NOBLECORNERDETECTION: [(GPUImageNobleCornerDetectionFilter *)filter setThreshold:[(UISlider*)sender value]]; break;
        case GPUIMAGE_SHITOMASIFEATUREDETECTION: [(GPUImageShiTomasiFeatureDetectionFilter *)filter setThreshold:[(UISlider*)sender value]]; break;
            //        case GPUIMAGE_HARRISCORNERDETECTION: [(GPUImageHarrisCornerDetectionFilter *)filter setSensitivity:[(UISlider*)sender value]]; break;
        case GPUIMAGE_SMOOTHTOON: [(GPUImageSmoothToonFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
            //        case GPUIMAGE_BULGE: [(GPUImageBulgeDistortionFilter *)filter setRadius:[(UISlider *)sender value]]; break;
        case GPUIMAGE_BULGE: [(GPUImageBulgeDistortionFilter *)filter setScale:[(UISlider *)sender value]]; break;
        case GPUIMAGE_TONECURVE: [(GPUImageToneCurveFilter *)filter setBlueControlPoints:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)], [NSValue valueWithCGPoint:CGPointMake(0.5, [(UISlider *)sender value])], [NSValue valueWithCGPoint:CGPointMake(1.0, 0.75)], nil]]; break;
        case GPUIMAGE_PINCH: [(GPUImagePinchDistortionFilter *)filter setScale:[(UISlider *)sender value]]; break;
        case GPUIMAGE_PERLINNOISE:  [(GPUImagePerlinNoiseFilter *)filter setScale:[(UISlider *)sender value]]; break;
        case GPUIMAGE_MOSAIC:  [(GPUImageMosaicFilter *)filter setDisplayTileSize:CGSizeMake([(UISlider *)sender value], [(UISlider *)sender value])]; break;
        case GPUIMAGE_VIGNETTE: [(GPUImageVignetteFilter *)filter setVignetteEnd:[(UISlider *)sender value]]; break;
        case GPUIMAGE_GAUSSIAN: [(GPUImageGaussianBlurFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
        case GPUIMAGE_BILATERAL: [(GPUImageBilateralFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
        case GPUIMAGE_FASTBLUR: [(GPUImageFastBlurFilter *)filter setBlurPasses:round([(UISlider*)sender value])]; break;
            //        case GPUIMAGE_FASTBLUR: [(GPUImageFastBlurFilter *)filter setBlurSize:[(UISlider*)sender value]]; break;
        case GPUIMAGE_GAUSSIAN_SELECTIVE: [(GPUImageGaussianSelectiveBlurFilter *)filter setExcludeCircleRadius:[(UISlider*)sender value]]; break;
        case GPUIMAGE_FILTERGROUP: [(GPUImagePixellateFilter *)[(GPUImageFilterGroup *)filter filterAtIndex:1] setFractionalWidthOfAPixel:[(UISlider *)sender value]]; break;
        case GPUIMAGE_CROP: [(GPUImageCropFilter *)filter setCropRegion:CGRectMake(0.0, 0.0, 1.0, [(UISlider*)sender value])]; break;
        case GPUIMAGE_TRANSFORM: [(GPUImageTransformFilter *)filter setAffineTransform:CGAffineTransformMakeRotation([(UISlider*)sender value])]; break;
        case GPUIMAGE_TRANSFORM3D:
        {
            CATransform3D perspectiveTransform = CATransform3DIdentity;
            perspectiveTransform.m34 = 0.4;
            perspectiveTransform.m33 = 0.4;
            perspectiveTransform = CATransform3DScale(perspectiveTransform, 0.75, 0.75, 0.75);
            perspectiveTransform = CATransform3DRotate(perspectiveTransform, [(UISlider*)sender value], 0.0, 1.0, 0.0);
            
            [(GPUImageTransformFilter *)filter setTransform3D:perspectiveTransform];            
        }; break;
        case GPUIMAGE_TILTSHIFT:
        {
            CGFloat midpoint = [(UISlider *)sender value];
            [(GPUImageTiltShiftFilter *)filter setTopFocusLevel:midpoint - 0.1];
            [(GPUImageTiltShiftFilter *)filter setBottomFocusLevel:midpoint + 0.1];
        }; break;
        default: break;
    }
}


@end
