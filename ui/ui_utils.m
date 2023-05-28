/*
 *  ui_utils.c
 *  Frotz
 *
 *  Created by Craig Smith on 8/3/08.
 *  Copyright 2008 Craig Smith. All rights reserved.
 *
 */

#include "iosfrotz.h"
#include "ui_utils.h"

static CGContextRef CreateARGBBitmapContext (size_t pixelsWide, size_t pixelsHigh);

UIImage *scaledUIImage(UIImage *image, size_t newWidth, size_t newHeight)
{
    if (!image)
        return nil;
    CGImageRef inImage = [image CGImage];
    if (!inImage)
        return nil;
	
    CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;
    
    size_t origWidth = CGImageGetWidth(inImage);
    size_t origHeight = CGImageGetHeight(inImage);
    UIImage *img = nil;
    if (newWidth == 0 && newHeight == 0) {
        if (!gLargeScreenDevice &&
            (origHeight <= screenSize.height*2 && origWidth <= screenSize.width*2)
            && [image respondsToSelector:@selector(scale)]) {
            // ??? can we also check if the device actually supports scale > 1.0?
            if ([image scale] < 2.0 && (origHeight > screenSize.height || origWidth > screenSize.width))
                img = [UIImage imageWithCGImage:inImage scale:2.0 orientation:UIImageOrientationUp];
            else
                img = image;
            return img;
        }
        
        newWidth = newHeight = screenSize.width; // fall thru...
    }
    
    if (origWidth < newWidth || origHeight < newHeight) {
        newWidth = origWidth;
        newHeight = origHeight;
    } else if (origWidth >= origHeight) {
        newHeight = (int)(origHeight * ((double)newWidth / origWidth));    
    } else {
        newWidth = (int)(origWidth * ((double)newHeight / origHeight));    
    }
    if (origWidth==newWidth && origHeight==newHeight)
        return image;

    CGFloat scale = 1.0;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        scale = [[UIScreen mainScreen] scale];
    
    if (scale > 1.0) {
        newWidth *= scale;
        newHeight *= scale;
    }
    // Create the bitmap context
    CGContextRef cgctx = CreateARGBBitmapContext(newWidth, newHeight);
    if (cgctx == NULL)     // error creating context
        return nil;
    
    // Get image width, height. We'll use the entire image.
    CGRect rect = {{0,0},{newWidth,newHeight}};
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextSetRGBFillColor(cgctx, 1.0, 1.0, 1.0, 0.0);
    CGContextFillRect(cgctx, rect);
    CGContextDrawImage(cgctx, rect, inImage);
    
    CGImageRef newRef = CGBitmapContextCreateImage(cgctx);
    
    void *data = CGBitmapContextGetData(cgctx);
    
    // When finished, release the context
    CGContextRelease(cgctx);
    if (scale > 1.0)
        img = [UIImage imageWithCGImage: newRef scale:scale orientation:UIImageOrientationUp];
    else
        img= [UIImage imageWithCGImage: newRef];

    CGImageRelease(newRef);
    // Free image data memory for the context
    if (data)
        free(data);
    
    return img;
}

UIImage *drawUIImageInImage(UIImage *image, int x, int y, size_t scaleWidth, size_t scaleHeight, UIImage *destImage) {

    if (!image || !destImage)
        return nil;
    CGImageRef imageRef = [image CGImage];
    CGImageRef destImageRef = [destImage CGImage];
    destImageRef = drawCGImageInCGImage(imageRef, x, y, scaleWidth, scaleHeight, destImageRef);
    UIImage *img= [UIImage imageWithCGImage: destImageRef];
    CGImageRelease(destImageRef);
    return  img;
}

void drawCGImageInCGContext(CGContextRef cgctx, CGImageRef imageRef, int x, int y, size_t scaleWidth, size_t scaleHeight)
{
    size_t destHeight = CGBitmapContextGetHeight(cgctx);
    CGImageRef inImage = imageRef;
    if (!inImage)
        return;
//    NSLog(@"draw img %p +%d+%d %dx%d", imageRef, x, y, scaleWidth, scaleHeight);
    CGRect rect = {{x, (int)destHeight-y-(int)scaleHeight},{scaleWidth,scaleHeight}};

    CGContextDrawImage(cgctx, rect, inImage);

}

