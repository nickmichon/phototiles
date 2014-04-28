//
//  PhotoTilesController.m
//  phototiles
//
//  Created by Mikolaj Michon on 2014-04-26.
//  Copyright (c) 2014 Mikolaj Michon. All rights reserved.
//

#import "PhotoTilesController.h"
#import "PhotoTileCell.h"
#import "Notifications.h"
#import "FlickrManager.h"
#import "ReachabilityOverlayView.h"
#import "Reachability.h"
#import "URLImageFileCache.h"
#import "UIImage+Luminance.h"

#define NUMPHOTOTILES    20

@interface PhotoTilesController ()

@end

@implementation PhotoTilesController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    self.cellImageUrls = [NSMutableArray new];
    self.emptyTileIndexes = [NSMutableArray new];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    //initially all tiles are empty and require injection of image urls
    
    for (int i=0; i<NUMPHOTOTILES; i++) {
        
        [self.cellImageUrls addObject:@""];
        [self.emptyTileIndexes addObject:[NSNumber numberWithInt:i]];
    }
    
    self.layout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:self.layout];
    [self.collectionView setDataSource:self];
    [self.collectionView setDelegate:self];
    [self.collectionView registerClass:[PhotoTileCell class] forCellWithReuseIdentifier:@"PhotoTileCell"];
    [self.collectionView setBackgroundColor:[UIColor darkGrayColor]];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.collectionView];
    
    //Sort button, tries to sort by luminance but it may be an expensive operation
    //There is also the issue of the images being lazy loaded, so it will really only sort
    //images that have already been seen.
    
    UIButton *sortButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [sortButton addTarget:self action:@selector(sortPressed) forControlEvents:UIControlEventTouchDown];
    sortButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:14];
    sortButton.backgroundColor = [UIColor whiteColor];
    sortButton.frame = CGRectMake( 5, 20+5, 120, 20 );
    [sortButton setTitle:@"Luminance Sort" forState:UIControlStateNormal];
    [sortButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:sortButton];
    
    //Add the reachability overlay last so that it draws over everything
    
    ReachabilityOverlayView *reachOverlay = [[ReachabilityOverlayView alloc] initWithFrame:CGRectMake
                                             (0, 20, self.view.frame.size.width, [ReachabilityOverlayView viewHeight])];
    [self.view addSubview:reachOverlay];
    
    //When new image urls are available, we want to inject all empty tiles
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flickrUrlUpdatedNotification:) name:FlickrUrlUpdatedNotification object:nil];

    //In case the network goes down and we click on a tile when there are no urls available, we will need to
    //get urls for empty tiles to let them download their corresponding images
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)sortPressed {
    
    //Calculate luminance for all images
    
    NSMutableArray *luminances = [NSMutableArray new];
    
    for (int i=0; i<[self.cellImageUrls count]; i++) {
        
        NSString *imageUrl = [self.cellImageUrls objectAtIndex:i];
        
        if (imageUrl && [imageUrl length] > 0) {
            
            // retrieve the image, if it doesn't get it now, then too bad, the luminance is 0
            
            UIImage *image = [[URLImageFileCache sharedInstance] findAndCacheGeneric:imageUrl error:nil];
            
            if (image) {
                
                [luminances addObject:[NSNumber numberWithDouble:[image lumine]]];
            }
            else {
                
                [luminances addObject:[NSNumber numberWithDouble:0]];
            }
        }
    }
    
    //Sort them (bubble ok)
    
    for (int i=0; i<[self.cellImageUrls count]; i++) {
        
        for (int j=0; j<[self.cellImageUrls count]; j++) {
            
            if (i != j) {
            
                NSNumber *lumineI = [luminances objectAtIndex:i];
                NSNumber *lumineJ = [luminances objectAtIndex:j];

                if ([lumineJ doubleValue] < [lumineI doubleValue]) {
                    
                    //Swap them
                    
                    NSString *urlI = [self.cellImageUrls objectAtIndex:i];
                    NSString *urlJ = [self.cellImageUrls objectAtIndex:j];
                    
                    [self.cellImageUrls replaceObjectAtIndex:i withObject:urlJ];
                    [self.cellImageUrls replaceObjectAtIndex:j withObject:urlI];
                    
                    [luminances replaceObjectAtIndex:i withObject:lumineJ];
                    [luminances replaceObjectAtIndex:j withObject:lumineI];
                }
            }
        }
    }
    
    //Refresh the entire view
    
    [self.collectionView reloadData];
}

