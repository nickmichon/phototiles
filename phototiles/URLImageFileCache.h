//
//  URLImageFileCache.h
//  Syzapp
//
//  Created by Mikolaj Michon on 2013-06-13.
//  Copyright (c) 2013 Mikolaj Michon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface URLImageFileCache : NSObject <NSURLConnectionDelegate>

@property (strong, nonatomic) NSMutableDictionary *downloadsInProgress;     //to avoid duplicate downloads

@property (strong, nonatomic) NSMutableDictionary *rejectedURLs;            //reject downloading invalid images again

@property (strong, nonatomic) NSDate *rejectedURLsTimeStamp;                //but clear the rejection list later in case fixed on server

+ (URLImageFileCache *)sharedInstance;

-(UIImage *)findAndCacheGeneric:(NSString *)url error:(NSError **)error;

-(void)clearCache;

@end
