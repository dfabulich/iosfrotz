/*
 *  ui_utils.h
 *  Frotz
 *
 *  Created by Craig Smith on 8/3/08.
 *  Copyright 2008 Craig Smith. All rights reserved.
 *
 */
#include <UIKit/UIKit.h>


CF_IMPLICIT_BRIDGING_ENABLED

CGContextRef createBlankFilledCGContext(unsigned int bgColor, size_t destWidth, size_t destHeight);

CF_IMPLICIT_BRIDGING_DISABLED

void drawRectInCGContext(CGContextRef cgctx, unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height);
void drawCGImageInCGContext(CGContextRef cgctx, CGImageRef imageRef, int x, int y, size_t scaleWidth, size_t scaleHeight);

CGImageRef drawCGImageInCGImage(CGImageRef imageRef, int x, int y, size_t scaleWidth, size_t scaleHeight, CGImageRef destImageRef) CF_RETURNS_RETAINED;

CF_IMPLICIT_BRIDGING_ENABLED

CGImageRef createBlankCGImage(unsigned int bgColor, size_t destWidth, size_t destHeight);

CF_IMPLICIT_BRIDGING_DISABLED

CGImageRef drawRectInCGImage(unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height, CGImageRef destImageRef) CF_RETURNS_RETAINED;

UIImage *scaledUIImage(UIImage *image, size_t newWidth, size_t newHeight);
UIImage *drawUIImageInUIImage(UIImage *image, int x, int y, size_t scaleWidth, size_t scaleHeight, UIImage *destImage);
UIImage *drawRectInUIImage(unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height, UIImage *destImage);
UIImage *createBlankUIImage(unsigned int bgColor, size_t destWidth, size_t destHeight);
NSData *imageDataFromBlorb(NSString *blorbFile);
UIColor *UIColorFromInt(unsigned int color);
BOOL MetaDataFromBlorb(NSString *blorbFile, NSString **title, NSString **author, NSString **description, NSString **tuid);

BOOL IsTadsFileExtension(NSString *ext);
BOOL IsZCodeExtension(NSString *ext);
BOOL IsGlulxExtension(NSString *ext);
BOOL IsSupportedFileExtension(NSString *ext);
extern NSString *const kSaveExt, *const kAltSaveExt;

void HandleITSSaveGameFile(NSString *file);
void HandleITSGameFile(NSString *file);

BOOL ReadGLULheaderFromUlxOrBlorb(const char *filename, char *glulHeader);
BOOL ReadHeaderFromZCodeUlxOrBlorb(const char *filename, char *header, BOOL *isGlulx);
BOOL ReadStoryReleaseAndSerial(const char *filename, UInt16 *release, char *serial);

BOOL ReadSavedGameReleaseAndSerial(NSString *path, UInt16 *release, char *serial);
BOOL DoesGameFileMatchSave(NSString *path, UInt16 checkRelease, char *checkSerial);
