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

static NSString *kStillCaptureImage = @"camera1@96.png";
static NSString *kVideoStartRecordImage = @"media_record.png";
static NSString *kVideoStopRecordImage = @"button_stop_red.png";

@interface ViewController () <UIImagePickerControllerDelegate , UIPopoverControllerDelegate>{
    GPUImageStillCamera *stillCamera;
    GPUImageOutput<GPUImageInput> *filter;
    UISlider *filterSettingsSlider;
    UILabel *timingLabel;
    UIButton *photoCaptureButton;
    UISwitch *photoSwitchVideo;
    UIButton *switchFrontBackButton ;
    UIImageView *thumbCapturedImageView;
    UIView *whiteFlashView ;
    UIPopoverController *popoverCtr;
    BOOL            captureStillImage;
    BOOL            isRecording;
    NSTimer         *recordTimer;
    GPUImageMovieWriter* movieWriter;
    NSURL *movieURL ;
    
    NSUInteger      usedTimesOfCapture;
}

- (void)updateSliderValue:(id)sender;
- (void)takePhoto:(id)sender;

@end

@implementation ViewController



- (void)loadView 
{
	CGRect mainScreenFrame = [[UIScreen mainScreen] bounds];
    
    // Yes, I know I'm a caveman for doing all this by hand
	GPUImageView *primaryView = [[GPUImageView alloc] initWithFrame:mainScreenFrame];
	primaryView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    float viewWidth = mainScreenFrame.size.width;
    float viewHeight = mainScreenFrame.size.height;
        
    // slider
    filterSettingsSlider = [[UISlider alloc] initWithFrame:CGRectMake(viewWidth*0.1,
                                                                      IS_PAD()? viewHeight*0.8 : viewHeight*.7, 
                                                                      viewWidth *.8, viewHeight * .1)];
    
    [filterSettingsSlider setThumbTintColor:[UIColor orangeColor]];
    [filterSettingsSlider setMinimumTrackTintColor:[UIColor orangeColor]];
    [filterSettingsSlider setBackgroundColor:[UIColor clearColor]];
    [filterSettingsSlider addTarget:self action:@selector(updateSliderValue:) forControlEvents:UIControlEventValueChanged];
	filterSettingsSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    filterSettingsSlider.minimumValue = 0.0;
    filterSettingsSlider.maximumValue = 3.0;
    filterSettingsSlider.value = 1.0;
    
    [primaryView addSubview:filterSettingsSlider];
    
    //time label for recording 
    timingLabel = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth - 200.0, 10., 180.0, 20.)];
    timingLabel.backgroundColor = [UIColor clearColor];
    timingLabel.textColor = [UIColor redColor];
    timingLabel.textAlignment = UITextAlignmentRight;
    timingLabel.hidden = YES;
    [primaryView addSubview:timingLabel];
    
    //capture button
    photoCaptureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    DLog(@"TAKE_PIC_BTN_WIDTH %f and %f",TAKE_PIC_BTN_WIDTH , IS_PAD() ? 80.0 : 60. );
    photoCaptureButton.frame = CGRectMake(viewWidth - TAKE_PIC_BTN_WIDTH , 
                                          viewHeight/2, 
                                          TAKE_PIC_BTN_WIDTH, 
                                          TAKE_PIC_BTN_HEIGHT);
    
    DLog(@"frame %@", NSStringFromCGRect(photoCaptureButton.frame));
    [photoCaptureButton setImage:[UIImage imageNamed:kStillCaptureImage] forState:UIControlStateNormal];
	photoCaptureButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [photoCaptureButton addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [primaryView addSubview:photoCaptureButton];
    
    //Bottom controller panel 
    
    UIView *bottomControlPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 
                                                                          IS_PAD()? viewHeight*0.9 : viewHeight*.82, 
                                                                          viewWidth, 
                                                                          IS_PAD()? viewHeight*0.1 : viewHeight*0.18)];
    bottomControlPanel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wood.jpg"]];
    bottomControlPanel.layer.cornerRadius = 10.0;
    bottomControlPanel.layer.shadowOffset = CGSizeMake(-10, -8);
    bottomControlPanel.layer.shadowOpacity = 0.5;
    bottomControlPanel.layer.shadowColor = [UIColor blackColor].CGColor;
        
    // thumb 
    thumbCapturedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(BOTTOM_OFFSET_X, BOTTOM_OFFSET_Y,  (int)roundf( CAPTURED_THUMB_IMAGE_HEIGHT), (int)roundf(CAPTURED_THUMB_IMAGE_HEIGHT))];
    DLog(@"thumb frame is %@", NSStringFromCGRect(thumbCapturedImageView.frame));
    thumbCapturedImageView.backgroundColor = [UIColor clearColor];
    
    //thumbCapturedImageView.layer.cornerRadius = 8.0;
    thumbCapturedImageView.layer.borderColor = [UIColor orangeColor].CGColor;
    thumbCapturedImageView.layer.borderWidth = 2.0;
    
    thumbCapturedImageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [thumbCapturedImageView addGestureRecognizer:tapGesture];

    [bottomControlPanel addSubview:thumbCapturedImageView];


    // switch from photo and video 
    photoSwitchVideo = [[UISwitch alloc] initWithFrame:CGRectMake(viewWidth - BOTTOM_OFFSET_X*2 - BOTTOM_SWITCH_WIDTH, 
                                                                            MAX(0.f, bottomControlPanel.frame.size.height/2 - BOTTOM_SWITCH_HEIGHT),
                                                                            BOTTOM_SWITCH_WIDTH, 
                                                                            MIN(BOTTOM_SWITCH_HEIGHT,bottomControlPanel.frame.size.height))];
    [photoSwitchVideo setOnTintColor:[UIColor redColor]];
    photoSwitchVideo.backgroundColor = [UIColor clearColor];
    [photoSwitchVideo addTarget:self action:@selector(switchVideo:) forControlEvents:UIControlEventTouchUpInside];
    [bottomControlPanel addSubview:photoSwitchVideo];
    
    
    
    // swich of front/back camera 
    switchFrontBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [switchFrontBackButton setImage:[UIImage imageNamed:@"camera@72.png"] forState:UIControlStateNormal];

    switchFrontBackButton.frame = CGRectMake(photoSwitchVideo.frame.origin.x - 64. - GAP_X/2 , 
                                             GAP_Y/2 , 
                                             IS_PAD()? 64.:48., 
                                             IS_PAD() ? 64.:48.);
    [bottomControlPanel addSubview:switchFrontBackButton];
    [switchFrontBackButton addTarget:self action:@selector(switchCameras:) forControlEvents:UIControlEventTouchUpInside];

    [primaryView addSubview:bottomControlPanel];
    
    //white flash screen
    whiteFlashView = [[UIView alloc] initWithFrame:primaryView.bounds];
    whiteFlashView.backgroundColor = [UIColor whiteColor];
    whiteFlashView.alpha = 0;
    [primaryView addSubview:whiteFlashView];
    
	self.view = primaryView;	
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    stillCamera = [[GPUImageStillCamera alloc] init];
    //stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    filter = [[GPUImageSketchFilter alloc] init];
  
    
	[filter prepareForImageCapture];
    
    [stillCamera addTarget:filter];
    GPUImageView *filterView = (GPUImageView *)self.view;
    [filter addTarget:filterView];

    captureStillImage = YES;
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