CGImageRef drawCGImageInCGImage(CGImageRef imageRef, int x, int y, size_t scaleWidth, size_t scaleHeight, CGImageRef destImageRef)
{
    if (!imageRef || !destImageRef)
        return nil;
    CGImageRef inImage = imageRef;
    CGImageRef origImage = destImageRef;
    
    if (!inImage || !origImage)
        return nil;
    
    size_t destWidth = CGImageGetWidth(destImageRef);
    size_t destHeight = CGImageGetHeight(destImageRef);
    
    if (scaleHeight > destHeight) {
        scaleHeight /= 2; 
    }
    if (scaleWidth > destWidth) {
        scaleWidth /= 2;
    }
    
    // Create the bitmap context
    CGContextRef cgctx = CreateARGBBitmapContext(destWidth, destHeight);
    if (cgctx == NULL)     // error creating context
        return nil;
    
    // Get image width, height. We'll use the entire image.
    CGRect destRect = {{0,0},{destWidth,destHeight}};
    
    CGContextDrawImage(cgctx, destRect, origImage);
    
    CGRect rect = {{x, destHeight-y-scaleHeight},{scaleWidth,scaleHeight}};
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextDrawImage(cgctx, rect, inImage);
    
    CGImageRef newRef = CGBitmapContextCreateImage(cgctx);
    
    void *data = CGBitmapContextGetData(cgctx);
    
    // When finished, release the context
    CGContextRelease(cgctx);
    // Free image data memory for the context
    if (data)
        free(data);
    
    return newRef;
}

UIImage *drawRectInUIImage(unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height, UIImage *destImage) {
    if (!destImage)
        return nil;
    CGImageRef origImage = [destImage CGImage];
    CGImageRef newRef = drawRectInCGImage(color, x, y, width, height, origImage);
    UIImage *img= [UIImage imageWithCGImage: newRef];
    CGImageRelease(newRef);
    return img;

}

void drawRectInCGContext(CGContextRef cgctx, unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    //size_t destWidth = CGBitmapContextGetHeight(cgctx);
    size_t destHeight = CGBitmapContextGetHeight(cgctx);
    //CGRect destRect = {{0,0},{destWidth,destHeight}};

    CGFloat red = ((color >> 16) & 0xff) / 255.0;
    CGFloat green = ((color >> 8) & 0xff) / 255.0;
    CGFloat blue = (color & 0xff) / 255.0;
    CGContextSetRGBFillColor(cgctx, red, green, blue, 1.0);
    CGContextFillRect(cgctx, CGRectMake(x, destHeight-y-height, width, height));
    
}

CGImageRef drawRectInCGImage(unsigned int color, CGFloat x, CGFloat y, CGFloat width, CGFloat height, CGImageRef destImageRef)
{
    if (!destImageRef)
        return nil;
    CGImageRef origImage = destImageRef;

    size_t destWidth = CGImageGetWidth(origImage);
    size_t destHeight = CGImageGetHeight(origImage);
    
    // Create the bitmap context
    CGContextRef cgctx = CreateARGBBitmapContext(destWidth, destHeight);
    if (cgctx == NULL)     // error creating context
        return nil;
    
    CGRect destRect = {{0,0},{destWidth,destHeight}};
    
    CGContextDrawImage(cgctx, destRect, origImage);
    
    CGFloat red = ((color >> 16) & 0xff) / 255.0;
    CGFloat green = ((color >> 8) & 0xff) / 255.0;
    CGFloat blue = (color & 0xff) / 255.0;
    CGContextSetRGBFillColor(cgctx, red, green, blue, 1.0);
    CGContextFillRect(cgctx, CGRectMake(x, destHeight-y-height, width, height));
    
    CGImageRef newRef = CGBitmapContextCreateImage(cgctx);
    
    void *data = CGBitmapContextGetData(cgctx);
    
    // When finished, release the context
    CGContextRelease(cgctx);
    
    // Free image data memory for the context
    if (data)
        free(data);
    
    return newRef;
}

