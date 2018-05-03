//
//  ViewController.m
//  chillout
//
//  Created by Meg on 4/27/18.
//  Copyright © 2018 meggrasse. All rights reserved.
//

#import "ViewController.h"

#import <MediaPlayer/MediaPlayer.h>

@implementation ViewController

UIButton *listenButton;
UILabel *nowPlaying;
NSUUID *chilloutPlaylistUUID;
double startTrackAlpha = -999;
bool addedTrack = NO;
bool isListening = NO;

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
    
    // load UI
    
    // make "chillout" label
    UILabel *title = [[UILabel alloc] init];
    title.text = @"chillout";
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:36 weight:UIFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    // add to the view
    [self.view addSubview:title];
    
    // make listen button
    listenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [listenButton addTarget:self action:@selector(controlButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // not autolayout
    listenButton.frame = CGRectMake(0, 0, 50, 50);
    listenButton.center = CGPointMake(self.view.center.x, self.view.center.y + 20);
    
    // button title label
    [listenButton setTitle:@"▶︎" forState:UIControlStateNormal];
    listenButton.titleLabel.font = [UIFont systemFontOfSize:25];
    [listenButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    listenButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    listenButton.backgroundColor = UIColor.clearColor;
    
    // black border
    listenButton.layer.masksToBounds = YES;
    listenButton.layer.cornerRadius = listenButton.frame.size.width / 2;
    listenButton.layer.borderWidth = 1;
    listenButton.layer.borderColor = UIColor.blackColor.CGColor;
    
    // add to the view
    [self.view addSubview:listenButton];
    
    // make "nowplaying" label
    nowPlaying = [[UILabel alloc] init];
    nowPlaying.textAlignment = NSTextAlignmentCenter;
    nowPlaying.numberOfLines = 2;
    nowPlaying.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    nowPlaying.textColor = [UIColor grayColor];
    nowPlaying.translatesAutoresizingMaskIntoConstraints = NO;
    // add to the view
    [self.view addSubview:nowPlaying];
    
    // use autolayout for position of labels
    NSArray<NSLayoutConstraint *> *constraints = @[
                                                   [title.leftAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leftAnchor],
                                                   [title.rightAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.rightAnchor],
                                                   [title.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-100],
                                                   
                                                   [nowPlaying.leftAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leftAnchor],
                                                   [nowPlaying.rightAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.rightAnchor],
                                                   [nowPlaying.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:130],
                                                   ];
    
    [NSLayoutConstraint activateConstraints:constraints];
    
    [self findOrAddChilloutPlaylist];
}

- (void)controlButtonTapped:(id)sender {
    isListening ? [self stopListening] : [self startListening];

    // update state
    isListening = !isListening;
}

- (void)startListening {
    NSLog(@"listening...");
    //if no current muses then init, otherwise setup for this muse
    if (![[[IXNMuseManagerIos sharedManager] getMuses] count]) {
        [self initListeningForMuse];
    } else {
        IXNMuse *currentMuse = [[IXNMuseManagerIos sharedManager] getMuses][0];
        [self startCapturingDataFromMuse:currentMuse];
    }
    
    [self startListeningForTrack];
    
    // start playing current track
    // sometimes throws "prepareToPlay without a queue" error but still seems to work
    [[MPMusicPlayerController systemMusicPlayer] prepareToPlayWithCompletionHandler:^(NSError *error) {
        [[MPMusicPlayerController systemMusicPlayer] play];
    }];
    
    [self updateUIForCurrentTrack];
}

- (void)stopListening {
    NSLog(@"no longer listening...");
    // stop getting data packets from the muse but don't disconnect
    IXNMuse *currentMuse = [[IXNMuseManagerIos sharedManager] getMuses][0];
    [currentMuse unregisterAllListeners];
    
    // end notifications for current track
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
    [MPMusicPlayerController.systemMusicPlayer endGeneratingPlaybackNotifications];
    
    // stop playing current track
    [[MPMusicPlayerController systemMusicPlayer] stop];
    
    // clear out current startTrackAlpha
    startTrackAlpha = -999;
    
    // update UI
    [listenButton setTitle:@"▶︎" forState:UIControlStateNormal];
    nowPlaying.text = @"";
}

- (void)findOrAddChilloutPlaylist {
    NSURL *pathURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"playlist1.txt"]];
    NSString *results = [NSString stringWithContentsOfFile:pathURL.path encoding:NSUTF8StringEncoding error:nil];
    
    if (results) {
        chilloutPlaylistUUID = [[NSUUID alloc] initWithUUIDString:results];
    } else {
        chilloutPlaylistUUID = [NSUUID UUID];
        // Write the uuid to the file
        [self writeUUID:chilloutPlaylistUUID toPath:pathURL.path];
    }
    
    NSLog(@"Results: %@", results);
}

