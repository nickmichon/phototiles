//
//  PhotoTileCell.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PhotoTileCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSString *imageUrl;

-(void)reloadImageUrl:(NSString *)imageUrl;

@end
