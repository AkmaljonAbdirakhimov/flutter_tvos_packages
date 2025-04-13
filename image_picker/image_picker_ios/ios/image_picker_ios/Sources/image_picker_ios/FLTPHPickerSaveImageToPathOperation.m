// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Flutter/Flutter.h>

#if !TARGET_OS_TV
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

#import "FLTPHPickerSaveImageToPathOperation.h"

#import <os/log.h>

#if !TARGET_OS_TV
API_AVAILABLE(ios(14))
@interface FLTPHPickerSaveImageToPathOperation ()

@property(strong, nonatomic) PHPickerResult *result;
@property(strong, nonatomic) NSNumber *maxHeight;
@property(strong, nonatomic) NSNumber *maxWidth;
@property(strong, nonatomic) NSNumber *desiredImageQuality;
@property(assign, nonatomic) BOOL requestFullMetadata;

@end
#endif

@implementation FLTPHPickerSaveImageToPathOperation {
  BOOL executing;
  BOOL finished;
  FLTGetSavedPath getSavedPath;
}

#if !TARGET_OS_TV
- (instancetype)initWithResult:(PHPickerResult *)result
                     maxHeight:(NSNumber *)maxHeight
                      maxWidth:(NSNumber *)maxWidth
           desiredImageQuality:(NSNumber *)desiredImageQuality
                  fullMetadata:(BOOL)fullMetadata
                savedPathBlock:(FLTGetSavedPath)savedPathBlock API_AVAILABLE(ios(14)) {
  if (self = [super init]) {
    if (result) {
      self.result = result;
      self.maxHeight = maxHeight;
      self.maxWidth = maxWidth;
      self.desiredImageQuality = desiredImageQuality;
      self.requestFullMetadata = fullMetadata;
      getSavedPath = savedPathBlock;
      executing = NO;
      finished = NO;
    } else {
      return nil;
    }
    return self;
  } else {
    return nil;
  }
}
#else
- (instancetype)initWithResult:(id)result
                     maxHeight:(NSNumber *)maxHeight
                      maxWidth:(NSNumber *)maxWidth
           desiredImageQuality:(NSNumber *)desiredImageQuality
                  fullMetadata:(BOOL)fullMetadata
                savedPathBlock:(FLTGetSavedPath)savedPathBlock {
  // This implementation is a stub for tvOS
  if (self = [super init]) {
    getSavedPath = savedPathBlock;
    executing = NO;
    finished = NO;
    return self;
  } else {
    return nil;
  }
}
#endif

- (BOOL)isConcurrent {
  return YES;
}

- (BOOL)isExecuting {
  return executing;
}

- (BOOL)isFinished {
  return finished;
}

- (void)setFinished:(BOOL)isFinished {
  [self willChangeValueForKey:@"isFinished"];
  self->finished = isFinished;
  [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)isExecuting {
  [self willChangeValueForKey:@"isExecuting"];
  self->executing = isExecuting;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperationWithPath:(NSString *)savedPath error:(FlutterError *)error {
  getSavedPath(savedPath, error);
  [self setExecuting:NO];
  [self setFinished:YES];
}

- (void)start {
  if ([self isCancelled]) {
    [self setFinished:YES];
    return;
  }

#if TARGET_OS_TV
  // On tvOS, just complete the operation with an error since PHPickerResult is not supported
  FlutterError *flutterError = [FlutterError errorWithCode:@"photo_picker_not_available"
                                                    message:@"PHPicker is not available on tvOS"
                                                    details:nil];
  [self completeOperationWithPath:nil error:flutterError];
  return;
#else
  if (@available(iOS 14, *)) {
    [self setExecuting:YES];

    // This supports uniform types that conform to UTTypeImage.
    // This includes UTTypeHEIC, UTTypeHEIF, UTTypeLivePhoto, UTTypeICO, UTTypeICNS, UTTypePNG
    // UTTypeGIF, UTTypeJPEG, UTTypeWebP, UTTypeTIFF, UTTypeBMP, UTTypeSVG, UTTypeRAWImage
    if ([self.result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
      [self.result.itemProvider
          loadDataRepresentationForTypeIdentifier:UTTypeImage.identifier
                                completionHandler:^(NSData *_Nullable data,
                                                    NSError *_Nullable error) {
                                  if (data != nil) {
                                    [self processImage:data];
                                  } else {
                                    FlutterError *flutterError =
                                        [FlutterError errorWithCode:@"invalid_image"
                                                            message:error.localizedDescription
                                                            details:error.domain];
                                    [self completeOperationWithPath:nil error:flutterError];
                                  }
                                }];
    } else if ([self.result.itemProvider
                   // This supports uniform types that conform to UTTypeMovie.
                   // This includes kUTTypeVideo, kUTTypeMPEG4, public.3gpp, kUTTypeMPEG,
                   // public.3gpp2, public.avi, kUTTypeQuickTimeMovie.
                   hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
      [self processVideo];
    } else {
      FlutterError *flutterError = [FlutterError errorWithCode:@"invalid_source"
                                                       message:@"Invalid media source."
                                                       details:nil];
      [self completeOperationWithPath:nil error:flutterError];
    }
  } else {
    [self setFinished:YES];
  }
#endif
}

#if !TARGET_OS_TV
/// Processes the image.
- (void)processImage:(NSData *)pickerImageData API_AVAILABLE(ios(14)) {
  UIImage *localImage = [[UIImage alloc] initWithData:pickerImageData];

  if (self.maxWidth != nil || self.maxHeight != nil) {
    localImage = [FLTImagePickerImageUtil scaledImage:localImage
                                             maxWidth:self.maxWidth
                                            maxHeight:self.maxHeight
                                  isMetadataAvailable:YES];
  }
  // maxWidth and maxHeight are used only for GIF images.
  NSString *savedPath =
      [FLTImagePickerPhotoAssetUtil saveImageWithOriginalImageData:pickerImageData
                                                             image:localImage
                                                          maxWidth:self.maxWidth
                                                         maxHeight:self.maxHeight
                                                      imageQuality:self.desiredImageQuality];
  [self completeOperationWithPath:savedPath error:nil];
}

/// Processes the video.
- (void)processVideo API_AVAILABLE(ios(14)) {
  NSString *typeIdentifier = self.result.itemProvider.registeredTypeIdentifiers.firstObject;
  [self.result.itemProvider
      loadFileRepresentationForTypeIdentifier:typeIdentifier
                            completionHandler:^(NSURL *_Nullable videoURL,
                                                NSError *_Nullable error) {
                              if (error != nil) {
                                FlutterError *flutterError =
                                    [FlutterError errorWithCode:@"invalid_image"
                                                        message:error.localizedDescription
                                                        details:error.domain];
                                [self completeOperationWithPath:nil error:flutterError];
                                return;
                              }

                              NSURL *destination =
                                  [FLTImagePickerPhotoAssetUtil saveVideoFromURL:videoURL];
                              if (destination == nil) {
                                [self
                                    completeOperationWithPath:nil
                                                        error:[FlutterError
                                                                  errorWithCode:
                                                                      @"flutter_image_picker_copy_"
                                                                      @"video_error"
                                                                        message:@"Could not cache "
                                                                                @"the video file."
                                                                        details:nil]];
                                return;
                              }

                              [self completeOperationWithPath:[destination path] error:nil];
                            }];
}
#endif

@end