- (void)writeUUID:(NSUUID *)uuid toPath:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        NSLog(@"Creating file.");
    }
    
    NSLog(@"is writable at path: %d", [[NSFileManager defaultManager] isWritableFileAtPath:path]);
    bool didWrite = [uuid.UUIDString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"wrote to file: %d", didWrite);
}

#pragma mark - Track

- (void)startListeningForTrack {
    // Setup notifications for track changing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(trackChanged)
                                                 name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
    
    [MPMusicPlayerController.systemMusicPlayer beginGeneratingPlaybackNotifications];
}

- (void)trackChanged {
    NSLog(@"track changed");
    // hack so we know to update the startTrackAlpha
    startTrackAlpha = -999;
    addedTrack = NO;
    
    [self updateUIForCurrentTrack];
}

- (void)updateUIForCurrentTrack {
    // change the now playing label
    NSString *nowPlayingTitle = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.title;
    NSString *nowPlayingArtist = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.artist;
    nowPlaying.text = [nowPlayingTitle stringByAppendingString:@"\n"];
    nowPlaying.text = [nowPlaying.text stringByAppendingString:nowPlayingArtist];
    
    // take away add to library message
    [listenButton setTitle:@"￭" forState:UIControlStateNormal];
}

#pragma mark - Muse

- (void)initListeningForMuse {
    [[IXNMuseManagerIos sharedManager] setMuseListener:self];
    [[IXNMuseManagerIos sharedManager] startListening];
}

- (void)startCapturingDataFromMuse:(IXNMuse *)currentMuse {
    // starting getting alpha data
    [currentMuse registerDataListener:self
                                 type:IXNMuseDataPacketTypeAlphaAbsolute];
    
    // runs handling connection and such
    [currentMuse runAsynchronously];
}

#pragma mark - IXNMuseListener

- (void)museListChanged {
    NSLog(@"CONNECTED");
    
    // gets the current muse - the first in the list of surrounding muses
    IXNMuse *currentMuse = [[IXNMuseManagerIos sharedManager] getMuses][0];
    [self startCapturingDataFromMuse:currentMuse];
}

#pragma mark - IXNMuseDataListener

- (void)receiveMuseDataPacket:(IXNMuseDataPacket *)packet
                         muse:(IXNMuse *)muse {
    NSLog(@"Recieved packet");
    if (packet.packetType == IXNMuseDataPacketTypeAlphaAbsolute) {
        double currentAlpha = ([packet.values[IXNEegEEG1] doubleValue] + [packet.values[IXNEegEEG2] doubleValue] + [packet.values[IXNEegEEG3] doubleValue] +[packet.values[IXNEegEEG4] doubleValue]) / 4;
        NSLog(@"Current alpha: %f", currentAlpha);
        // if the track just started, set startTrackAlpha and get outta here
        if (startTrackAlpha == -999 && currentAlpha > 0) {
            startTrackAlpha = currentAlpha;
            NSLog(@"Start alpha: %f", startTrackAlpha);
        // otherwise if they are chilling and we haven't added the track yet
        // heuristic
        } else if (currentAlpha > (1.25 * startTrackAlpha) && (startTrackAlpha != -999)) {
            MPMediaPlaylistCreationMetadata *playlistData = [[MPMediaPlaylistCreationMetadata alloc] initWithName:@"chillout"];
            [MPMediaLibrary.defaultMediaLibrary getPlaylistWithUUID:chilloutPlaylistUUID creationMetadata:playlistData completionHandler:^(MPMediaPlaylist *playlist, NSError *error) {
                // if you haven't added the track, add it to the playlist
                if (!addedTrack) {
                    NSString *currentTrackProductID = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.playbackStoreID;
                    [playlist addItemWithProductID:currentTrackProductID completionHandler:nil];
                    addedTrack = YES;
                    [listenButton setTitle:@"✔️" forState:UIControlStateNormal];
                }
            }];
        }
    }
}

- (void)receiveMuseArtifactPacket:(nonnull IXNMuseArtifactPacket *)packet
                             muse:(nullable IXNMuse *)muse {
    // Not needed
}

@end