UIColor *UIColorFromInt(unsigned int color) {
    CGFloat red = ((color >> 16) & 0xff) / 255.0;
    CGFloat green = ((color >> 8) & 0xff) / 255.0;
    CGFloat blue = (color & 0xff) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}


CGContextRef createBlankFilledCGContext(unsigned int bgColor, size_t destWidth, size_t destHeight) {
    CGContextRef cgctx = CreateARGBBitmapContext(destWidth, destHeight);
    
    CGFloat red = ((bgColor >> 16) & 0xff) / 255.0;
    CGFloat green = ((bgColor >> 8) & 0xff) / 255.0;
    CGFloat blue = (bgColor & 0xff) / 255.0;
    CGContextSetRGBFillColor(cgctx, red, green, blue, 1.0);
    CGContextFillRect(cgctx, CGRectMake(0, 0, destWidth, destHeight));
//`    NSLog(@"new cgctx %p", cgctx);
    return cgctx;
}

CGImageRef createBlankCGImage(unsigned int bgColor, size_t destWidth, size_t destHeight) {
    CGContextRef cgctx = createBlankFilledCGContext(bgColor, destWidth, destHeight);
    CGImageRef newRef = CGBitmapContextCreateImage(cgctx);
    
    void *data = CGBitmapContextGetData(cgctx);
    
    // When finished, release the context
    CGContextRelease(cgctx);
    
    // Free image data memory for the context
    if (data)
        free(data);
    
    return newRef;
}

UIImage *createBlankUIImage(unsigned int bgColor, size_t destWidth, size_t destHeight) {
    // Free image data memory for the context
    CGImageRef imgRef = createBlankCGImage(bgColor, destWidth, destHeight);
    UIImage *img= [UIImage imageWithCGImage: imgRef];
    CGImageRelease(imgRef);
    return img;
}

CGContextRef CreateARGBBitmapContext (size_t pixelsWide, size_t pixelsHigh)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    void *          bitmapData;
    size_t             bitmapByteCount;
    size_t             bitmapBytesPerRow;
    
    // Declare the number of bytes per row. Each pixel in the bitmap in this
    // example is represented by 4 bytes; 8 bits each of red, green, blue, and
    // alpha.
    bitmapBytesPerRow   = (pixelsWide * 4);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        NSLog(@"Error allocating color space\n");
        return NULL;
    }
    
    // Allocate memory for image data. This is the destination in memory
    // where any drawing to the bitmap context will be rendered.
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL)
    {
        NSLog(@"BitmapContext memory not allocated!");
        CGColorSpaceRelease( colorSpace );
        return NULL;
    }
    
    // Create the bitmap context. We want pre-multiplied ARGB, 8-bits
    // per component. Regardless of what the source image format is
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedFirst);
    if (context == NULL)
    {
        free (bitmapData);
        NSLog(@"Context not created!");
    }
    
    // Make sure and release colorspace before returning
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

NSString *const kSaveExt = @".sav", *const kAltSaveExt = @".qut";

BOOL IsTadsFileExtension(NSString *ext) {
    return ([ext isEqualToString: @"gam"] || [ext isEqualToString: @"t3"]);
}

BOOL IsZCodeExtension(NSString *ext) {
    if ([ext isEqualToString: @"z1"] ||
        [ext isEqualToString: @"z2"]||
        [ext isEqualToString: @"z3"]||
        [ext isEqualToString: @"z4"]||
        [ext isEqualToString: @"z5"] ||
        [ext isEqualToString: @"z8"] ||
        [ext isEqualToString: @"zblorb"] ||
        [ext isEqualToString: @"zlb"] ||
        [ext isEqualToString: @"dat"])
        return YES;
    return NO;
}

BOOL IsGlulxExtension(NSString *ext) {
    if ([ext isEqualToString: @"blb"] ||
        [ext isEqualToString: @"ulx"] ||
        [ext isEqualToString: @"gblorb"])
        return YES;
    return NO;
}

