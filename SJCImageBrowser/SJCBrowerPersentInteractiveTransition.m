//
//  SJCBrowerPersentInteractiveTransition.m
//  Yehwang
//
//  Created by Yehwang on 2020/11/3.
//  Copyright © 2020 Yehwang. All rights reserved.
//

#import "SJCBrowerPersentInteractiveTransition.h"
#import "SJCImageBrowser.h"
#import "HXPhotoSubViewCell.h"

@interface SJCBrowerPersentInteractiveTransition () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) id<UIViewControllerContextTransitioning> transitionContext;
@property (nonatomic, weak) UIViewController *vc;
@property (weak, nonatomic) HXPreviewContentView *contentView;
@property (strong, nonatomic) UIView *bgView;
@property (weak, nonatomic) HXPhotoSubViewCell *tempCell;
@property (weak, nonatomic) HXPhotoPreviewViewCell *fromCell;
@property (nonatomic, assign) CGPoint transitionImgViewCenter;
@property (nonatomic, assign) CGFloat beginX;
@property (nonatomic, assign) CGFloat beginY;
@property (weak, nonatomic) HXPhotoView *photoView;
@property (assign, nonatomic) BOOL isPanGesture;
@property (assign, nonatomic) CGFloat scrollViewZoomScale;
@property (assign, nonatomic) CGSize scrollViewContentSize;
@property (assign, nonatomic) CGPoint scrollViewContentOffset;
@property (assign, nonatomic) CGRect imageInitialFrame;
@property (strong, nonatomic) UIPanGestureRecognizer *panGesture;

@end

