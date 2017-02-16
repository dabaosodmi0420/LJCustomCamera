//
//  ViewController.m
//  LJCustomCamera
//
//  Created by Apple on 2017/2/16.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "ViewController.h"
#import "LJCustomCameraViewController.h"
@interface ViewController ()<LJCustomCameraDelegate>

/** <# explain #> */
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
    _imageView = [[UIImageView alloc]initWithFrame:self.view.bounds];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_imageView];
    // Do any additional setup after loading the view, typically from a nib.
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    [self presentViewController:[[LJCustomCameraViewController alloc]init] animated:YES completion:nil];
    LJCustomCameraViewController *vc = [[LJCustomCameraViewController alloc]init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
    
}
- (void)ljCustomCamera:(UIImage *)image{
    _imageView.image = image;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
