//
//  UIImage+Luminance.m
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-27.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import "UIImage+Luminance.h"

@implementation UIImage (Luminance)

- (double)lumine {
    
    NSData *bitmap = [self mutableRGBAData];
    const unsigned char *bytes = bitmap.bytes;
    
    if (bitmap.length > 0) {
    
        double sumLuminance = 0;
        
        for (NSUInteger index = 0; index < bitmap.length; index += 4) {
            
            //0.2126 R + 0.7152 G + 0.0722 B
            
            double pixelLuminance = 0.2126 * ((double)bytes[index+0]/(double)255) +
                                    0.7152 * ((double)bytes[index+1]/(double)255) +
                                    0.0722 * ((double)bytes[index+2]/(double)255);
            
            /*
            double pixelLuminance = ((double)bytes[index+0]/(double)255) +
                                    ((double)bytes[index+1]/(double)255) +
                                    ((double)bytes[index+2]/(double)255);
            */
            sumLuminance = sumLuminance + pixelLuminance;
        }
        
        return (sumLuminance / (double)(bitmap.length/4));
    }
    
    return 0;
}

- (NSMutableData *)mutableRGBAData {
    
    //this function is taken from the github account of iMartinKiss
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGSize scaledSize = (CGSize){
        .width = self.size.width * self.scale,
        .height = self.size.height * self.scale,
    };
    
    NSUInteger const bytesPerPixel = 4;
    NSUInteger const bitsPerComponent = 8;
    NSUInteger const bytesPerRow = bytesPerPixel * scaledSize.width;
    NSMutableData *bitmap = [[NSMutableData alloc] initWithLength:scaledSize.height * scaledSize.width * bytesPerPixel];
    
    CGContextRef context = CGBitmapContextCreate(bitmap.mutableBytes,
                                                 scaledSize.width, scaledSize.height,
                                                 bitsPerComponent, bytesPerRow,
                                                 colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGRect rect = (CGRect) {
        .origin = CGPointZero,
        .size = scaledSize,
    };
    CGContextDrawImage(context, rect, self.CGImage);
    
    CGColorSpaceRelease(colorSpace), colorSpace = NULL;
    CGContextRelease(context), context = NULL;
    
    return bitmap;
}

@end