@implementation SJCBrowerPersentInteractiveTransition
- (void)addPanGestureForViewController:(UIViewController *)viewController {
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureRecognizeDidUpdate:)];
    self.panGesture.delegate = self;
    self.vc = viewController;
    if ([viewController isKindOfClass:[SJCImageBrowser class]]) {
        SJCImageBrowser *previewVC = (SJCImageBrowser *)self.vc;
        HXWeakSelf
        previewVC.currentCellScrollViewDidScroll = ^(UIScrollView *scrollView) {
            CGFloat offsetY = scrollView.contentOffset.y;
            if (offsetY < 0) {
                weakSelf.atFirstPan = YES;
            }else if (offsetY == 0) {
                if (weakSelf.interation) {
                    weakSelf.atFirstPan = NO;
                }
            }else {
                weakSelf.atFirstPan = NO;
            }
        };
    }
    [viewController.view addGestureRecognizer:self.panGesture];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer.view isKindOfClass:[UICollectionView class]]) {
        return NO;
    }
    if ([otherGestureRecognizer.view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)otherGestureRecognizer.view;
        if (scrollView.contentOffset.y <= 0 &&
            !scrollView.zooming && self.atFirstPan) {
            return YES;
        }
    }
    return NO;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    SJCImageBrowser *previewVC = (SJCImageBrowser *)self.vc;
    HXPhotoPreviewViewCell *viewCell = [previewVC currentPreviewCell:previewVC.modelArray[previewVC.currentModelIndex]];
    if (viewCell.scrollView.zooming ||
        viewCell.scrollView.zoomScale < 1.0f ||
        viewCell.scrollView.isZoomBouncing) {
        return NO;
    }
    [viewCell.scrollView setContentOffset:viewCell.scrollView.contentOffset animated:NO];
    return YES;
}
- (void)gestureRecognizeDidUpdate:(UIPanGestureRecognizer *)gestureRecognizer {
    CGFloat scale = 0;
    
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    CGFloat transitionY = translation.y;
    scale = transitionY / ((gestureRecognizer.view.frame.size.height - 50) / 2);
    if (scale > 1.f) {
        scale = 1.f;
    }
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            if (scale < 0) {
                [self.vc.view removeGestureRecognizer:self.panGesture];
                [self.vc.view addGestureRecognizer:self.panGesture];
                return;
            }
            self.isPanGesture = YES;
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
                [[UIApplication sharedApplication] setStatusBarHidden:NO];
#pragma clang diagnostic pop
            [(SJCImageBrowser *)self.vc setStopCancel:YES];
            self.beginX = [gestureRecognizer locationInView:gestureRecognizer.view].x;
            self.beginY = [gestureRecognizer locationInView:gestureRecognizer.view].y;
            self.interation = YES;
            [self.vc dismissViewControllerAnimated:YES completion:nil];
        } break;
        case UIGestureRecognizerStateChanged:
            if (self.interation) {
                if (scale < 0.f) {
                    scale = 0.f;
                }
                CGFloat imageViewScale = 1 - scale * 0.5;
                if (imageViewScale < 0.4) {
                    imageViewScale = 0.4;
                }
                self.contentView.center = CGPointMake(self.transitionImgViewCenter.x + translation.x, self.transitionImgViewCenter.y + translation.y);
                self.contentView.transform = CGAffineTransformMakeScale(imageViewScale, imageViewScale);
                
                [self updateInterPercent:1 - scale * scale];
                
                [self updateInteractiveTransition:scale];
            }
            break;
        case UIGestureRecognizerStateEnded:
            if (self.interation) {
                if (scale < 0.f) {
                    scale = 0.f;
                }
                self.interation = NO;
                if (scale < 0.15f){
                    [self cancelInteractiveTransition];
                    [self interPercentCancel];
                }else {
                    [self finishInteractiveTransition];
                    [self interPercentFinish];
                }
            }
            break;
        default:
            if (self.interation) {
                self.interation = NO;
                [self cancelInteractiveTransition];
                [self interPercentCancel];
            }
            break;
    }
}
- (void)beginInterPercent{
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    
    SJCImageBrowser *fromVC = (SJCImageBrowser *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    HXPhotoModel *model = [fromVC.modelArray objectAtIndex:fromVC.currentModelIndex];
    
    HXPhotoPreviewViewCell *fromCell = [fromVC currentPreviewCell:model];
    
    UICollectionView *collectionView = (UICollectionView *)self.photoView.collectionView;
    HXPhotoSubViewCell *toCell = (HXPhotoSubViewCell *)[collectionView cellForItemAtIndexPath:[self.photoView currentModelIndexPath:model]];
    
    self.fromCell = fromCell;
    self.scrollViewZoomScale = [self.fromCell getScrollViewZoomScale];
    self.scrollViewContentSize = [self.fromCell getScrollViewContentSize];
    self.scrollViewContentOffset = [self.fromCell getScrollViewContentOffset];
    
    UIView *containerView = [transitionContext containerView];
    CGRect tempImageViewFrame;
    self.contentView = fromCell.previewContentView;
    self.imageInitialFrame = fromCell.previewContentView.frame;
    tempImageViewFrame = [fromCell.previewContentView convertRect:fromCell.previewContentView.bounds toView:containerView];
    
    self.bgView = [[UIView alloc] initWithFrame:containerView.bounds];
    CGFloat scaleX;
    CGFloat scaleY;
    if (self.isPanGesture) {
        if (self.beginX < tempImageViewFrame.origin.x) {
            scaleX = 0;
        }else if (self.beginX > CGRectGetMaxX(tempImageViewFrame)) {
            scaleX = 1.0f;
        }else {
            scaleX = (self.beginX - tempImageViewFrame.origin.x) / tempImageViewFrame.size.width;
        }
        if (self.beginY < tempImageViewFrame.origin.y) {
            scaleY = 0;
        }else if (self.beginY > CGRectGetMaxY(tempImageViewFrame)){
            scaleY = 1.0f;
        }else {
            scaleY = (self.beginY - tempImageViewFrame.origin.y) / tempImageViewFrame.size.height;
        }
    }else {
        scaleX = 0.5f;
        scaleY = 0.5f;
    }
    self.contentView.layer.anchorPoint = CGPointMake(scaleX, scaleY);
    
    [fromCell resetScale:NO];
    [fromCell refreshImageSize];
    
    self.contentView.frame = tempImageViewFrame;
    self.transitionImgViewCenter = self.contentView.center;
    
    [containerView addSubview:self.bgView];
    [containerView addSubview:self.contentView];
    [containerView addSubview:fromVC.view];
    
    self.bgView.backgroundColor = [UIColor blackColor];
    fromVC.collectionView.hidden = YES;
    if (!toCell && fromVC.customPreviewToView) {
        toCell = (id)fromVC.customPreviewToView(fromVC.currentModelIndex);
    }
    toCell.hidden = fromVC.hideOrginView;
    fromVC.view.backgroundColor = [UIColor clearColor];
    self.tempCell = toCell;
    if (self.contentView.model.subType == HXPhotoModelMediaSubTypeVideo) {
        [self.contentView.videoView hideOtherView:YES];
    }
}
- (void)updateInterPercent:(CGFloat)scale{
    SJCImageBrowser *fromVC = (SJCImageBrowser *)[self.transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    fromVC.view.alpha = scale;
    self.bgView.alpha = fromVC.view.alpha;
}
- (void)interPercentCancel{
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    SJCImageBrowser *fromVC = (SJCImageBrowser *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC = [self.transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
#pragma clang diagnostic pop
        [toVC.navigationController setNavigationBarHidden:YES];
        toVC.navigationController.navigationBar.alpha = 1;
    if (self.contentView.model.subType == HXPhotoModelMediaSubTypeVideo) {
        [self.contentView.videoView showOtherView];
    }
    self.panGesture.enabled = NO;
    [UIView animateWithDuration:0.2f animations:^{
        fromVC.view.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
        self.contentView.center = self.transitionImgViewCenter;
        self.bgView.alpha = 1;
    } completion:^(BOOL finished) {
        if (finished) {
            fromVC.collectionView.hidden = NO;
            fromVC.view.backgroundColor = [UIColor blackColor];
            self.tempCell.hidden = NO;
            self.tempCell = nil;
            
            self.contentView.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
            [self.fromCell againAddImageView];
             
            [self.fromCell setScrollViewZoomScale:self.scrollViewZoomScale];
            self.contentView.frame = self.imageInitialFrame;
            [self.fromCell setScrollViewContnetSize:self.scrollViewContentSize];
            if (self.scrollViewContentOffset.y < 0) {
                self.scrollViewContentOffset = CGPointMake(self.scrollViewContentOffset.x, 0);
            }
            [self.fromCell setScrollViewContentOffset:self.scrollViewContentOffset];
            
            [self.bgView removeFromSuperview];
            self.bgView = nil;
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.panGesture.enabled = YES;
            });
        }
    }];
}
//完成
- (void)interPercentFinish {
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    UIView *containerView = [transitionContext containerView];
    SJCImageBrowser *fromVC = (SJCImageBrowser *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    UIViewController *toVC = [self.transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    NSTimeInterval duration = 0.35;
    UIViewAnimationOptions option = UIViewAnimationOptionLayoutSubviews;
    
    if (self.contentView.model.subType == HXPhotoModelMediaSubTypeVideo) {
        [self.contentView.videoView hideOtherView:NO];
    }
    CGRect tempImageViewFrame = self.contentView.frame;
    if (self.tempCell) {
        self.contentView.layer.anchorPoint = CGPointMake(0.5, 0.5);
    }
    self.contentView.transform = CGAffineTransformIdentity;
    self.contentView.frame = tempImageViewFrame;
    [self.contentView layoutIfNeeded];
    
    if (fromVC.transitionNeedPop) {
        [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.1 options:option animations:^{
            if (self.tempCell) {
                self.contentView.frame = [self.tempCell convertRect:self.tempCell.bounds toView: containerView];
            }else {
                self.contentView.alpha = 0;
                self.contentView.transform = CGAffineTransformMakeScale(0.3, 0.3);
            }
            fromVC.view.alpha = 0;
            self.bgView.alpha = 0;
            toVC.navigationController.navigationBar.alpha = 1;
        }completion:^(BOOL finished) {
            if (finished) {
                self.tempCell.hidden = NO;
                [self.contentView cancelRequest];
                [self.contentView removeFromSuperview];
                [self.bgView removeFromSuperview];
                self.contentView = nil;
                self.bgView = nil;
                [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            }
        }];
    }else{
        [UIView animateWithDuration:duration delay:0.0 options:option animations:^{
            if (self.tempCell) {
                self.contentView.frame = [self.tempCell convertRect:self.tempCell.bounds toView: containerView];
            }else {
                self.contentView.alpha = 0;
                self.contentView.transform = CGAffineTransformMakeScale(0.3, 0.3);
            }
            fromVC.view.alpha = 0;
            self.bgView.alpha = 0;
            toVC.navigationController.navigationBar.alpha = 1;
        } completion:^(BOOL finished) {
            if (finished) {
                self.tempCell.hidden = NO;
                [self.contentView cancelRequest];
                [self.contentView removeFromSuperview];
                [self.bgView removeFromSuperview];
                self.contentView = nil;
                self.bgView = nil;
                [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            }
        }];
    }
}
- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    self.transitionContext = transitionContext;
    [self beginInterPercent];
}
@end

