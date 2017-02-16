//
//  LJCustomCameraViewController.h
//  LJCustomCamera
//
//  Created by Apple on 2017/2/16.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol LJCustomCameraDelegate <NSObject>
- (void)ljCustomCamera:(UIImage *)image;

@end

@interface LJCustomCameraViewController : UIViewController
{
    BOOL detectFaces;
}


@property(nonatomic, assign)BOOL isSaveLibrary;

@property(nonatomic, weak)id <LJCustomCameraDelegate> delegate;


@end

