//
//  LJCustomCameraViewController.m
//  LJCustomCamera
//
//  Created by Apple on 2017/2/16.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "LJCustomCameraViewController.h"
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIOBase.h>
#import <CoreMotion/CoreMotion.h>

#define LJCustomCamera_IphoneW [UIScreen mainScreen].bounds.size.width
#define LJCustomCamera_IphoneH [UIScreen mainScreen].bounds.size.height

#define LJCustomBackgroundColor_Alpha 0.6
#define LJCustomBackgroundColor [[UIColor blackColor]colorWithAlphaComponent:LJCustomBackgroundColor_Alpha]
static CGFloat LJCustomCamera_DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";

@interface LJCustomCameraViewController (){
    UIImage *_chooseImage;
    
    //自动识别框
    CIDetector *faceDetector;
    //框的图片
    UIImage *square;
    //照片出处data
    AVCaptureVideoDataOutput *videoDataOutput;
    //用来判断使用的是前摄像头还是后摄像头
    BOOL isUsingFrontFacingCamera;
    //获取图像数据线程
    dispatch_queue_t videoDataOutputQueue;
    CGFloat effectiveScale;
    
    AVCaptureVideoOrientation orientation;
    
    //获取拍照方向
    CMMotionManager *motionManager;
    NSOperationQueue *queue;
    UIInterfaceOrientation deviceOrientation;
    
    // 是否显示导航栏
    BOOL _isShowNavBar;
}

//AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
@property (nonatomic, strong)AVCaptureSession *session;
//AVCaptureDeviceInput对象是输入流
@property (nonatomic, strong)AVCaptureDeviceInput *videoInput;
//照片输出流对象，当然我的照相机只有拍照功能，所以只需要这个对象就够了
@property (nonatomic, strong)AVCaptureStillImageOutput *stillImageOutput;
//预览图层，来显示照相机拍摄到的画面
@property (nonatomic, strong)AVCaptureVideoPreviewLayer *previewLayer;

//切换前后镜头的按钮
@property (nonatomic, strong)UIButton *toggleButton;
@property (strong, nonatomic)UIButton *cancel;
//拍照按钮
@property (strong, nonatomic)UIButton *shutterButton;
//重拍按钮
@property (nonatomic, strong)UIButton *reShutterButton;
//使用照片
@property (nonatomic, strong)UIButton *saveImageButton;
//放置预览图层的View
@property (nonatomic, strong)UIView *cameraShowView;
@property (strong, nonatomic)UILabel *hintLabel;
@property (strong, nonatomic)UIView *chooseView;



@end

