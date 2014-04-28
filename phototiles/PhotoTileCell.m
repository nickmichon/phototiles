//
//  PhotoTileCell.m
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import "PhotoTileCell.h"
#import "URLImageFileCache.h"
#import "Notifications.h"
#import "Reachability.h"

@implementation PhotoTileCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        // Initialization code
        
        self.imageUrl = nil;
        
        self.backgroundColor = [UIColor clearColor];
                
        self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height )];
        self.imageView.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.imageView];
    }
    return self;
}

-(void)reloadImageUrl:(NSString *)imageUrl {
    
    //clear old notifications first
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.imageUrl = imageUrl;
    self.imageView.image = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageCacheUpdated:) name:ImageCacheUpdated object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [self loadImage];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)loadImage {
    
    //only loads the image if there isn't one currently
    
    if (nil == self.imageView.image && self.imageUrl && [self.imageUrl length] > 0) {
        
        // retrieve the image, if it doesn't get it now, it will send out a notification
        // which will end up back here again
        
        UIImage *image = [[URLImageFileCache sharedInstance] findAndCacheGeneric:self.imageUrl error:nil];
        
        if (image) {
            self.imageView.image = image;
            [[NSNotificationCenter defaultCenter] removeObserver:self];
        }
    }
}

- (void)imageCacheUpdated:(NSNotification*) notification {
    
    [self loadImage];
}

- (void)reachabilityChanged:(NSNotification*) notification {
    
    Reachability *reach = (Reachability *)notification.object;
    
    if ([reach isReachable]) {
        
        //In case the network went down right when a download was in progress which failed, and we just
        //got a connection again now, try again to load the image if we don't have it yet
        
        [self loadImage];
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