BOOL IsSupportedFileExtension(NSString *ext) {
    if (IsZCodeExtension(ext))
        return YES;
    if (IsGlulxExtension(ext))
        return YES;
    if (IsTadsFileExtension(ext))
        return YES;
    return NO;
}

BOOL DoesGameFileMatchSave(NSString *path, UInt16 checkRelease, char *checkSerial) {
    const char *filename = [path fileSystemRepresentation];
    UInt16 release = 0;
    char serial[32];
    memset(serial, 0, sizeof(serial));
    if (ReadStoryReleaseAndSerial(filename, &release, serial)) {
        if (release == checkRelease && strcmp(checkSerial, serial) == 0)
            return YES;
    }
    return NO;
}

void MoveFileToPathWithUniquenessRename(NSString *srcPath, NSString *dstPath) {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![defaultManager fileExistsAtPath: dstPath]) {
        [defaultManager moveItemAtPath:srcPath toPath:dstPath error:&error];
    } else {
        NSString *srcName = [srcPath lastPathComponent];
        NSString *ext = [srcName pathExtension];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"YYMMdd_HHmmss"];
        NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];

        NSString *renamedFile = [[srcName stringByDeletingPathExtension] stringByAppendingFormat:@"_%@.%@", timestamp, ext];
        NSLog(@"- file already exists at %@", [[[dstPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent: srcName]);

        NSString *renamedDstPath = [[dstPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:renamedFile];
        [defaultManager moveItemAtPath:srcPath toPath:renamedDstPath error:&error];
        NSLog(@"- renamed to %@", renamedFile);
    }
    if (error) {
        NSLog(@"- failed to install file, error: %@, discarding", error);
        [defaultManager removeItemAtPath:srcPath error:&error];
    }
}

// Handle save files copied in via iTunes File Sharing.  File extension already matched.
void HandleITSSaveGameFile(NSString *file)
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];

    NSLog(@"Found save game %@", file);
    NSString *srcFile = [docPath stringByAppendingPathComponent: file];
    UInt16 release;
    char serial[32];
    if (ReadSavedGameReleaseAndSerial(srcFile, &release, serial)) {
        BOOL found = NO;
        NSArray *gameRootPaths = @[docPath, [[NSBundle mainBundle] resourcePath]];
        for (NSString *gameRootDir in gameRootPaths) {
            NSString *storyGameFolderPath = [gameRootDir stringByAppendingPathComponent: @kFrotzGameDir];
            NSArray *gameFiles = [defaultManager contentsOfDirectoryAtPath:storyGameFolderPath error:&error];
            for (NSString *gameFile in gameFiles) {
                NSString *gamePath = [storyGameFolderPath stringByAppendingPathComponent: gameFile];
                BOOL match = DoesGameFileMatchSave(gamePath, release, serial);
                if (match) {
                    NSLog(@"- saved game matches story %@!", gameFile);
                    found = YES;
                    NSString *storySaveGameFolderPath = [docPath stringByAppendingPathComponent: @kFrotzSaveDir];
                    NSString *storySaveGamePath = [storySaveGameFolderPath stringByAppendingPathComponent: [gameFile stringByAppendingString: @kFrotzGameSaveDirExt]];
                    storySaveGamePath = [storySaveGamePath stringByAppendingPathComponent: file];
                    MoveFileToPathWithUniquenessRename(srcFile, storySaveGamePath);
                    break;
                }
            }
            if (found)
                break;
        }
        if (!found)
            NSLog(@"- failed to find story file for saved game");
    } else
        NSLog(@"- unknown save format");
}

// Handle game files copied in via iTunes File Sharing.  File extension already matched.
void HandleITSGameFile(NSString *file)
{
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];

    NSString *storyGameFolderPath = [docPath stringByAppendingPathComponent: @kFrotzGameDir];
    NSString *storyGamePath = [storyGameFolderPath stringByAppendingPathComponent: file];
    NSLog(@"Found game %@, installing", file);
    NSString *srcFile = [docPath stringByAppendingPathComponent: file];
    MoveFileToPathWithUniquenessRename(srcFile, storyGamePath);
}

