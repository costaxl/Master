//
//  MWGridViewController.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import "MWGridViewController.h"
#import "MWGridCell.h"
#import "MWPhotoBrowserPrivate.h"
#import "MWCommon.h"

@interface MWGridViewController ()
{
    
    // Store margins for current setup
    CGFloat _margin, _gutter, _marginL, _gutterL, _columns, _columnsL;
    UIBarButtonItem  *_doneButton;
    BOOL _isModel;
    bool _bScrolling;

}
@end

@implementation MWGridViewController
@synthesize isModal=_isModel;

- (id)init {
    UICollectionViewFlowLayout* Layout = [[UICollectionViewFlowLayout alloc] init];

    if ((self = [super initWithCollectionViewLayout:Layout])) {
        
        // Defaults
        _columns = 3, _columnsL = 4;
        _margin = 0, _gutter = 1;
        _marginL = 0, _gutterL = 1;
        
        // For pixel perfection...
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // iPad
            _columns = 6, _columnsL = 8;
            _margin = 1, _gutter = 2;
            _marginL = 1, _gutterL = 2;
        } else if ([UIScreen mainScreen].bounds.size.height == 480) {
            // iPhone 3.5 inch
            _columns = 3, _columnsL = 4;
            _margin = 0, _gutter = 1;
            _marginL = 1, _gutterL = 2;
        } else {
            // iPhone 4 inch
            _columns = 3, _columnsL = 5;
            _margin = 0, _gutter = 1;
            _marginL = 0, _gutterL = 2;
        }

        _initialContentOffset = CGPointMake(0, CGFLOAT_MAX);
        self.m_bBatchLoadThumbnails = false;
        self.isModal = false;
        _bScrolling = false;
    }
    return self;
}

#pragma mark - View



- (void)viewDidLoad {
    [super viewDidLoad];
    [self.collectionView registerClass:[MWGridCell class] forCellWithReuseIdentifier:@"GridCell"];
    
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    _doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", nil) style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonPressed:)];
    //_doneButton = [[UIBarButtonItem alloc]  initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(doneButtonPressed:)];
    // Set appearance
    if ([UIBarButtonItem respondsToSelector:@selector(appearance)]) {
        [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
        [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
        [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
        [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
    }

    
}

- (void)viewWillDisappear:(BOOL)animated {
    // Cancel outstanding loading
    NSArray *visibleCells = [self.collectionView visibleCells];
    if (visibleCells) {
        for (MWGridCell *cell in visibleCells) {
            [cell.photo cancelAnyLoading];
        }
    }
    [super viewWillDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self performLayout];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Move to previous content offset
    if (_initialContentOffset.y != CGFLOAT_MAX)
    {
        self.collectionView.contentOffset = _initialContentOffset;
    }
    CGPoint currentContentOffset = self.collectionView.contentOffset;
    
    // Get scroll position to have the current photo on screen
    if (_browser.numberOfPhotos > 0)
    {
        NSIndexPath *currentPhotoIndexPath = [NSIndexPath indexPathForItem:_browser.currentIndex inSection:0];
        //[self.collectionView scrollToItemAtIndexPath:currentPhotoIndexPath atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
    }
    CGPoint offsetToShowCurrent = self.collectionView.contentOffset;
    
    // Only commit to using the scrolled position if it differs from the initial content offset
    if (!CGPointEqualToPoint(offsetToShowCurrent, currentContentOffset)) {
        // Use offset to show current
        self.collectionView.contentOffset = offsetToShowCurrent;
    } else {
        // Stick with initial
        self.collectionView.contentOffset = currentContentOffset;
    }
    
}

- (void)performLayout {
    UINavigationBar *navBar = self.navigationController.navigationBar;
    
    self.browser.navigationItem.leftBarButtonItem = _doneButton;

    CGFloat yAdjust = 0;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    if (SYSTEM_VERSION_LESS_THAN(@"7") && !self.browser.wantsFullScreenLayout) yAdjust = -20;
#endif
    self.collectionView.contentInset = UIEdgeInsetsMake(navBar.frame.origin.y + navBar.frame.size.height + [self getGutter] + yAdjust, 0, 0, 0);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self.collectionView reloadData];
    [self performLayout]; // needed for iOS 5 & 6
}

#pragma mark - Layout

- (CGFloat)getColumns {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _columns;
    } else {
        return _columnsL;
    }
}

- (CGFloat)getMargin {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _margin;
    } else {
        return _marginL;
    }
}

- (CGFloat)getGutter {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _gutter;
    } else {
        return _gutterL;
    }
}

