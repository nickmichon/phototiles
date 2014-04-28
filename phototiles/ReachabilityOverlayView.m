//
//  ReachabilityOverlayView.m
//  Syzapp
//
//  Created by Mikolaj Michon on 2013-07-09.
//  Copyright (c) 2013 Mikolaj Michon. All rights reserved.
//

#import "ReachabilityOverlayView.h"
#import "Reachability.h"
#import "Globals.h"

#define REACHABILITY_OVERLAY_HEIGHT 30

@implementation ReachabilityOverlayView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        self.backgroundColor = [UIColor colorWithRed:0.5f green:0.0f blue:0.0f alpha:1.0f];
        
        UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        messageLabel.text = @"No Internet Connection";
        messageLabel.backgroundColor = [UIColor clearColor];
        messageLabel.textColor = [UIColor whiteColor];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        
        [self addSubview:messageLabel];
        
        self.hidden = TRUE;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
    }
    return self;
}

+(float)viewHeight {
    return REACHABILITY_OVERLAY_HEIGHT;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reachabilityChanged:(NSNotification*) notification {
    
    Reachability *reach = (Reachability *)notification.object;
    
    if ([reach isReachable]) {
        self.hidden = TRUE;
    }
    else {
        self.hidden = FALSE;
    }
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
