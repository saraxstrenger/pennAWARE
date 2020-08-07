//
//  LikertScaleESMView.h
//  AWARE
//
//  Created by Yuuki Nishiyama on 2017/08/03.
//  Copyright © 2017 Yuuki NISHIYAMA. All rights reserved.
//

#import "BaseESMView.h"

@interface ESMLikertScaleView : BaseESMView

- (instancetype)initWithFrame:(CGRect)frame esm:(EntityESM *)esm  displayEsm: (EntityESM *) display bigText: (BOOL)bigText viewController:(UIViewController *)viewController;

@end
