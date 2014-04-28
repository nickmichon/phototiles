//
//  FlickrManager.m
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import "FlickrManager.h"
#import "Globals.h"
#import "FlickrPhoto.h"
#import "FlickrPhotos.h"
#import "Notifications.h"
#import "Reachability.h"

@implementation FlickrManager

static FlickrManager *sharedFlickrManager = nil;

+(FlickrManager *)sharedInstance {
    if (!sharedFlickrManager) {
        sharedFlickrManager = [[FlickrManager alloc] init];
    }
    return sharedFlickrManager;
}

-(id)init {
    if ((self = [super init])) {
        
        self.imageUrls = [NSMutableArray new];
        
#ifdef NODEBUG_RESTKIT
        //No debug
        RKLogConfigureByName("RestKit/Network", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/Network/Reachability", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/Network/Cache", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/Network/Queue", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/CoreData", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/ObjectMapper", RKLogLevelCritical);
        RKLogConfigureByName("RestKit", RKLogLevelCritical);
#else
        //Full debug
        RKLogConfigureByName("RestKit/Network", RKLogLevelTrace);
#endif
        
        [RKMIMETypeSerialization registerClass:[RKNSJSONSerialization class] forMIMEType:@"text/plain"];
        
        NSString *flickrUrl = [NSString stringWithFormat:@"%@%@", HTTP_SECURE, FLICKR_API_URL];
        NSURL *url = [NSURL URLWithString:flickrUrl];
        
        self.sessionRKManager = [RKObjectManager managerWithBaseURL:url];
        self.sessionRKManager.requestSerializationMIMEType = RKMIMETypeJSON;

        //Set up mappings
        
        //A single Photo
        
        NSDictionary *photoMappingDict = @{
                                           @"id":               @"flickrid",
                                           @"owner":            @"owner",
                                           @"secret":           @"secret",
                                           @"server":           @"flickrserver",
                                           @"title":            @"title",
                                           @"farm":             @"farm",
                                           @"ispublic":         @"ispublic",
                                           @"isfriend":         @"isfriend",
                                           @"isfamily":         @"isfamily",
                                           };
        RKObjectMapping* photoMapping = [RKObjectMapping mappingForClass:[FlickrPhoto class]];
        [photoMapping addAttributeMappingsFromDictionary:photoMappingDict];
        RKResponseDescriptor *flickrPhotoResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:photoMapping
                                                                                                           method:RKRequestMethodAny
                                                                                                      pathPattern:nil
                                                                                                          keyPath:@"photo"
                                                                                                      statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        [self.sessionRKManager addResponseDescriptor:flickrPhotoResponseDescriptor];
        
        //Set of Photos
        
        NSDictionary *photosMappingDict = @{
                                           @"page":     @"page",
                                           @"pages":    @"pages",
                                           @"perpage":  @"perpage",
                                           @"total":    @"total",
                                           };
        
        RKObjectMapping* szPhotosMapping = [RKObjectMapping mappingForClass:[FlickrPhotos class]];
        [szPhotosMapping addAttributeMappingsFromDictionary:photosMappingDict];
        [szPhotosMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"photo"
                                                                                        toKeyPath:@"photo"
                                                                                     withMapping:photoMapping]];
        RKResponseDescriptor *flickrPhotosResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:szPhotosMapping
                                                                                                            method:RKRequestMethodAny
                                                                                                       pathPattern:nil
                                                                                                           keyPath:@"photos"
                                                                                                       statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        [self.sessionRKManager addResponseDescriptor:flickrPhotosResponseDescriptor];
        
        //init
        
        self.pageIndex = 1;  //Flickr starts paging at 1!!  But returns results for 0 as 1, so you'll get looping images
        
        //Try to get photos right away
        
        [self getPhotos];
        
        //Register for when the network is reachable, in case started up with no connection in the first place
        //or interrupted during the course of using the app

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)reachabilityChanged:(NSNotification*) notification {
    
    Reachability *reach = (Reachability *)notification.object;
    
    if ([reach isReachable]) {

        //If we haven't gotten the first batch of photos yet lets get them now
        
        if (!self.initialized && !self.pageGetInProgress) {
            
            [self getPhotos];
        }
    }
}


-(BOOL)isTimeToGetMoreUrlsFromFlickr {
    
    if (self.imageUrlIndex-self.recentNewUrlIndex >= FLICKR_PAGESIZE/2) {
        
        //if we've burned through half of our page size already, then get some more urls if possible
        
        return TRUE;
    }
    return FALSE;
}

-(NSString *)getImageUrl {
    
    if (self.maxImagesReached) {
    
        NSString *url = [self.imageUrls objectAtIndex:self.imageUrlIndex];
        
        NSLog(@"Returing url index %i: %@",self.imageUrlIndex, url);
        
        self.imageUrlIndex++;
        
        if (self.imageUrlIndex >= [self.imageUrls count]) {
            
            //loop the images if we absolutely can't get any more from the api
            
            self.imageUrlIndex = 0;
        }
        
        return url;
    }
    else {
        
        if (self.imageUrlIndex >= [self.imageUrls count]) {
            
            //get more now, should have already happened
                
            [self getPhotos];
            
            //we're totally out of images but we can get more, but for now, we have to return nil
            //and request more
            
            return nil;
        }
        else {
            
            NSString *url = [self.imageUrls objectAtIndex:self.imageUrlIndex];

            NSLog(@"Returing url index %i: %@",self.imageUrlIndex, url);
            
            self.imageUrlIndex++;
            
            if ([self isTimeToGetMoreUrlsFromFlickr]) {
                
                [self getPhotos];
            }
            
            return url;
        }
    }
}

-(void)handleFlickrPhotos:(FlickrPhotos *)flickrPhotos {
    
    self.recentNewUrlIndex = [self.imageUrls count];
    
    NSLog(@"Got photos: %i photos", [flickrPhotos.photo count]);
    
    for (FlickrPhoto *photo in flickrPhotos.photo) {
        
        [self.imageUrls addObject:[self photoUrlFromFlickrPhoto:photo]];
    }
    
    if ([self.imageUrls count] >= [flickrPhotos.total intValue]) {
        
        //We can not get any more, so we have to loop the image get
        
        self.maxImagesReached = TRUE;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FlickrUrlUpdatedNotification object:nil userInfo:nil];
}

-(NSString *)photoUrlFromFlickrPhoto:(FlickrPhoto *)photo {
    
    //http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}_[mstzb].jpg
    
    NSString *url = [NSString stringWithFormat:@"http://farm%i.staticflickr.com/%@/%@_%@_q.jpg",
                     [photo.farm intValue],
                     photo.flickrserver,
                     photo.flickrid,
                     photo.secret];
    
    return url;
}

-(void)getPhotos {
    
    if (!self.pageGetInProgress) {
    
        [self getInterestingPhotos:self.pageIndex perpage:FLICKR_PAGESIZE];
    }
}

-(void)getInterestingPhotos:(int)page perpage:(int)perpage {
    
    self.pageGetInProgress = TRUE;
    
    [RKObjectManager setSharedManager:self.sessionRKManager];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"flickr.interestingness.getList",  @"method",
                            [NSNumber numberWithInt:perpage],   @"per_page",
                            [NSNumber numberWithInt:page],      @"page",
                            @"json",                            @"format",
                            FLICKR_KEY,                         @"api_key",
                            @"1",                               @"nojsoncallback",
                            nil];
    
    NSString *path = [NSString stringWithFormat:@"/services/rest/"];
    
    [[RKObjectManager sharedManager] getObjectsAtPath:path
                                           parameters:params
                                              success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                                  
                                                  dispatch_async( dispatch_get_main_queue(), ^{
                                                      
                                                      NSLog(@"Got Flickr photos");
                                                      
                                                      NSObject *obj = [mappingResult.array objectAtIndex:0];
                                                      
                                                      if ([obj isKindOfClass:[FlickrPhotos class]]) {
                                                          
                                                          FlickrPhotos *photos = (FlickrPhotos *)obj;
                                                      
                                                          [self handleFlickrPhotos:photos];
                                                      }

                                                      self.initialized = TRUE;
                                                      self.pageIndex++;
                                                      self.pageGetInProgress = FALSE;
                                                  });
                                                  
                                              } failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                  
                                                  dispatch_async( dispatch_get_main_queue(), ^{
                                                      
                                                      self.pageGetInProgress = FALSE;

                                                      NSLog(@"Failed to get Flickr Photos");
                                                  });
                                              }];
}


@end
