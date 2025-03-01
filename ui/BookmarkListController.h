//
//  BookmarkListController.h
//  Frotz
//
//  Created by Craig Smith on 8/6/08.
//  Copyright 2008 Craig Smith. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BookmarkDelegate <NSObject>
-(void)enterURL:(NSString*)url;
-(NSString*)currentURL;
-(NSString*)currentURLTitle;
-(void)hideBookmarks;
-(void)loadBookmarksWithURLs:(NSArray**)urls andTitles:(NSArray**)titles;
-(void)saveBookmarksWithURLs:(NSArray*)urls andTitles:(NSArray*)titles;
-(NSString*)bookmarkPath;
@end

@interface BookmarkListController : UITableViewController {
    NSMutableArray *m_sites;
    NSMutableArray *m_titles;
    id<BookmarkDelegate> __weak m_delegate;
    UITableView *m_tableView;
    UIToolbar *m_toolBar;
}
@property (nonatomic, weak) id<BookmarkDelegate> delegate;
@end
