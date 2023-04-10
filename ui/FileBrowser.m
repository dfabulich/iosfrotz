/*
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

#import "FileBrowser.h"
#include "iosfrotz.h"

static NSString *kSaveExt = @".sav", *kAltSaveExt = @".qut";

@interface FileInfo : NSObject
{
    NSString *path;
    NSDate *modDate;
}
@property(nonatomic,strong) NSString *path;
@property(nonatomic,strong) NSDate *modDate;
-(NSComparisonResult)compare:(FileInfo*)other;
-(instancetype)initWithPath:(NSString*)path NS_DESIGNATED_INITIALIZER;
-(instancetype)init NS_UNAVAILABLE;
-(nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end

@implementation FileInfo
@synthesize path;
@synthesize modDate;

-(instancetype)initWithPath:(NSString*)aPath {
    if ((self = [super init])) {
        self.path = aPath;
        NSDictionary *fileAttribs = [[NSFileManager defaultManager] fileAttributesAtPath: aPath traverseLink:NO];
        if (fileAttribs)
            self.modDate = fileAttribs[NSFileModificationDate];
    }
    return self;
}

-(NSComparisonResult)compare:(FileInfo*)other {
    return -[self.modDate compare: other.modDate];
}

@end


@implementation FileBrowser
@synthesize delegate = m_delegate;
@synthesize path = m_path;
@synthesize textFileCount = m_textFileCount;

- (instancetype)initWithDialogType:(FileBrowserState)dialogType {
    if ((self = [super initWithNibName:nil bundle:nil]) != nil) {
        m_tableViewController = self;
        m_dialogType = dialogType;
        NSString *title = @"";
        switch (m_dialogType) {
            case kFBDoShowSave:
                title = @"Save Game";
                break;
            case kFBDoShowRestore:
                title = @"Restore Game";
                break;
            case kFBDoShowScript:
                title = @"Save Transcript";
                break;
            case kFBDoShowViewScripts:
                title = @"View Transcript";
                break;
            case kFBDoShowRecord:
                title = @"Save Recording";
                break;
            case kFBDoShowPlayback:
                title = @"Playback Recording";
                break;
            default:
                break;
        }
        if (title)
            self.title = NSLocalizedString(title, @"");

        m_extensions = [[NSMutableArray alloc] init];
        m_files = [[NSMutableArray alloc] initWithCapacity: 32];
        m_rowCount = 0;
        [self setEditing: NO];
    }
    return self;
}

- (void)loadView {
    [super loadView];

    m_tableView = m_tableViewController.tableView;
    [m_tableView setAutoresizingMask: UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleRightMargin];
    [m_tableView setDelegate: self];
    [m_tableView setDataSource: self];
    CGRect origFrame = self.view.frame; //[[UIScreen mainScreen] applicationFrame];
    m_backgroundView = [[UIView alloc] initWithFrame: origFrame];
    [m_backgroundView setBackgroundColor: [UIColor grayColor]];
    [m_backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|
     UIViewAutoresizingFlexibleWidth|
     UIViewAutoresizingFlexibleBottomMargin];
    [m_backgroundView setAutoresizesSubviews: YES];
    self.view = m_backgroundView;
    [m_backgroundView addSubview: m_tableView];
    if (m_dialogType != kFBDoShowRestore && m_dialogType != kFBDoShowViewScripts && m_dialogType != kFBDoShowPlayback) {
        m_textField = [[UITextField alloc] initWithFrame: CGRectMake(0, 0, origFrame.size.width, 30)];
        if (@available(iOS 11.0,*)) {
            UIEdgeInsets insets = UIEdgeInsetsMake(m_textField.frame.size.height, 0, 0, 0);
            self.additionalSafeAreaInsets = insets;
        }
        [m_backgroundView addSubview: m_textField];

        [m_tableView setFrame: CGRectMake(0, m_textField.bounds.size.height,
                                          origFrame.size.width,
                                          origFrame.size.height-m_textField.bounds.size.height)];
        [m_textField setReturnKeyType: UIReturnKeyDone];
        if (@available(iOS 13.0, *)) {
            [m_textField setBackgroundColor: [UIColor systemBackgroundColor]];
        } else {
            [m_textField setBackgroundColor: [UIColor whiteColor]];
        }
        [m_textField setBorderStyle: UITextBorderStyleRoundedRect];
        [m_textField setPlaceholder: @" filename"];
        [m_textField setDelegate: self];
        [m_textField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [m_textField setAutocorrectionType: UITextAutocorrectionTypeNo];
        [m_textField setAutoresizingMask: UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
        
        m_textField.text = @(iosif_filename);
        
        //	[m_tableView setBounces: NO];
        [m_textField becomeFirstResponder];
        [m_backgroundView setNeedsLayout];
    } else
        [m_tableView setFrame: CGRectMake(0, 0, origFrame.size.width, origFrame.size.height)];
    [m_backgroundView bringSubviewToFront: m_textField];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChangeFrame:) name:UIKeyboardDidChangeFrameNotification object:nil];

}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardDidChangeFrame:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    UIWindow *window = [m_tableView window];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect kbIntersectFrame = [window convertRect:CGRectIntersection(window.frame, kbFrame) toView:m_tableView];
    kbIntersectFrame = CGRectIntersection(m_tableView.bounds, kbIntersectFrame);
    
    // get point before contentInset change
    CGPoint pointBefore = m_tableView.contentOffset;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbIntersectFrame.size.height, 0.0);
    m_tableView.contentInset = contentInsets;
    m_tableView.scrollIndicatorInsets = contentInsets;
    // get point after contentInset change
    CGPoint pointAfter = m_tableView.contentOffset;
    // avoid jump by settings contentOffset
    m_tableView.contentOffset = pointBefore;
    // and now animate smoothly
    [m_tableView setContentOffset:pointAfter animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated:animated];
    if (m_tableViewController != self)
        [m_tableViewController setEditing: editing animated:animated];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (@available(iOS 11.0,*)) {
        if (m_textField) {
            CGRect frame = m_textField.frame;
            frame.origin.y = m_tableView.adjustedContentInset.top;
            m_textField.frame = frame;
        }
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (m_alertView)
        return NO;
    NSIndexPath *indexPath = [m_tableView indexPathForSelectedRow];
    if (indexPath != nil)
        [m_tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSMutableString *newFilename = [NSMutableString stringWithString: [textField text]];
    [newFilename replaceCharactersInRange: range withString:string];
    if ([newFilename length] == 0) {
        return YES;
    }
    int row = 0;
    for (FileInfo *fi in m_files) {
        NSString *file = [fi.path lastPathComponent];
        if ([file caseInsensitiveCompare: newFilename] == NSOrderedSame
            || [file caseInsensitiveCompare: [newFilename stringByAppendingString: kSaveExt]] == NSOrderedSame
            || [file caseInsensitiveCompare: [newFilename stringByAppendingString: kAltSaveExt]] == NSOrderedSame) {
            indexPath = [NSIndexPath indexPathForRow: row inSection:0];
            [m_tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
            break;
        }
        row++;
    }
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    NSIndexPath *indexPath = [m_tableView indexPathForSelectedRow];
    if (indexPath != nil)
        [m_tableView deselectRowAtIndexPath:indexPath animated:YES];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (m_alertView)
        return NO;
    if ([[textField text] length] > 0) {
        [self commit: textField];
        return YES;
    }
    return NO;
}

- (void)commit:(id)sender {
    if ([[m_textField text] length] > 0) {
        NSString *selFile = [self selectedFile];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: selFile];
        if (m_dialogType==kFBDoShowScript) {
            if (!exists) {
                exists = [[NSFileManager defaultManager] fileExistsAtPath: [selFile stringByAppendingString: kSaveExt]];
                if (exists)
                    m_textField.text = [m_textField.text stringByAppendingString: @".txt"];
            }
        } else {
            if (!exists) {
                exists = [[NSFileManager defaultManager] fileExistsAtPath: [selFile stringByAppendingString: kSaveExt]];
                if (exists)
                    m_textField.text = [m_textField.text stringByAppendingString: kSaveExt];
            }
            if (!exists) {
                exists = [[NSFileManager defaultManager] fileExistsAtPath: [selFile stringByAppendingString: kAltSaveExt]];
                if (exists)
                    m_textField.text = [m_textField.text stringByAppendingString: kAltSaveExt];
            }
        }
        if (exists && m_dialogType != kFBDoShowScript) {
            if (!m_alertView) {
                m_alertView = [[UIAlertView alloc] initWithTitle:@"Overwrite File" message:@"Do you want to save over this file?"
                                                               delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles: @"Save", nil];
                [m_alertView show];
            }
            return;
        }
        [m_textField endEditing: YES];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSString *file = [textField text];
    
    if ([file length] > 0)
    	[m_delegate fileBrowser:self fileSelected: [self selectedFile]];
    else
    	[m_delegate fileBrowser:self fileSelected:nil];
}

-(void)viewDidLoad {
    if (@available(iOS 11.0,*)) {
    } else {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem* backItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(didPressCancel:)];
    self.navigationItem.leftBarButtonItem = backItem;

    UIBarButtonItem* editItem = [self editButtonItem];
    [editItem setStyle: UIBarButtonItemStylePlain];
    self.navigationItem.rightBarButtonItem = editItem;
    [editItem setEnabled: (m_rowCount > 0)];

    if (@available(iOS 13.0, *)) {
        self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor labelColor]};
    } else {
        [self.navigationController.navigationBar setBarStyle: UIBarStyleDefault];
        [self.navigationController.navigationBar setBarTintColor: [UIColor whiteColor]];
        [self.navigationController.navigationBar setTintColor:  [UIColor darkGrayColor]];
    }

    self.navigationController.presentationController.delegate = self;
}

-(void)viewWillDisappear:(BOOL)animated {
    // since the save dialog and parent vc both have the keyboard showing and there's not much vertical space,
    // the normal dismissal animation looks stuttery.  It's better just to fade out in this case.
    [super viewWillDisappear:animated];
    if (animated && UIInterfaceOrientationIsLandscape([self interfaceOrientation]) && m_dialogType != kFBDoShowRestore && m_dialogType != kFBDoShowViewScripts && m_dialogType != kFBDoShowPlayback)
        [self.navigationController.view.superview setHidden: YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSInteger row = indexPath.row;
        if (row < [m_files count]) {
            if ([m_delegate respondsToSelector: @selector(fileBrowser:deleteFile:)])
                [m_delegate fileBrowser:self deleteFile: [m_files[row] path]];
            [m_files removeObjectAtIndex: row];
            m_rowCount = [m_files count];
            NSArray *indexPaths = @[indexPath];
            [m_tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
            [self reloadData];
            [[self editButtonItem] setEnabled: (m_rowCount > 0)];
        }
    }
}

-(void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    [self didPressCancel: self];
}

-(void)didPressCancel:(id)sender {
    if (m_textField) {
        [m_textField setText: nil];
        NSIndexPath *indexPath = [m_tableView indexPathForSelectedRow];
        if (indexPath)
            [m_tableView  deselectRowAtIndexPath:indexPath animated:NO];
        [m_textField endEditing: YES];
    } else if( [m_delegate respondsToSelector:@selector( fileBrowser:fileSelected: )] )
        [m_delegate fileBrowser:self fileSelected: nil];
}

- (void)setPath: (NSString *)path {
    if (m_path != path) {
        m_path = [path copy];
    }
    
    [self reloadData];
}

- (void)addExtension: (NSString *)extension {
    if (![m_extensions containsObject:[extension lowercaseString]]) {
        [m_extensions addObject: [extension lowercaseString]];
    }
}

- (void)setExtensions: (NSArray *)extensions {
    [m_extensions setArray: extensions];
}

- (void)reloadData {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath: m_path] == NO) {
        return;
    }
    
    [m_files removeAllObjects];
    
    NSString *file;
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath: m_path];
    while ((file = [dirEnum nextObject])) {
        BOOL isDir;
        NSString *path = [m_path stringByAppendingPathComponent: file];
        if ([fileManager fileExistsAtPath: path isDirectory: &isDir] && !isDir) {
            const char *fn = [file cStringUsingEncoding: NSUTF8StringEncoding];
            if (fn && strcasecmp(fn, kFrotzAutoSaveFile) != 0 && strcasecmp(fn, kFrotzAutoSavePListFile) != 0
                && strcasecmp(fn, kFrotzAutoSaveFileGlkWin) != 0) {
                if ([file hasSuffix: @".png"] || [file hasSuffix: @".jpg"])
                    continue;
                if (m_dialogType==kFBDoShowRecord || m_dialogType==kFBDoShowPlayback) {
                    if (![file hasSuffix:@".rec"])
                        continue;
                } else if (m_dialogType==kFBDoShowScript || m_dialogType==kFBDoShowViewScripts) {
                    if (([file hasSuffix: kSaveExt] || [file hasSuffix: kAltSaveExt]))
                        continue;
                    ++m_textFileCount;
                } else if ([file hasSuffix: @".scr"] || [file hasSuffix: @".txt"] || [file hasSuffix: @".rec"])
                    continue;
                FileInfo *fi = [[FileInfo alloc] initWithPath: path];
                [m_files addObject: fi];
            }
        }
    }
    
    [m_files sortUsingSelector:@selector(compare:)];
    m_rowCount = [m_files count];
    [m_tableView reloadData];
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    if (m_dialogType==kFBDoShowScript || m_dialogType==kFBDoShowViewScripts || m_dialogType==kFBDoShowRecord || m_dialogType == kFBDoShowPlayback)
        return nil;
    if (section == 0 && m_rowCount > 0)
        return @"Previously saved games";
    else
        return @"No saved games";
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection: (NSInteger)section {
    return m_rowCount;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    return 1;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"saveGameCell"];
    if (cell == nil) {
        cell = [UITableViewCell alloc];
        if ([cell respondsToSelector: @selector(initWithStyle:reuseIdentifier:)])
            cell = [cell initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"saveGameCell"];
        else
            cell = [cell initWithFrame:CGRectZero reuseIdentifier:@"saveGameCell"];
    }
    
    NSString *file = [[m_files[indexPath.row] path] lastPathComponent], *cellText = nil;
    if ([file hasSuffix: kSaveExt] || [file hasSuffix: kAltSaveExt]) {
        cellText = [file stringByDeletingPathExtension];
        if (indexPath.row > 0 && [[[m_files[indexPath.row-1] path] lastPathComponent] isEqual: cellText])
            cellText = file;
	}
    else
        cellText = file;
    cell.text = cellText;
    if ([cell respondsToSelector: @selector(detailTextLabel)]) {
        NSDate *moddate = [m_files[indexPath.row] modDate];
        
        if (moddate)
            cell.detailTextLabel.text = [NSString stringWithFormat: @"%@; .%@", [moddate description], [[file pathExtension] lowercaseString]];
        else
            cell.detailTextLabel.text = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self setEditing: NO];
    if (m_textField) {
        if (indexPath != nil) {
            NSString *file = [[m_files[indexPath.row] path] lastPathComponent];
            if ([file hasSuffix: kSaveExt] || [file hasSuffix: kAltSaveExt])
                [m_textField setText:[file stringByDeletingPathExtension]];
            else
                [m_textField setText: file];
        }
    }
    else {
        if( [m_delegate respondsToSelector:@selector( fileBrowser:fileSelected: )] ) {
            
            if (m_dialogType == kFBDoShowViewScripts) {
                CGRect bounds = self.view.bounds;
                CGFloat margin = self.view.safeAreaInsets.top;
                bounds.origin.y += margin;
                bounds.size.height -= margin;
                UITextView *textView = [[UITextView alloc] initWithFrame: bounds];
                NSString *text = [[NSString alloc] initWithData: [[NSFileManager defaultManager] contentsAtPath: [self selectedFile]] encoding:NSUTF8StringEncoding];
                textView.text = text;
                textView.editable = NO;
                [self.view addSubview: textView];
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                    target:self action:@selector(doneWithTextFile:)];
                self.navigationItem.rightBarButtonItem = nil;
                return;
            }
            
            [m_delegate fileBrowser:self fileSelected:[self selectedFile]];
        }
    }
}

-(void)doneWithTextFile:(id)sender {
    [m_delegate fileBrowser:self fileSelected:[self selectedFile]];
}    

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    m_alertView = nil;
    if (buttonIndex == 1) { 
        [m_textField endEditing: YES];
    }
}

- (NSString *)selectedFile {
    if (m_textField && [[m_textField text] length] > 0)
        return [m_path stringByAppendingPathComponent: [m_textField text]];    
    NSIndexPath *indexPath = [m_tableView indexPathForSelectedRow];
    if (indexPath == nil || indexPath.row == -1) {
        return nil;
    }
    return [m_files[indexPath.row] path];
}

@end
