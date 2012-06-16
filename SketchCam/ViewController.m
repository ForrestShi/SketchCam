//
//  ViewController.m
//  SketchCam
//
//  Created by Shi Forrest on 12-6-16.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>


@interface ViewController () <UIImagePickerControllerDelegate , UIPopoverControllerDelegate>{
    GPUImageStillCamera *stillCamera;
    GPUImageOutput<GPUImageInput> *filter;
    UISlider *filterSettingsSlider;
    UIButton *photoCaptureButton;
    UIImageView *thumbCapturedImageView;
    UIView *whiteFlashView ;
    UIPopoverController *popoverCtr;
    BOOL            captureStillImage;
    BOOL            isRecording;
    GPUImageMovieWriter* movieWriter;
    NSURL *movieURL ;
}

- (void)updateSliderValue:(id)sender;
- (void)takePhoto:(id)sender;

@end

@implementation ViewController


#define SWITCH_CAMERA_WIDTH     80.0
#define SWITCH_CAMERA_HEIGHT    60.0
#define GAP_X                   30.0 
#define GAP_Y                   30.0


#define TAKE_PIC_BTN_WIDTH     80.0
#define TAKE_PIC_BTN_HEIGHT    60.0

#define BOTTOM_OFFSET_X        10.0
#define BOTTOM_OFFSET_Y        10.0

#define CAPTURED_THUMB_IMAGE_HEIGHT ((IS_PAD())? 102.4 *0.8 : 48 * 1.5 * 0.8)
#define CAPTURED_THUMB_IMAGE_WIDTH  CAPTURED_THUMB_IMAGE_HEIGHT * ( (IS_PAD()) ? 768.0/1024.0 : 320./480. )

#define BOTTOM_SWITCH_WIDTH         80.0
#define BOTTOM_SWITCH_HEIGHT        20.0


- (void)loadView 
{
	CGRect mainScreenFrame = [[UIScreen mainScreen] bounds];
    
    // Yes, I know I'm a caveman for doing all this by hand
	GPUImageView *primaryView = [[GPUImageView alloc] initWithFrame:mainScreenFrame];
	primaryView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    float viewWidth = mainScreenFrame.size.width;
    float viewHeight = mainScreenFrame.size.height;
        
    // slider
    filterSettingsSlider = [[UISlider alloc] initWithFrame:CGRectMake(viewWidth*0.1, viewHeight * 0.8, 
                                                                      viewWidth *.8, viewHeight * .1)];
    
    [filterSettingsSlider addTarget:self action:@selector(updateSliderValue:) forControlEvents:UIControlEventValueChanged];
	filterSettingsSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    filterSettingsSlider.minimumValue = 0.0;
    filterSettingsSlider.maximumValue = 3.0;
    filterSettingsSlider.value = 1.0;
    
    [primaryView addSubview:filterSettingsSlider];
    
    //capture button
    photoCaptureButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    photoCaptureButton.frame = CGRectMake(viewWidth - TAKE_PIC_BTN_WIDTH - GAP_X, 
                                          viewHeight/2, 
                                          TAKE_PIC_BTN_WIDTH, 
                                          TAKE_PIC_BTN_HEIGHT);
    
    [photoCaptureButton setTitle:@"Capture Photo" forState:UIControlStateNormal];
	photoCaptureButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [photoCaptureButton addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [photoCaptureButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [primaryView addSubview:photoCaptureButton];

    
    
    
    //Bottom controller panel 
    
    UIView *bottomControlPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 
                                                                          IS_PAD()? viewHeight*0.9 : viewHeight*.85, 
                                                                          viewWidth, 
                                                                          IS_PAD()? viewHeight*0.1 : viewHeight*0.15)];
    bottomControlPanel.backgroundColor = [UIColor clearColor];
    
        
    // thumb 
    thumbCapturedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(BOTTOM_OFFSET_X, BOTTOM_OFFSET_Y,  (int)roundf( CAPTURED_THUMB_IMAGE_WIDTH), (int)roundf(CAPTURED_THUMB_IMAGE_HEIGHT))];
    DLog(@"thumb frame is %@", NSStringFromCGRect(thumbCapturedImageView.frame));
    
    thumbCapturedImageView.backgroundColor = [UIColor redColor];
    thumbCapturedImageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [thumbCapturedImageView addGestureRecognizer:tapGesture];

    [bottomControlPanel addSubview:thumbCapturedImageView];


    // switch from photo and video 
    UISwitch *photoSwitchVideo = [[UISwitch alloc] initWithFrame:CGRectMake(
                                                                            viewWidth - BOTTOM_OFFSET_X - BOTTOM_SWITCH_WIDTH, 
                                                                            bottomControlPanel.frame.size.height/2 - BOTTOM_SWITCH_HEIGHT/2,
                                                                            BOTTOM_SWITCH_WIDTH, 
                                                                            BOTTOM_SWITCH_HEIGHT)];
    [photoSwitchVideo addTarget:self action:@selector(switchVideo:) forControlEvents:UIControlEventTouchUpInside];
    photoSwitchVideo.backgroundColor = [UIColor clearColor];
    [bottomControlPanel addSubview:photoSwitchVideo];
    
    
    
    // swich of front/back camera 
    UIButton *switchFrontBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    switchFrontBackButton.backgroundColor = [UIColor blueColor];
    switchFrontBackButton.frame = CGRectMake(photoSwitchVideo.frame.origin.x - 100. , 
                                             photoSwitchVideo.frame.origin.y, 
                                             60., 40.);
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return UIInterfaceOrientationIsPortrait(interfaceOrientation);
    }
}
#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    DLog(@"DEBUG");

    [stillCamera resumeCameraCapture];
    [picker dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    DLog(@"DEBUG");

    [stillCamera resumeCameraCapture];
    [picker dismissModalViewControllerAnimated:YES];
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
    [stillCamera rotateCamera];
}

- (void) switchVideo:(id)sender{
    captureStillImage = !captureStillImage;
}


- (void)updateSliderValue:(id)sender
{
    float value = [(UISlider*)sender value] ;
    [(GPUImageSketchFilter *)filter setTexelHeight:(value / 480.0)];
    [(GPUImageSketchFilter *)filter setTexelWidth:(value / 360.0)];
    
}

/*
 
 ISSUE: For the iPad2, there are some random noise when capturing photo 
 It is obvious for the back camera.
 */
- (void)takePhoto:(id)sender;
{
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

- (void) recordVideo{
    if (isRecording) {
        [self stopRecording];
    }else {
        [self startRecording];
    }        
}

- (void) startRecording{
    
    isRecording = YES;
    photoCaptureButton.titleLabel.text = @"Recording";
    
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
    
    isRecording = NO;
    photoCaptureButton.titleLabel.text = @"Stop";

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