@implementation LJCustomCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    /** 初始化页面 */
    [self initUI];
    
    [self changeBtn:YES];
    [self initialSession];
    motionManager = [[CMMotionManager alloc]init];
    queue = [[NSOperationQueue alloc]init];
    
    [self getDeviceOrientation];
}
- (void)initUI{
    
    /** 上下左右覆盖View */
    CGFloat topViewH = 90;
    CGFloat bottomViewH = 93;
    CGFloat leftRightW = 34;
    
    UIView *topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, LJCustomCamera_IphoneW, topViewH)];
    topView.backgroundColor = LJCustomBackgroundColor;
    [self.view addSubview:topView];
    
    UIView *bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, LJCustomCamera_IphoneH - bottomViewH, LJCustomCamera_IphoneW, bottomViewH)];
    bottomView.backgroundColor = LJCustomBackgroundColor;
    [self.view addSubview:bottomView];
    
    UIView *leftView = [[UIView alloc]initWithFrame:CGRectMake(0, topViewH, leftRightW, LJCustomCamera_IphoneH - topViewH - bottomViewH)];
    leftView.backgroundColor = LJCustomBackgroundColor;
    [self.view addSubview:leftView];
    
    UIView *rightView = [[UIView alloc]initWithFrame:CGRectMake(LJCustomCamera_IphoneW - leftRightW, topViewH, leftRightW,  LJCustomCamera_IphoneH - topViewH - bottomViewH)];
    rightView.backgroundColor = LJCustomBackgroundColor;
    [self.view addSubview:rightView];
    
    /** 中间显示View */
    self.chooseView = [[UIView alloc]initWithFrame:CGRectMake(leftRightW, topViewH, LJCustomCamera_IphoneW - 2 * leftRightW, LJCustomCamera_IphoneH - topViewH - bottomViewH)];
    self.chooseView.backgroundColor = [UIColor clearColor];
    self.chooseView.layer.borderWidth = 3.f;
    self.chooseView.layer.borderColor = [UIColor colorWithRed:1.0 green:170/255.0 blue:36/255.0 alpha:1].CGColor;
    [self.view addSubview:self.chooseView];
    
    /** 中间提示Label */
    self.hintLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 350, 30)];
    self.hintLabel.center = self.view.center;
    self.hintLabel.font = [UIFont systemFontOfSize:25];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.text = @"请横屏拍摄";
    self.hintLabel.textColor = [UIColor orangeColor];
    self.hintLabel.layer.affineTransform = CGAffineTransformMakeRotation(M_PI_2);
    [self.view addSubview:self.hintLabel];
    
    /** 添加按钮 */
    CGFloat buttonW = 70;
    CGFloat buttonH = 50;
    CGFloat buttonSpace = 10;
    
    // 取消按钮
    self.cancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.cancel.frame = CGRectMake(buttonSpace, LJCustomCamera_IphoneH - buttonH - buttonSpace, buttonW, buttonH);
    [self.cancel setTitle:@"取消" forState:UIControlStateNormal];
    [self.cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.cancel.titleLabel.font = [UIFont systemFontOfSize:25];
    [self.cancel addTarget:self action:@selector(cancelChoose:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancel];
    // 重拍按钮
    self.reShutterButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.reShutterButton.frame = CGRectMake(buttonSpace, LJCustomCamera_IphoneH - buttonH - buttonSpace, buttonW, buttonH);
    [self.reShutterButton setTitle:@"重拍" forState:UIControlStateNormal];
    [self.reShutterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.reShutterButton.titleLabel.font = [UIFont systemFontOfSize:25];
    [self.reShutterButton addTarget:self action:@selector(reShutter:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.reShutterButton];
    // 使用按钮
    self.saveImageButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.saveImageButton.frame = CGRectMake(LJCustomCamera_IphoneW - buttonSpace - buttonW, LJCustomCamera_IphoneH - buttonH - buttonSpace, buttonW, buttonH);
    [self.saveImageButton setTitle:@"使用" forState:UIControlStateNormal];
    [self.saveImageButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveImageButton.titleLabel.font = [UIFont systemFontOfSize:25];
    [self.saveImageButton addTarget:self action:@selector(saveImage:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.saveImageButton];
    // 拍照按钮
    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shutterButton.frame = CGRectMake((LJCustomCamera_IphoneW - 50) * 0.5, LJCustomCamera_IphoneH - 50 - buttonSpace, 50, 50);
    [self.shutterButton setImage:[UIImage imageNamed:@"PS1"] forState:UIControlStateNormal];
    [self.shutterButton addTarget:self action:@selector(shutDown:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.shutterButton];
    
}

- (void)getDeviceOrientation{
    if (motionManager.accelerometerAvailable) {
        motionManager.accelerometerUpdateInterval = 0.1f;
        [motionManager startAccelerometerUpdatesToQueue:queue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            CGFloat x = accelerometerData.acceleration.x;
            CGFloat y = accelerometerData.acceleration.y;
            CGFloat angle = atan2f(y, x);
            if(angle >= -2.25 && angle <= -0.25)
            {
                if(deviceOrientation != UIInterfaceOrientationPortrait)
                {
                    deviceOrientation = UIInterfaceOrientationPortrait;
                }
            }
            else if(angle >= -1.75 && angle <= 0.75)
            {
                if(deviceOrientation != UIInterfaceOrientationLandscapeRight)
                {
                    deviceOrientation = UIInterfaceOrientationLandscapeRight;
                }
            }
            else if(angle >= 0.75 && angle <= 2.25)
            {
                if(deviceOrientation != UIInterfaceOrientationPortraitUpsideDown)
                {
                    deviceOrientation = UIInterfaceOrientationPortraitUpsideDown;
                }
            }
            else if(angle <= -2.25 || angle >= 2.25)
            {
                if(deviceOrientation != UIInterfaceOrientationLandscapeLeft)
                {
                    deviceOrientation = UIInterfaceOrientationLandscapeLeft;
                }
            }
        }];
    }
}

-  (void) initialSession
{
    //1.这个方法的执行我放在init方法里了
    self.session = [[AVCaptureSession alloc] init];
    //    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //    captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    //2.初始化输入设备
    //[self fronCamera]方法会返回一个AVCaptureDevice对象，因为我初始化时是采用前摄像头，所以这么写，具体的实现方法后面会介绍
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backCamera] error:nil];
    
    //3.设置照片的输出设备
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    //这是输出流的设置参数AVVideoCodecJPEG参数表示以JPEG的图片格式输出图片
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    //    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext)];
    //    effectiveScale = 1.0;
    //4.将输入、输出设备添加到AVCaptureSession中
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    
    [self setUpCameraLayer];
}

- (void)setAutoCamera{
    videoDataOutput = [AVCaptureVideoDataOutput new];
    
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                       [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ( [_session canAddOutput:videoDataOutput] )
        [_session addOutput:videoDataOutput];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
    
    //    square = [UIImage imageNamed:@"squarePNG"];
    //    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    //CIDetectorTypeRectangle:自动识别框。
    //    faceDetector = [CIDetector detectorOfType:CIDetectorTypeRectangle context:nil options:detectorOptions];
    //
    //    detectFaces = YES;
    //
    //    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:detectFaces];
    //    if (!detectFaces) {
    //        dispatch_async(dispatch_get_main_queue(), ^(void) {
    // clear out any squares currently displaying.
    //            [self drawFaceBoxesForFeatures:[NSArray array] forVideoBox:CGRectZero orientation:UIDeviceOrientationPortrait];
    //        });
    //    }
}
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    NSArray *sublayers = [NSArray arrayWithArray:[_previewLayer sublayers]];
    NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
    NSInteger featuresCount = [features count], currentFeature = 0;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    // hide all the face layers
    for ( CALayer *layer in sublayers ) {
        if ( [[layer name] isEqualToString:@"FaceLayer"] )
            [layer setHidden:YES];
    }
    
    if ( featuresCount == 0 || !detectFaces ) {
        [CATransaction commit];
        return; // early bail.
    }
    
    CGSize parentFrameSize = [_previewLayer frame].size;
    NSString *gravity = [_previewLayer videoGravity];
    BOOL isMirrored = [_previewLayer isMirrored];
    CGRect previewBox = [LJCustomCameraViewController videoPreviewBoxForGravity:gravity frameSize:parentFrameSize apertureSize:clap.size];
    
    for ( CIFaceFeature *ff in features ) {
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];
        
        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        
        if ( isMirrored )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
        else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        
        CALayer *featureLayer = nil;
        
        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }
        
        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [CALayer new];
            [featureLayer setContents:(id)[square CGImage]];
            [featureLayer setName:@"FaceLayer"];
            [_previewLayer addSublayer:featureLayer];
        }
        [featureLayer setFrame:faceRect];
        
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(LJCustomCamera_DegreesToRadians(0.))];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(LJCustomCamera_DegreesToRadians(180.))];
                break;
            case UIDeviceOrientationLandscapeLeft:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(LJCustomCamera_DegreesToRadians(90.))];
                break;
            case UIDeviceOrientationLandscapeRight:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(LJCustomCamera_DegreesToRadians(-90.))];
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                break; // leave the layer in its last known orientation
        }
        currentFeature++;
    }
    
    [CATransaction commit];
}
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
}
//获取当前照片时时代理
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // got an image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    if (attachments)
        CFRelease(attachments);
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    NSArray *features = [faceDetector featuresInImage:ciImage options:imageOptions];
    if (features.count != 0) {
        //        NSLog(@"%@",features);
    }
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
    });
}