#pragma mark - scroll View

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    NSLog(@"scrollViewWillBeginDragging");
    _bScrolling = true;
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
         _bScrolling = false;
        [self BatchLoadThumbnail:self.collectionView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSLog(@"scrollViewDidEndDecelerating");

    _bScrolling = false;
    [self BatchLoadThumbnail:self.collectionView];
}

#pragma mark - Collection View


- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return [_browser numberOfPhotos];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MWGridCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"GridCell" forIndexPath:indexPath];
    if (!cell) {
        cell = [[MWGridCell alloc] init];
    }
    id <MWPhoto> photo = [_browser thumbPhotoAtIndex:indexPath.row];
    cell.photo = photo;
    cell.gridController = self;
    cell.selectionMode = _selectionMode;
    cell.isSelected = [_browser photoIsSelectedAtIndex:indexPath.row];
    cell.index = indexPath.row;
    UIImage *img = [_browser imageForPhoto:photo];
    if (img) {
        [cell displayImage];
    } else
    {
        if (!self.m_bBatchLoadThumbnails)
            [photo loadUnderlyingImageAndNotify];
        else
        {
            if (!_bScrolling)
                [self BatchLoadThumbnail:cv];

        }
    }
    return cell;
}

-(void)BatchLoadThumbnail:(UICollectionView *)collectionView
{
    // check whether or not any Batch load executed
    if(![_browser canBatchLoadThumbnail])
        return;
    
    // need to exec in next run --- need to let collection view ready in this run
    [_browser prepareBatchLoad];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self BatchLoadThumbnailTask];
    });

 }
-(void)BatchLoadThumbnailTask
{
     // generate photo list via indexPathsForVisibleItems
    NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
	
    // if we know scroll direction, we can do the following
	//id objOrEnumerator = (lastTableViewScrollDirection == AssetBrowserScrollDirectionDown) ? (id)visibleIndexPaths : (id)[visibleIndexPaths reverseObjectEnumerator];
	id objOrEnumerator = (id)visibleIndexPaths;
    NSMutableArray* indexArray = [[NSMutableArray alloc] init];
	for (NSIndexPath *path in objOrEnumerator)
	{
        [indexArray addObject:[[NSNumber alloc] initWithInteger:path.row]];
    }
    
    // tell browser to batch load
    [_browser batchLoadThumbnail:indexArray];

}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [_browser setCurrentPhotoIndex:indexPath.row];
    [_browser hideGrid];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [((MWGridCell *)cell).photo cancelAnyLoading];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat margin = [self getMargin];
    CGFloat gutter = [self getGutter];
    CGFloat columns = [self getColumns];
    CGFloat value = floorf(((self.view.bounds.size.width - (columns - 1) * gutter - 2 * margin) / columns));
    return CGSizeMake(value, value);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return [self getGutter];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return [self getGutter];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    CGFloat margin = [self getMargin];
    return UIEdgeInsetsMake(margin, margin, margin, margin);
}


- (void)doneButtonPressed:(id)sender {
    // Only if we're modal and there's a done button
    if (_doneButton)
    {
        [self.browser FinishBrowser];
    }
}

-(NSString*) GetTitle
{
    if (self.selectionMode)
    {
        return NSLocalizedString(@"Select Photos", nil);
    }
    else
    {
        NSString *photosText;
        int numberOfPhotos = [self.browser numberOfPhotos];
        if (numberOfPhotos == 1) {
            photosText = NSLocalizedString(@"photo", @"Used in the context: '1 photo'");
        } else {
            photosText = NSLocalizedString(@"photos", @"Used in the context: '3 photos'");
        }
        return [NSString stringWithFormat:@"%lu %@", (unsigned long)numberOfPhotos, photosText];
    }
    
  
}
-(void) reloadData
{
    [self.collectionView reloadData];
    
    if (SYSTEM_VERSION_LESS_THAN(@"7"))
    {
        [self.view setNeedsLayout];
        [self.view setNeedsDisplay];
    }
}
@end
