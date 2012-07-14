//
//  FSHomeViewController.m
//  SketchCam
//
//  Created by Shi Forrest on 12-6-28.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "FSHomeViewController.h"
#import "FSCameraFilterViewController.h"
#import "SCFacebook.h"

@interface FSHomeViewController ()<UIImagePickerControllerDelegate>{
    UIButton    *_imageFilterButton;
    UIButton    *_cameraFilterButton;
    UIButton    *_loginFBButton;
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

    if (!_loginFBButton) {
        UIImage *loginImage = [UIImage imageNamed:@"facebook-login.png"];
        _loginFBButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _loginFBButton.backgroundColor = [UIColor clearColor];
        _loginFBButton.frame = CGRectMake(self.view.bounds.size.width/2 - loginImage.size.width/2 ,self.view.bounds.size.height/2 , 216, 40);
        [_loginFBButton setImage:loginImage forState:UIControlStateNormal];
        [_loginFBButton addTarget:self action:@selector(loginFB:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_loginFBButton];
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
    self.view.backgroundColor = [UIColor whiteColor];

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

#pragma mark - Actions of Buttons

//- (void)launchImageFilter:(id)sender{
//
//    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
//    ipc.delegate = self;
//    
//    [self presentViewController:ipc animated:YES completion:^{
//        //
//    }];
//}

- (void)launchCameraFilter:(id)sender{
    [self hideSubviewsBeforeLeave];
    self.view.backgroundColor = [UIColor clearColor];
    
    FSCameraFilterViewController *camVC = [[FSCameraFilterViewController alloc] initCameraFX];
    camVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    [self presentViewController:camVC animated:YES completion:^{
        
    }];
}

- (void)loginFB:(id)sender{
    
    [SCFacebook loginCallBack:^(BOOL success, id result) {
        //loadingView.hidden = YES;
        if (success) {
            //[self getUserInfo];
            DLog(@"DEBUG %@",result);
        }
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