BOOL ReadSavedGameReleaseAndSerial(NSString *path, UInt16 *release, char *serial) {
    FILE *fp;
    const char *filename = [path fileSystemRepresentation];
    BOOL success = NO;
    if ((fp = os_path_open(filename, "rb")) == NULL)
        return NO;
    unsigned char zblorbbuf[512];
    unsigned char *z;
    unsigned int fileSize=0, chunkSize=0, pos;
    while (1) {
        if (fread(zblorbbuf, 1, 12, fp)!=12)
            break;
        z = zblorbbuf;
        if (strncmp((char*)z, "TADS2",5) == 0) {
            if (fread(zblorbbuf+12, 1, 6, fp) != 6)
                break;
            if (strncmp((char*)z+5, " save/g\012\015\032", 10)!=0)
                break;
            z = zblorbbuf+16;
            int fnlen = z[0] + z[1]*256;
            if (fnlen > 384) // balk if filename too long
                break;
            z += 2;
            if (fread(z, 1, fnlen, fp) != fnlen)
                break;
            z += fnlen;
            if (fread(z, 1, 14+7+26, fp) != 47)
                break;
            if (strncmp((char*)z, "TADS2 save\012\015\032", 13)!=0)
                break;
            z += 14;
            if (strncmp((char*)z, "v2.2.", 5) != 0 || z[5] != '0' && z[5] != '1')
                break;
            *release = 0; // z[5] == '1' ? 0 : 1; // somehow, version 0 is 'current', matching 2.2.1
            strncpy(serial, (char*)z+7, 26);
            serial[26] = '\0';
            success = YES;
            break;
        }
        if (*z++ != 'F') break;
        if (*z++ != 'O') break;
        if (*z++ != 'R') break;
        if (*z++ != 'M') break;
        fileSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
        z += 4;
        if (*z++ != 'I') break;
        if (*z++ != 'F') break;
        if (*z++ != 'Z') break;
        if (*z   != 'S') break;
        pos = 12;
        while (pos < fileSize) {
            if (fread(zblorbbuf, 1, 8, fp) != 8)
                break;
            pos += 8;
            z = zblorbbuf+4;
            chunkSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
            z = zblorbbuf;
            if (chunkSize >= 8 && z[0]=='I' && z[1]=='F' && z[2]=='h' && z[3]=='d') {
                if (fread(zblorbbuf, 1, 8, fp)!=8)
                    break;
                *release = (z[0] << 8) | z[1];
                strncpy(serial, (char*)z+2, 6);
                serial[7] = '\0';
                success = YES;
            }
            break;
        }
    }
    fclose(fp);
    return success;
}

BOOL ReadStoryReleaseAndSerial(const char *filename, UInt16 *release, char *serial) {
    BOOL isGlulx = NO;
    char header[128];
    BOOL readHeader = ReadHeaderFromZCodeUlxOrBlorb(filename, header, &isGlulx);
    if (readHeader) {
        if (isGlulx) {
            char *p = &header[36], *headerEnd = &header[sizeof(header)-16];
            while (p < headerEnd) {
                if (strncmp(p, "INFO", 4)==0) { // Inform compiler header
                    p += 8;
                    if (*p=='6' || *p=='7') { // Inform version
                        while (p < headerEnd && (isdigit(*p) || *p=='.')) {
                            p++;
                        }
                        if (p < headerEnd) {
                            *release = (p[0]<<8) | p[1];
                            strncpy(serial, p+1, 6);
                            serial[6] = '\0';
                            return YES;
                        }
                    }
                }
                p++;
            }
            return NO;
        } if (strncmp(header, "TADS2 bin\012\015\032",12) == 0) {
            *release = 0;
            strncpy(serial, header+13+9, 26);
            serial[26] = '\0';
        } else {
            *release = (header[H_RELEASE]<<8) | header[H_RELEASE+1];
            strncpy(serial, &header[H_SERIAL], 6);
            serial[6] = '\0';
        }
    }
    return readHeader;
}


