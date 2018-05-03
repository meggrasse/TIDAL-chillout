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

MPMediaPlaylist *chilloutPlaylist;
UILabel *nowPlaying;
double startTrackAlpha;
bool addedTrack = NO;

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
    
    // playlist picker
    UIPickerView *playlistPicker = [UIPickerView new];
    playlistPicker.delegate = self;
    playlistPicker.dataSource = self;
    
    // make "start listening" button
    UIButton *listen = [UIButton buttonWithType:UIButtonTypeCustom];
    
    // not autolayout
    listen.frame = CGRectMake(0, 0, 50, 50);
    listen.center = CGPointMake(self.view.center.x, self.view.center.y + 20);
    
    // button title label
    [listen setTitle:@"▶︎" forState:UIControlStateNormal];
    listen.titleLabel.font = [UIFont systemFontOfSize:25];
    [listen setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    listen.titleLabel.textAlignment = NSTextAlignmentCenter;
    listen.backgroundColor = UIColor.clearColor;
    
    // black border
    listen.layer.masksToBounds = YES;
    listen.layer.cornerRadius = listen.frame.size.width / 2;
    listen.layer.borderWidth = 1;
    listen.layer.borderColor = UIColor.blackColor.CGColor;
    
    // add to the view
    [self.view addSubview:listen];
    
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

    [self startListeningForMuse];
    [self startListeningForTrack];
    
    //  uncomment to test each method
//    [self addCurrentTrackToPlaylistTest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startListeningForTrack {
    // Setup notifications for track changing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(trackChanged)
                                                 name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
    
    [MPMusicPlayerController.systemMusicPlayer beginGeneratingPlaybackNotifications];
}

- (void)trackChanged {
    // hack so we know to update the startTrackAlpha
    startTrackAlpha = -999;
    addedTrack = NO;
    
    // change the now playing label
    NSString *nowPlayingTitle = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.title;
    NSString *nowPlayingArtist = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.artist;
    nowPlaying.text = [nowPlayingTitle stringByAppendingString:@"\n"];
    nowPlaying.text = [nowPlaying.text stringByAppendingString:nowPlayingArtist];
}

- (void)addCurrentTrackToPlaylist:(MPMediaPlaylist *)playlist {
    NSString *currentTrackProductID = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem.playbackStoreID;
    [playlist addItemWithProductID:currentTrackProductID completionHandler:nil];
}

- (void)startListeningForMuse {
    [[IXNMuseManagerIos sharedManager] setMuseListener:self];
    [[IXNMuseManagerIos sharedManager] startListening];
}

- (void)setupMuse:(IXNMuse *)currentMuse {
    // starting getting alpha data
    [currentMuse registerDataListener:self
                                 type:IXNMuseDataPacketTypeAlphaAbsolute];
    
    // runs handling connection and such
    [currentMuse runAsynchronously];
}

#pragma mark - IXNMuseListener

- (void)museListChanged {
    // TODO: make a visual connected label
    NSLog(@"CONNECTED");
    
    // gets the current muse - the first in the list of surrounding muses
    IXNMuse *currentMuse = [[IXNMuseManagerIos sharedManager] getMuses][0];
    [self setupMuse:currentMuse];
}

#pragma mark - IXNMuseDataListener

- (void)receiveMuseDataPacket:(IXNMuseDataPacket *)packet
                         muse:(IXNMuse *)muse {
    NSLog(@"Recieved packet");
    if (addedTrack) return;
    if (packet.packetType == IXNMuseDataPacketTypeAlphaAbsolute) {
        double currentAlpha = ([packet.values[IXNEegEEG1] doubleValue] + [packet.values[IXNEegEEG2] doubleValue] + [packet.values[IXNEegEEG3] doubleValue] +[packet.values[IXNEegEEG4] doubleValue]) / 4;
        NSLog(@"Current alpha: %f", currentAlpha);
        // if the track just started, set startTrackAlpha and get outta here
        if (startTrackAlpha == -999) {
            startTrackAlpha  = currentAlpha;
        // otherwise if they are chilling and we haven't added the track yet
        } else if (currentAlpha < (.75 * startTrackAlpha)) {
            [self addCurrentTrackToPlaylist:chilloutPlaylist];
        }
    }
}

- (void)receiveMuseArtifactPacket:(nonnull IXNMuseArtifactPacket *)packet
                             muse:(nullable IXNMuse *)muse {
    // Not needed
}

//- (void)findOrAddChilloutPlaylist:(void (^)(MPMediaPlaylist *playlist))completionHandler {
- (void)findOrAddChilloutPlaylist {
    MPMediaPlaylistCreationMetadata *playlistData = [[MPMediaPlaylistCreationMetadata alloc] initWithName:@"chillout"];
    NSURL *pathURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"playlist1.txt"]];
    
    NSString *results = [NSString stringWithContentsOfFile:pathURL.path encoding:NSUTF8StringEncoding error:nil];
    
    NSUUID *uuid;
    if (results) {
        uuid = [[NSUUID alloc] initWithUUIDString:results];
    } else {
        uuid = [NSUUID UUID];
        // Write the uuid to the file
        [self writeUUID:uuid toPath:pathURL.path];
    }
    
    NSLog(@"Results: %@", results);

    [MPMediaLibrary.defaultMediaLibrary getPlaylistWithUUID:uuid creationMetadata:playlistData completionHandler:^(MPMediaPlaylist *playlist, NSError *error) {
        // There is a potential bug here in setting chilloutPlaylist in the block - there's a possiblity we access it before it's been set
        chilloutPlaylist = playlist;
        NSLog(@"Chillout playlist: %@", chilloutPlaylist.name);
//        completionHandler(playlist);
    }];
    
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
