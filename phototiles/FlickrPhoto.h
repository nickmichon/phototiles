//
//  FlickrPhoto.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlickrPhoto : NSObject

@property (nonatomic, copy) NSString *flickrid;
@property (nonatomic, copy) NSString *owner;
@property (nonatomic, copy) NSString *secret;
@property (nonatomic, copy) NSString *flickrserver;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, strong) NSNumber *farm;
@property (nonatomic, strong) NSNumber *ispublic;
@property (nonatomic, strong) NSNumber *isfriend;
@property (nonatomic, strong) NSNumber *isfamily;

@end

/*
 "photo": [
 { "id": "14001805553", "owner": "22292497@N05", "secret": "74fe8ec186", "server": "7238", "farm": 8, "title": "moments after sunrise", "ispublic": 1, "isfriend": 0, "isfamily": 0 },
 
*/