- (void) onTap:(id)sender{
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
    [self.view.layer addAnimation:animation forKey:nil];

    [stillCamera rotateCamera];
}

- (void) switchVideo:(id)sender{
    captureStillImage = !captureStillImage;
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = 1.0;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    animation.type = captureStillImage ? @"fromRight" : @"fromLeft";
    animation.type = @"flip";
    [photoCaptureButton.layer addAnimation:animation forKey:@"image"];
    
    if (!captureStillImage) {
        [photoCaptureButton setImage:[UIImage imageNamed:kVideoStartRecordImage] forState:UIControlStateNormal];
    }else {
        [photoCaptureButton setImage:[UIImage imageNamed:kStillCaptureImage] forState:UIControlStateNormal];
    }
}


- (void)updateSliderValue:(id)sender
{
    float value = [(UISlider*)sender value] ;
    [(GPUImageSketchFilter *)filter setTexelHeight:(value / 480.0)];
    [(GPUImageSketchFilter *)filter setTexelWidth:(value / 360.0)];
    
}

#define FREETIMES_LIMITATION  2 
#define kMyProduct @"com.dfa.sketchcam.takephoto"
/*
 
 ISSUE: For the iPad2, there are some random noise when capturing photo 
 It is obvious for the back camera.
 */
- (void)takePhoto:(id)sender;
{
    // IN APP PURCHASE 
    
//    id valueOfTimes = [[NSUserDefaults standardUserDefaults] objectForKey:@"usedTimes"];
//    if (valueOfTimes == nil) {
//        usedTimesOfCapture = 0;
//    }else {
//        usedTimesOfCapture = [valueOfTimes intValue];
//    }
//    
//    usedTimesOfCapture++;
//    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:usedTimesOfCapture] forKey:@"usedTimes"];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//
//    
//    DLog(@"used times %d",usedTimesOfCapture);
//    
//    if (usedTimesOfCapture > FREETIMES_LIMITATION ) {
//        [[MKStoreManager sharedManager] buyFeature:kMyProduct onComplete:^(NSString *purchasedFeature, NSData *purchasedReceipt) {
//            //
//            DLog(@"DEBUG %@ %@", purchasedFeature, purchasedReceipt);
//        } onCancelled:^{
//            //
//            DLog(@"DEBUG");
//        }];
//    }
    
    if (!captureStillImage) {
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

@end