BOOL ReadGLULheaderFromUlxOrBlorb(const char *filename, char *glulHeader) {
    BOOL isGlulx = NO;
    BOOL readHeader= ReadHeaderFromZCodeUlxOrBlorb(filename, glulHeader, &isGlulx);
    return readHeader && isGlulx;
}

BOOL ReadHeaderFromZCodeUlxOrBlorb(const char *filename, char *header, BOOL *isGlulx) {
    BOOL found = NO;
    FILE *fp;
    if (isGlulx)
        *isGlulx = NO;
    if ((fp = os_path_open(filename, "rb")) == NULL)
        return NO;
    unsigned char zblorbbuf[128];
    unsigned char *z;
    unsigned int fileSize=0, chunkSize=0, pos = -1;
    while (1) {
        if (fread(zblorbbuf, 1, 12, fp)!=12)
            break;
        z = zblorbbuf;
        if (strncmp((char*)z, "TADS2 bin\012\015\032",12) == 0) {
            if (fread(zblorbbuf+12, 1, 36, fp) != 36)
               break;
            found = YES;
            if (header)
                memcpy(header, zblorbbuf, 48);
            break;
        }
        if (z[0]=='G' && z[1]=='l' && z[2]=='u' && z[3]=='l') {
            if (fread(zblorbbuf+12, 1, 36, fp) != 36)
               break;
            goto foundGLUL;
        }
        pos = 0;
        if (*z++ != 'F') break;
        if (*z++ != 'O') break;
        if (*z++ != 'R') break;
        if (*z++ != 'M') break;
        fileSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
        z += 4;
        if (*z++ != 'I') break;
        if (*z++ != 'F') break;
        if (*z++ != 'R') break;
        if (*z   != 'S') break;
        pos = 12;
        while (pos < fileSize) {
            if (fread(zblorbbuf, 1, 8, fp) != 8)
                break;
            pos += 8;
            z = zblorbbuf+4;
            chunkSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
            if (chunkSize % 2 == 1)
                chunkSize++;
            z = zblorbbuf;

            if (chunkSize >= 48 && z[0]=='G' && z[1]=='L' && z[2]=='U' && z[3]=='L') {
                if (fread(zblorbbuf, 1, 128, fp)!=128)
                    break;
                if (z[0]=='G' && z[1]=='l' && z[2]=='u' && z[3]=='l') {
                foundGLUL:
                    found = YES;
                    if (isGlulx)
                        *isGlulx = YES;
                    if (header)
                        memcpy(header, z, 128);
                }
                break;
            } else if (chunkSize >= 64 && z[0]=='Z' && z[1]=='C' && z[2]=='O' && z[3]=='D') {
                if (fread(zblorbbuf, 1, 64, fp)!=64)
                    break;
                found = YES;
                if (header)
                    memcpy(header, z, 64);
                break;
            } else {
                pos += chunkSize;
                fseek (fp, pos, SEEK_SET);
            }
        }
        break;
    }
    if (!found && pos == 0) { // Not FORM, not GLUL, read 12 bytes
        if (fread(zblorbbuf+12, 1, 52, fp) == 52) {
            z = zblorbbuf;
            if (z[0] > 0 && z[0] <= 8 && isdigit(z[18]) && isdigit(z[23])) {
                found = YES;
                if (header)
                    memcpy(header, z, 64);
            }
        }
    }
    fclose(fp);
    return found;
}


