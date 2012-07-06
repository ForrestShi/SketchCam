//
//  FSHomeViewController.m
//  SketchCam
//
//  Created by Shi Forrest on 12-6-28.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "FSHomeViewController.h"
#import "FSCameraFilterViewController.h"


@interface FSHomeViewController ()<UIImagePickerControllerDelegate>{
    UIButton    *_imageFilterButton;
    UIButton    *_cameraFilterButton;
}

@end

@implementation FSHomeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor blackColor];
    
    if (!_imageFilterButton) {
        _imageFilterButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        _imageFilterButton.frame = CGRectMake(100, 100, 100, 60);
        [_imageFilterButton addTarget:self action:@selector(launchImageFilter:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_imageFilterButton];
    }
    
    if (!_cameraFilterButton) {
        _cameraFilterButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        _cameraFilterButton.frame = CGRectMake(100, 200, 100, 60);
        [_cameraFilterButton addTarget:self action:@selector(launchCameraFilter:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_cameraFilterButton];
    }

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    DLog(@"DEBUG");
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    DLog(@"DEBUG");
    
    for (UIView* subView in [self.view subviews]) {
        subView.alpha = 1.;
    } 

}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    DLog(@"DEBUG");
    [self hideSubviewsBeforeLeave];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)hideSubviewsBeforeLeave{
    for (UIView* subView in [self.view subviews]) {
        subView.alpha = 0.;
    } 
}

- (void)launchImageFilter:(id)sender{

    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.delegate = self;
    
    [self presentViewController:ipc animated:YES completion:^{
        //
    }];
    
    
}

- (void)launchCameraFilter:(id)sender{
    
    FSCameraFilterViewController *camVC = [[FSCameraFilterViewController alloc] initCameraFX];
    [self presentViewController:camVC animated:YES completion:^{
        
    }];
}

#pragma mark - UIImagePickerControllerDelegate 

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    DLog(@"DEBUG");
    
    UIImage *selectedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    [self hideSubviewsBeforeLeave];

    [picker dismissViewControllerAnimated:YES completion:^{
        
        FSCameraFilterViewController *camVC = [[FSCameraFilterViewController alloc] initWithPicture:selectedImage];
        [self presentViewController:camVC animated:YES completion:^{
            
        }];

    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:^{
        
    }];
}


@end
