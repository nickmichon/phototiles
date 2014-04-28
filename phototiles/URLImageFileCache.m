//
//  URLImageFileCache.m
//  Syzapp
//
//  Created by Mikolaj Michon on 2013-06-13.
//  Copyright (c) 2013 Mikolaj Michon. All rights reserved.
//

#import "URLImageFileCache.h"
#import "NSString+MD5.h"
#import "Notifications.h"
#import "Globals.h"

#define PATH_GENERIC @"/generic"

@implementation URLImageFileCache

static URLImageFileCache *sharedURLImageFileCache = nil;

+ (URLImageFileCache *) sharedInstance {
    if (!sharedURLImageFileCache) {
        sharedURLImageFileCache = [[URLImageFileCache alloc] init];
    }
    
    //Check if the blacklist should be cleared
    
    NSDate *currentTimestamp = [NSDate date];
    if ([currentTimestamp timeIntervalSinceDate:sharedURLImageFileCache.rejectedURLsTimeStamp] > IMAGE_BLACKLIST_LIFESPAN) {
        
        //clear the blacklist and reset the timer
        
        sharedURLImageFileCache.rejectedURLsTimeStamp = currentTimestamp;
        
        @synchronized (sharedURLImageFileCache) {

            sharedURLImageFileCache.rejectedURLs = [NSMutableDictionary new];
        }
    }
    
    return sharedURLImageFileCache;
}

- (id)init {
    if ((self = [super init])) {
        
        self.downloadsInProgress = [NSMutableDictionary new];
        self.rejectedURLs = [NSMutableDictionary new];
        self.rejectedURLsTimeStamp = [NSDate date];
    }
    return self;
}

-(UIImage *)findAndCache:(NSString *)url withPath:(NSString *)path isUserData:(BOOL)isUserData error:(NSError **)error
{
    //Looks for the image in the file cache, if it doesn't find it, it returns
    //nil and begins attempting to download the image.
    //If the image exists in files, then it is turned into a UIImage
    //and returned.
    //If the image is downloaded successfully, it is stored as a file and an
    //NSNotification is broadcast for the original caller to call this same function again.
    //The class is smart enough not to download multiple instances of the same
    //image url at the same time, so it may be called freely.
    
    if (nil==url || url.length < 1) {
        
        return nil;
    }
    
    //Check if this is a rejected URL
    
    if ([self.rejectedURLs objectForKey:url]) {
        
        return nil;
    }
    
    NSLog(@"findAndCache: %@",url);
    
    //Hash the url so that it becomes our filename key (miniscule chance of collision?)
    
    NSString *fileName = [url MD5];
    
    //Set up the path where we store the file
    
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *dirPath = [NSString stringWithFormat:@"%@/cache%@", basePath, path];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", dirPath, fileName];
    
    //Look for the file
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
        
    BOOL found = [fileManager fileExistsAtPath:filePath];
    
    if (found) {

        NSLog(@" found image.");
        
        //fixme: Really need to cache these images too
        
        NSData *imageData = [[NSData alloc] initWithContentsOfFile:filePath];
        
        UIImage *image = [UIImage imageWithData:imageData];
        
        return image;
    }
    else {
    
        NSLog(@"Would store file at %@",filePath);
        
        @synchronized (self) {

            //NSError *localError = nil;
            
            //Ensure that there isn't already a download in progress for this file
            
            if ([self.downloadsInProgress objectForKey:url]) {
                
                //Currently being downloaded by another thread
                
                return nil;
            }
            
            //Store the filepath to indicate we're downloading it, also so that the download
            //thread knows where to write the file when its finished
            
            [self.downloadsInProgress setObject:filePath forKey:url];
            
            //Initiate the download
            
            [self downloadImage:url dirPath:dirPath filePath:filePath isUserData:isUserData];
        }
    }
    
    // not found, not cached
    return nil;
}