BOOL MetaDataFromBlorb(NSString *blorbFile, NSString **title, NSString **author, NSString **description, NSString **tuid) {
    const char *filename = [blorbFile fileSystemRepresentation];
    BOOL found = NO;
    FILE *fp;
    if ((fp = os_path_open(filename, "rb")) == NULL)
        return NO;
    unsigned char zblorbbuf[16];
    unsigned char *z;
    unsigned int fileSize=0, chunkSize=0, pos;
    while (1) {
        if (fread(zblorbbuf, 1, 12, fp)!=12)
            break;
        z = zblorbbuf;
        if (*z++ != 'F') break;
        if (*z++ != 'O') break;
        if (*z++ != 'R') break;
        if (*z++ != 'M') break;
        fileSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
        z += 4;
        if (*z++ != 'I') break;
        if (*z++ != 'F') break;
        if (*z++ != 'R') break;
        if (*z   != 'S') break;
        pos = 12;
        while (pos < fileSize) {
            if (fread(zblorbbuf, 1, 8, fp) != 8)
                break;
            pos += 8;
            z = zblorbbuf+4;
            chunkSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
            if (chunkSize % 2 == 1)
                chunkSize++;
            z = zblorbbuf;
            if (z[0]=='I' && z[1]=='F' && z[2]=='m' && z[3]=='d') {
                char *buf = malloc(chunkSize+1);
                if (!buf)
                    break;
                buf[chunkSize] = 0;
                if (fread(buf, 1, chunkSize, fp) != chunkSize) {
                    free(buf);
                    break;
                }
                NSString *xmlString = @(buf);
                NSRange r = [xmlString rangeOfString: @"<identification>"], r2 = [xmlString rangeOfString: @"</identification>"];
                if (r.length && r2.length) {
                    NSRange r3 = [xmlString rangeOfString:@"<tuid>" options:0 range: NSMakeRange(r.location+r.length, r2.location-(r.location+r.length))];
                    if (r3.length) {
                        NSRange r4 = [xmlString rangeOfString:@"</tuid>" options:0 range: NSMakeRange(r3.location+r3.length, r2.location-(r3.location+r3.length))];
                        if (r4.length) {
                            NSString *xtuid = [xmlString substringWithRange: NSMakeRange(r3.location+r3.length, r4.location-(r3.location+r3.length))];
                            if (tuid)
                                *tuid = xtuid;
                        }
                    }
                }
                r = [xmlString rangeOfString: @"<bibliographic>"]; r2 = [xmlString rangeOfString: @"</bibliographic>"];
                if (r.length && r2.length) {
                    NSRange r3 = [xmlString rangeOfString:@"<title>" options:0 range: NSMakeRange(r.location+r.length, r2.location-(r.location+r.length))];
                    if (r3.length) {
                        NSRange r4 = [xmlString rangeOfString:@"</title>" options:0 range: NSMakeRange(r3.location+r3.length, r2.location-(r3.location+r3.length))];
                        if (r4.length) {
                            found = YES;
                            NSString *xtitle = [xmlString substringWithRange: NSMakeRange(r3.location+r3.length, r4.location-(r3.location+r3.length))];
                            if (title) {
                                xtitle = [xtitle stringByReplacingOccurrencesOfString: @"&amp;" withString:@"&"];
                                xtitle = [xtitle stringByReplacingOccurrencesOfString: @"&lt;" withString:@"<"];
                                xtitle = [xtitle stringByReplacingOccurrencesOfString: @"&gt;" withString:@">"];                                         
                                *title = xtitle;
                            }
                        }
                    }
                    r3 = [xmlString rangeOfString:@"<author>" options:0 range: NSMakeRange(r.location+r.length, r2.location-(r.location+r.length))];
                    if (r3.length) {
                        found = YES;
                        NSRange r4 = [xmlString rangeOfString:@"</author>" options:0 range: NSMakeRange(r3.location+r3.length, r2.location-(r3.location+r3.length))];
                        if (r4.length) {
                            NSString *xauthor = [xmlString substringWithRange: NSMakeRange(r3.location+r3.length, r4.location-(r3.location+r3.length))];
                            if (author) {
                                xauthor = [xauthor stringByReplacingOccurrencesOfString: @"&amp;" withString:@"&"];
                                xauthor = [xauthor stringByReplacingOccurrencesOfString: @"&lt;" withString:@"<"];
                                xauthor = [xauthor stringByReplacingOccurrencesOfString: @"&gt;" withString:@">"];                                         
                                *author = xauthor;
                            }
                        }
                    }
                    r3 = [xmlString rangeOfString:@"<description>" options:0 range: NSMakeRange(r.location+r.length, r2.location-(r.location+r.length))];
                    if (r3.length) {
                        found = YES;
                        NSRange r4 = [xmlString rangeOfString:@"</description>" options:0 range: NSMakeRange(r3.location+r3.length, r2.location-(r3.location+r3.length))];
                        if (r4.length) {
                            NSString *xdescript = [xmlString substringWithRange: NSMakeRange(r3.location+r3.length, r4.location-(r3.location+r3.length))];
                            if (xdescript) {
                                // descript should already have &,<,> encoded in HTML, and no other tags but <br/>
                                *description = xdescript;
                            }
                        }
                    }
                }
                free(buf);
            } else
                ;//printf("Skipping chunk '%c%c%c%c'\n", z[0],z[1],z[2],z[3]);
            pos += chunkSize;
            fseek (fp, pos, SEEK_SET);
        }
        break;
    }
    fclose(fp);
    return found;

}

