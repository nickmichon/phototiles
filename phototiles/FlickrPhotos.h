//
//  FlickrPhotos.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlickrPhotos : NSObject

@property (nonatomic, strong) NSNumber *page;
@property (nonatomic, strong) NSNumber *pages;
@property (nonatomic, strong) NSNumber *perpage;
@property (nonatomic, strong) NSNumber *total;

@property (nonatomic, strong) NSArray *photo;   //contains FlickrPhoto's

@end

/*
 { "photos": { "page": 1, "pages": 25, "perpage": 20, "total": "500",
 "photo": [
 
*/