-(void) downloadImage:(NSString *)url dirPath:(NSString *)dirPath filePath:(NSString *)filePath isUserData:(BOOL)isUserData {
    
    //Initiate the download
    //Make sure the device isn't trying to act smart and caching, then reporting errors even after a file is fixed remotely

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0f];
    
    //+ (id)requestWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval;

    //Change the user agent just in case mobile devices are unwelcome
    
    NSString* userAgent = SNEAKY_USER_AGENT; 
    [request addValue:userAgent forHTTPHeaderField:@"User-Agent"];
    
    
    NSLog(@"downloadImage: url=%@",url);
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]   // this dictates where the completion
                                                                            // handler is called; it doesn't make
                                                                            // the fetch block the main queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
    {
        if (nil != data) {
            
            NSLog(@"Image data for %@: size=%i",url, data.length);
            
            if (data.length >= MAXIMUM_IMAGE_DATA_SIZE_BYTES) {
                
                NSLog(@"Huge image file! %@",url);
            }
            
            //Discard anything less than 200 bytes or larger than 200k bytes
            
            if (data.length >= MINIMUM_IMAGE_DATA_SIZE_BYTES &&
                data.length <= MAXIMUM_IMAGE_DATA_SIZE_BYTES) {
            
                //Test to see if the data is an image
            
                UIImage *testImage = [UIImage imageWithData:data];
                
                if (nil != testImage) {
                    
                    //NSLog(@"Image size=%f,%f",testImage.size.width, testImage.size.height);
                    
                    //Set up the directory
                    
                    BOOL createdDir=FALSE;
                    NSError *directoryError;
                    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath])
                    {
                        //Directory doesn't exist yet
                        //NSLog(@"Directory at %@ doesn't exist yet",dirPath);
                        
                        if (![[NSFileManager defaultManager] createDirectoryAtPath:dirPath
                                                       withIntermediateDirectories:YES
                                                                        attributes:nil
                                                                             error:&directoryError])
                        {
                            NSLog(@"Create directory error: %@", directoryError);
                        }
                        else {
                            
                            createdDir = TRUE;
                        }
                    }
                    else {
                        createdDir = TRUE; //already created
                    }
                    
                    //Write the data to a file
                    
                    if (createdDir && [data writeToFile:filePath atomically:true]) {
                    
                        //NSLog(@"Successfully downloaded and stored image");
                        
                        //Set backup settings depending if the data is user originated
                        
                        if (!isUserData) {
                            
                            //only user originated photos get backed up
                            
                            [self addSkipBackupAttributeToItemAtPath:filePath isDirectory:FALSE];
                        }
                        
                        //Broadcast to the app that an image was downloaded and is available now
                    
                        [[NSNotificationCenter defaultCenter] postNotificationName:ImageCacheUpdated object:nil userInfo:nil];
                    }
                    else {
                        //NSLog(@"Failed to store image");
                    }
                }
                else {
                    //NSLog(@"Failed to verify image for url: %@",url);
                }
            }
            else {
                
                NSLog(@"Image data size (%i) not within range [500, 350000], discarding data and blacklisting url [%@].",data.length, url);
                
                //Add to the rejected list of URL images (only kept during this app instance)
                //So that another connection to this image is not made
                
                [self.rejectedURLs setObject:[NSNumber numberWithInt:1] forKey:url];
            }
        }
        else {
            //NSLog(@"Failed to download image");
        }
        
        @synchronized (self) {
            
            //Remove the download information from our dictionary
            
            [self.downloadsInProgress removeObjectForKey:url];
        }
    }];
}


-(UIImage *)findAndCacheGeneric:(NSString *)url error:(NSError **)error {
    
    return [self findAndCache:url withPath:PATH_GENERIC isUserData:FALSE error:error];
}

-(void)clearCache {
    
    int deletedCount;
        
    deletedCount = [self deleteAllCachedFilesAtPath:PATH_GENERIC];
    NSLog(@"Deleted %i items from GENERIC cache.",deletedCount);
}

-(int)deleteAllCachedFilesAtPath:(NSString *)path {
    
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *dirPath = [NSString stringWithFormat:@"%@/cache%@", basePath, path];

    return [self deleteAllItemsAtPath:dirPath];
}

-(void)deleteItemAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
}

-(int)deleteAllItemsAtPath:(NSString *)path {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator* en = [fileManager enumeratorAtPath:path];
    NSError* err = nil;
    BOOL res;
    
    int deletedCount=0;
    
    NSString* file;
    while (file = [en nextObject]) {
        res = [fileManager removeItemAtPath:[path stringByAppendingPathComponent:file] error:&err];
        if (!res && err) {
            NSLog(@"error deleting file: %@", err);
        }
        else {
            
            deletedCount++;
        }
    }
    return deletedCount;
}

-(NSString *)photoDirPath {
    
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path = @"/photos";
    NSString *dirPath = [NSString stringWithFormat:@"%@/images%@", basePath, path];
    
    return dirPath;
}

-(NSString *)photoFilePath:(NSString *)fileName {
    
    NSString *dirPath = [self photoDirPath];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", dirPath, fileName];
 
    return filePath;
}

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)path isDirectory:(BOOL)isDir
{
    NSURL *URL = [NSURL fileURLWithPath:path isDirectory:isDir];
    
    //assert([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup: %@", URL, error);
    }
    else {
        //NSLog(@"Successfully excluded %@ from backup", URL);
    }
    return success;
}

//NSURLConnectionDownloadDelegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *) destinationURL {
    
}

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes {
    
    
}


@end