NSData *imageDataFromBlorb(NSString *blorbFile) {
    const char *filename = [blorbFile fileSystemRepresentation];
    NSData *data = nil;
    FILE *fp;
    if ((fp = os_path_open(filename, "rb")) == NULL)
        return nil;
    unsigned char zblorbbuf[16];
    unsigned char *z;
    unsigned int fileSize=0, chunkSize=0, numEntries=0, pictOffset=0, pos,i;
    while (1) {
        if (fread(zblorbbuf, 1, 12, fp)!=12)
            break;
        z = zblorbbuf;
        if (*z++ != 'F') break;
        if (*z++ != 'O') break;
        if (*z++ != 'R') break;
        if (*z++ != 'M') break;
        fileSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
        z += 4;
        if (*z++ != 'I') break;
        if (*z++ != 'F') break;
        if (*z++ != 'R') break;
        if (*z   != 'S') break;
        pos = 12;
        while (pos < fileSize) {
            if (fread(zblorbbuf, 1, 8, fp) != 8)
                break;
            pos += 8;
            z = zblorbbuf+4;
            chunkSize = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
            if (chunkSize % 2 == 1)
                chunkSize++;
            z = zblorbbuf;
            if (z[0]=='R' && z[1]=='I' && z[2]=='d' && z[3]=='x') {
                if (fread(zblorbbuf, 1, 4, fp) != 4)
                    break;
                pos += 4;
                numEntries = (z[0]<<24)|(z[1]<<16)|(z[2]<<8)|z[3];
                printf("Found Ridx chunk of size %d with %d entries at pos %d\n", chunkSize, numEntries, pos);
                for (i=0; i < numEntries; ++i) {		
                    if (fread(zblorbbuf, 1, 12, fp) != 12)
                        break;
                    if (z[0]=='P' && z[1]=='i' && z[2]=='c' && z[3]=='t') {
                        pictOffset = (z[8]<<24)|(z[9]<<16)|(z[10]<<8)|z[11];
                        break;
                    }
                    if (pictOffset)
                        break;
                }
                if (pictOffset) {
                    pos = pictOffset;
                    fseek(fp, pos, SEEK_SET);
                    continue;
                }
            } else if (z[0]=='J' && z[1]=='P' && z[2]=='E' && z[3]=='G'
                       || z[0]=='P' && z[1]=='N' && z[2]=='G' && z[3]==' ') {
                printf ("Found pict resource\n");
                char *buf = malloc(chunkSize);
                int sizePerRead = 0x2000;
                int size=0,  sizeLeft = chunkSize;
                while (sizeLeft > 0) {
                    if (sizePerRead > sizeLeft)
                        sizePerRead = sizeLeft;
                    if (fread(buf + size, 1, sizePerRead, fp) != sizePerRead)
                        break;
                    size += sizePerRead;
                    sizeLeft -= sizePerRead;
                }
                if (sizeLeft == 0)
                    data = [[NSData alloc] initWithBytesNoCopy: buf length:chunkSize freeWhenDone:YES];
                else
                    free(buf);
                break;
            } else
                ; //printf("Skipping chunk '%c%c%c%c'\n", z[0],z[1],z[2],z[3]);
            pos += chunkSize;
            fseek (fp, pos, SEEK_SET);
        }
        break;
    }
    fclose(fp);
    return data;
}





