//
//  ViewController.m
//  chillout
//
//  Created by Meg on 4/27/18.
//  Copyright © 2018 meggrasse. All rights reserved.
//

#import "ViewController.h"

#import <MediaPlayer/MediaPlayer.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // request authorization to access the user's media library
    [MPMediaLibrary requestAuthorization:^(MPMediaLibraryAuthorizationStatus status) {
        if (status != MPMediaLibraryAuthorizationStatusAuthorized) {
            // if we don't get access, abort
            NSLog(@"Need authorization");
            exit(0);
        }
    }];
    
    //  uncomment to test each method
//    [self addCurrentTrackToPlaylistTest];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addCurrentTrackToPlaylist:(MPMediaPlaylist *)playlist {
    NSString *currentTrackProductID = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.playbackStoreID;
    [playlist addItemWithProductID:currentTrackProductID completionHandler:nil];
}

#pragma mark - Tests
- (void)addCurrentTrackToPlaylistTest {
    
    MPMediaPlaylistCreationMetadata *playlistData = [[MPMediaPlaylistCreationMetadata alloc] initWithName:@"addCurrentTrackToPlaylistTest"];
    [MPMediaLibrary.defaultMediaLibrary getPlaylistWithUUID: [NSUUID UUID]
                       creationMetadata:playlistData
                      completionHandler:^(MPMediaPlaylist *playlist, NSError *error) {
                          [self addCurrentTrackToPlaylist:playlist];
                      }];
}

@end
