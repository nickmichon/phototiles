//
//  FlickrManager.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RestKit/RestKit.h>
#import "Globals.h"


@interface FlickrManager : NSObject

@property (strong, nonatomic) RKObjectManager *sessionRKManager;

@property (strong, nonatomic) NSMutableArray *imageUrls;
@property (assign) int recentNewUrlIndex;
@property (assign) int imageUrlIndex;
@property (assign) int pageIndex;
@property (assign) BOOL maxImagesReached;
@property (assign) BOOL pageGetInProgress;

@property (assign) BOOL initialized;                //has it gotten a first set of urls yet?

+(FlickrManager *)sharedInstance;

-(NSString *)getImageUrl;

@end