- (void)changeBtn:(BOOL)isShutter{
    
    if (isShutter) {
        [self getDeviceOrientation];
    }else{
        [motionManager stopAccelerometerUpdates];
    }
    _saveImageButton.hidden = isShutter;
    _reShutterButton.hidden = isShutter;
    _hintLabel.hidden = !isShutter;
    _cancel.hidden = !isShutter;
    _shutterButton.hidden = !isShutter;
}
- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.session) {
        [self.session startRunning];
    }
    
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (!self.navigationController.navigationBarHidden) {
        _isShowNavBar = YES;
        self.navigationController.navigationBarHidden = YES;
    }
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (_isShowNavBar) {
        self.navigationController.navigationBarHidden = NO;
    }
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear: animated];
    if (self.session) {
        [self.session stopRunning];
    }
    
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}
//开启前摄像头
- (AVCaptureDevice *)frontCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}
//开启后摄像头
- (AVCaptureDevice *)backCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}
- (void) setUpCameraLayer
{
    if (self.previewLayer == nil) {
        self.cameraShowView = [[UIView alloc]initWithFrame:self.view.frame];
        [self.view insertSubview:self.cameraShowView atIndex:0];
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        UIView * view = self.cameraShowView;
        CALayer * viewLayer = [view layer];
        [viewLayer setMasksToBounds:YES];
        
        CGRect bounds = [view bounds];
        // 设置预览Layer的大小和位置
        [self.previewLayer setFrame:bounds];
        // 设置预览Layer的缩放方式
        [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
        // 将预览Layer添加到预览UIView上
        [viewLayer insertSublayer:self.previewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
        
    }
}


//按尺寸压缩
- (UIImage *)shrinkImage:(UIImage *)original toSize:(CGSize)size{
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [original drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *final = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return final;
}
-(UIImage *)getClipImageFromImage:(UIImage *)bigImage{
    
    UIImage *shinkImage = [self shrinkImage:bigImage toSize:self.view.bounds.size];
    //获取当前屏幕的像素
    CGFloat pixel = [UIScreen mainScreen].scale;
    //定义myImageRect，截图的区域
    
    CGRect myImageRect = _chooseView.frame;
    
    //以像素为单位
    CGFloat x = myImageRect.origin.x*pixel;
    CGFloat y = myImageRect.origin.y*pixel;
    CGFloat w = myImageRect.size.width*pixel;
    CGFloat h = myImageRect.size.height*pixel;
    
    CGRect rect = CGRectMake(x, y, w, h);
    //裁剪图片
    CGImageRef smallImage = CGImageCreateWithImageInRect(shinkImage.CGImage, rect);
    
    UIGraphicsBeginImageContext(myImageRect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextRotateCTM(context, M_PI_2);
    CGContextDrawImage(context, myImageRect, smallImage);
    
    UIImage* smallImage1 = [UIImage imageWithCGImage:smallImage];
    CGImageRelease(smallImage);
    
    UIGraphicsEndImageContext();
    //    CGContextRelease(context);
    
    return smallImage1;
    
}
#pragma mark - 图片旋转方法
- (UIImage *)image:(UIImage *)image rotation:(UIInterfaceOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation) {
        case UIDeviceOrientationLandscapeRight:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIDeviceOrientationLandscapeLeft:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //做CTM变换
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    CGContextScaleCTM(context, scaleX, scaleY);
    
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //    CGContextRelease(context);
    return newPic;
}

//拍照
- (void)shutDown:(id)sender {
    // 获取拍照的AVCaptureConnection
    AVCaptureConnection * videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    [self.stillImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:AVVideoCodecJPEG forKey:AVVideoCodecKey]];
    // 拍照并保存
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        // 如果图片缓存为NULL
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        
        UIImage * image = [UIImage imageWithData:imageData];
        
        //        NSLog(@"%ld",(long)deviceOrientation);
        //裁剪后
        _chooseImage = [self getClipImageFromImage:image];
        _chooseImage = [self image:_chooseImage rotation:deviceOrientation];
        
        [self.session stopRunning];
        [self changeBtn:NO];
        if (_isSaveLibrary) {
            //保存到相册
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,imageDataSampleBuffer,kCMAttachmentMode_ShouldPropagate);
            
            [library writeImageDataToSavedPhotosAlbum:imageData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    [self displayErrorOnMainQueue:error withMessage:@"Save to camera roll failed"];
                }
            }];
            
            //            NSLog(@"image size = %@",NSStringFromCGSize(image.size));
            if (attachments)
                CFRelease(attachments);
        }
        
    }];
    
}


