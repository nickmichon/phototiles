//
//  PhotoTilesController.h
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PhotoTilesController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewFlowLayout *layout;

@property (nonatomic, strong) NSMutableArray *cellImageUrls;        //tracks which tiles get which image urls
@property (nonatomic, strong) NSMutableArray *emptyTileIndexes;     //which tiles haven't gotten image urls yet

@end