-(void)flickrUrlUpdatedNotification:(NSNotification*) notification {
 
    [self fillAllEmptyTilesWithUrls];
}

- (void)reachabilityChanged:(NSNotification*) notification {
    
    Reachability *reach = (Reachability *)notification.object;
    
    if ([reach isReachable]) {
        
        //In case we have tiles which don't have urls lets try filling up
        //any remaining ones
        
        [self fillAllEmptyTilesWithUrls];
    }
}

-(void)getNewUrlForTile:(int)tileIndex {
    
    @synchronized(self) {
        
        //make sure the tile isn't already empty
        
        NSString *existingUrl = [self.cellImageUrls objectAtIndex:tileIndex];
        
        if (existingUrl && [existingUrl length] > 0) {
            
            //Try to get a url for this tile
            
            NSString *imageUrl = [[FlickrManager sharedInstance] getImageUrl];
            
            if (imageUrl) {
            
                [self.cellImageUrls replaceObjectAtIndex:tileIndex withObject:imageUrl];
            }
            else {
                
                //We couldn't even get a url at this time, so mark it as empty
                //for updating later
                
                [self.cellImageUrls replaceObjectAtIndex:tileIndex withObject:@""];

                [self.emptyTileIndexes addObject:[NSNumber numberWithInt:tileIndex]];
            }
            
            //Whether or not we got a url or are still waiting on one, we update the view
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:tileIndex inSection:0];
            
            //Only refresh the selected tile
            
            NSMutableArray *indexPaths = [NSMutableArray new];
            [indexPaths addObject:indexPath];
            [self.collectionView reloadItemsAtIndexPaths:indexPaths];
        }
    }
}

-(void)fillAllEmptyTilesWithUrls {
    
    //the user can select (and empty) a tile while we are still updating them, so make sure
    //the operations don't overlap
    
    @synchronized(self) {
    
        //fill as many empty tiles as we can, then update the screen
        
        NSMutableArray *discardedItems = [NSMutableArray new];
        NSMutableArray *indexPaths = [NSMutableArray new];
        
        for (int i=0; i<[self.emptyTileIndexes count]; i++) {
            
            NSNumber *emptyTileIndex = [self.emptyTileIndexes objectAtIndex:i];
            
            //try to get a url for this empty tile
            
            NSString *imageUrl = [[FlickrManager sharedInstance] getImageUrl];
            
            if (imageUrl) {
                
                //give this tile a url and update it
                
                [self.cellImageUrls replaceObjectAtIndex:[emptyTileIndex intValue] withObject:imageUrl];
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[emptyTileIndex intValue] inSection:0];
                [indexPaths addObject:indexPath];
                
                //remember to discard this empty index
                
                [discardedItems addObject:emptyTileIndex];
            }
            else {
                
                //There aren't any more image urls, we'll have to wait for more
                //which will happen when the next flickrurlupdatednotification happens,
                //for now we break out
                
                break;
            }
        }
        
        [self.emptyTileIndexes removeObjectsInArray:discardedItems];
        
        //Update the cells that just got urls
        
        [self.collectionView reloadItemsAtIndexPaths:indexPaths];
    }
}

#pragma mark - UICollectionView Datasource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return [self.cellImageUrls count];
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView {
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    PhotoTileCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"PhotoTileCell" forIndexPath:indexPath];
    [cell reloadImageUrl:[self.cellImageUrls objectAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: Select Item
    NSLog(@"selected cell %i",indexPath.row);
    
    [self getNewUrlForTile:indexPath.row];
}
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    // TODO: Deselect item
}

#pragma mark – UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    CGSize size = CGSizeMake(100+35, 100+35);
    return size;
}

- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(50, 20, 50, 20);
}
@end