//图片合并
- (UIImage *)addImage:(UIImage *)image1 toImage:(UIImage *)image2 {
    UIGraphicsBeginImageContext(image1.size);
    
    // Draw image1
    [image1 drawInRect:CGRectMake(0, 0, image1.size.width, image1.size.height)];
    
    // Draw image2
    [image2 drawInRect:CGRectMake(0, 0, image2.size.width, image2.size.height)];
    
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resultingImage;
}

//重拍
- (void)reShutter:(id)sender {
    _chooseImage = nil;
    [self changeBtn:YES];
    [self.session startRunning];
    
}
//取消
- (void)cancelChoose:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
    //    [self dismissViewControllerAnimated:YES completion:nil];
    _chooseImage = nil;
}
//使用
- (void)saveImage:(id)sender{
    if ([self.delegate respondsToSelector:@selector(ljCustomCamera:)]) {
        [self.delegate ljCustomCamera:_chooseImage];
    }
    _chooseImage = nil;
    [self.navigationController popViewControllerAnimated:YES];
    //    [self dismissViewControllerAnimated:YES completion:nil];
}

//改变摄像头
- (void)changeCamera:(id)sender {
    
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount > 1) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[_videoInput device] position];
        
        if (position == AVCaptureDevicePositionBack)
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontCamera] error:&error];
        else if (position == AVCaptureDevicePositionFront)
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backCamera] error:&error];
        else
            return;
        
        if (newVideoInput != nil) {
            [self.session beginConfiguration];
            [self.session removeInput:self.videoInput];
            if ([self.session canAddInput:newVideoInput]) {
                [self.session addInput:newVideoInput];
                [self setVideoInput:newVideoInput];
            } else {
                [self.session addInput:self.videoInput];
            }
            [self.session commitConfiguration];
        } else if (error) {
            //            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
    
}

- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
