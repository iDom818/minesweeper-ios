//
//  ViewController.m
//  Minesweeper
//
//  Created by Daniel James on 6/17/14.
//  Copyright (c) 2014 developersBliss. All rights reserved.
//

#import "ViewController.h"
#import "Grid.h"
#import <GameKit/GameKit.h>
#import "SettingsManager.h"
#import "Minesweeper-Swift.h"

@interface ViewController () {
    Grid *_grid;
    
    MinesweeperGame *_game;
    BOOL _alreadyPaused;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Background2"]];
    
    self.timerLabelBackground.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Background"]];
    self.bombsLabelBackground.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Background"]];
    
    self.timerLabelBackground.layer.cornerRadius = 3;
    self.bombsLabelBackground.layer.cornerRadius = 3;
        
    //Register for application states
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(applicationDidBecomeActive:)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(applicationWillResignActive:)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(promptNewGame)
                                                name:@"MinesweeperDifficultyChanged"
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(newGame)
                                                name:@"NewGame"
                                              object:nil];
    
    [self.hintButton setEnabled:FALSE];
    
    if (@available(iOS 13.4, *)) {
        [self.smileyButton addInteraction:[[UIPointerInteraction alloc] init]];
    }
}

- (IBAction)smileButtonPressed:(id)sender {
    [SoundManager.sharedInstance playSoundEffect:SoundEffectSelect];
    [self promptNewGame];
}

- (IBAction)hintButtonPressed:(id)sender {
    if (_grid && _game) {
        if (_game.state == GameStatePlaying) {
            [_grid hint];
        } else if (_game.state == GameStateFinished) {
            [_grid undo];
        }
    }
}

- (void) dealloc {
    //Resign form NSNotifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"MinesweeperDifficultyChanged" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NewGame" object:nil];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_grid) {
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(setInsets)    name:UIDeviceOrientationDidChangeNotification  object:nil];
        [self newGame];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    _game.isPaused = true;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _game.isPaused = false;
}

- (void) applicationDidBecomeActive: (id) sender {
    if (!_alreadyPaused) {
        _game.isPaused = NO;
    }
}

- (void) applicationWillResignActive: (id) sender {
    NSLog(@"Application will resign active.");
    if (_game.isPaused) {
        _alreadyPaused = YES;
    } else {
        _alreadyPaused = NO;
        _game.isPaused = YES;
    }
}

- (void) viewDidLayoutSubviews {
    [self setInsets];
    [self.scrollView setNeedsDisplay];
    [self.scrollView setNeedsLayout];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return _grid;
}

- (void) scrollViewDidZoom:(UIScrollView *)scrollView {
    [self setInsets];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self setInsets];
}

- (void) scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    scale *= [[UIScreen mainScreen] scale];
    scrollView.contentScaleFactor = scale;
    _grid.contentScaleFactor = scale;
    [self setInsets];
}

- (void) newGame {
    if (_game != nil) {
        _game.state = GameStateFinished;
        _game = nil;
    }
    
    DifficultyLevel difficultyLevel = [[SettingsManager sharedInstance] getCurrentDifficultyLevel];
    NSInteger width = [[SettingsManager sharedInstance] getWidth];
    NSInteger height = [[SettingsManager sharedInstance] getHeight];
    NSInteger mines = [[SettingsManager sharedInstance] getMines];
    BOOL luck = [[SettingsManager sharedInstance] getLuckEnabled];
    BOOL emptyFirstTap = [[SettingsManager sharedInstance] getEmptyFirstTapEnabled];
    BOOL randomHints = [[SettingsManager sharedInstance] getRandomHintsEnabled];
    
    _game = [[MinesweeperGame alloc] initWithDifficulty:difficultyLevel withWidth:width withHeight:height withMines:mines withLuck:luck withEmptyFirstTap:emptyFirstTap withRandomHints:randomHints];
    
    if (_grid) {
        [_grid removeFromSuperview];
    }
    
    _grid = [[Grid alloc] initWithGame:_game withSize:self.traitCollection.horizontalSizeClass];
    _grid.title = self;
    _grid.scrollView = self.scrollView;
    [self resetWithBombs:(int)_game.mines];
    _game.timerDelegate = self;
    
    self.scrollView.contentSize = _grid.frame.size;
    [self setInsets];
    [self.scrollView addSubview:_grid];
}

- (void) setInsets {
    CGSize size = self.scrollView.frame.size;
    CGFloat offsetTop = self.scrollView.safeAreaInsets.top;
    CGFloat offsetBottom = self.scrollView.safeAreaInsets.bottom;
    size.height = size.height - offsetTop - offsetBottom;
    
    float paddingX, paddingY;
    if (_grid.frame.size.width > size.width) {
        paddingX = 12;
    } else {
        paddingX = (size.width - _grid.frame.size.width)/2.0;
    }
    if (_grid.frame.size.height > size.height) {
        paddingY = 12;
    } else {
        paddingY = (size.height - _grid.frame.size.height)/2.0;
    }

    self.scrollView.contentInset = UIEdgeInsetsMake(paddingY, paddingX, paddingY, paddingX);
}

- (void) promptNewGame {
    if (_game.state == GameStatePlaying) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"New Game?"
                                     message:@"Would you like to start a new game and quit the current one?"
                                     preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* yesButton = [UIAlertAction
                                    actionWithTitle:@"Yes"
                                    style:UIAlertActionStyleDestructive
                                    handler:^(UIAlertAction * action) {
            self->_game.isPaused = false;
            [self newGame];
                                    }];

        UIAlertAction* noButton = [UIAlertAction
                                   actionWithTitle:@"No"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
            self->_game.isPaused = false;
                                   }];

        [alert addAction:noButton];
        [alert addAction:yesButton];
        
        if (self.presentedViewController) {
            [[self presentedViewController] presentViewController:alert animated:YES completion:nil];
        } else {
            [self presentViewController:alert animated:YES completion:nil];
        }
        
        _game.isPaused = true;
    } else {
        [self newGame];
    }
}

- (void) resetWithBombs:(int)b {
    self.time = 0;
    self.bombs = b;
    self.smileyState = SmileyStateNormal;
}

- (void) setBombs:(int)bombs {
    _bombs = bombs;
    
    if (self.bombs < -9) {
        self.bombsLabel.text = [NSString stringWithFormat:@"-%d", -self.bombs];
    } else if (self.bombs < 0) {
        self.bombsLabel.text = [NSString stringWithFormat:@" -%d", -self.bombs];
    } else if (self.bombs < 10) {
        self.bombsLabel.text = [NSString stringWithFormat:@"  %d", self.bombs];
    } else if (self.bombs < 100) {
        self.bombsLabel.text = [NSString stringWithFormat:@" %d", self.bombs];
    } else {
        self.bombsLabel.text = [NSString stringWithFormat:@"%d", self.bombs];
    }
}

- (void) timeChangedWithTime:(NSInteger)time {
    [self setTime:time];
}

- (void) setTime:(NSInteger)time {
    if (time > 999) {
        time = 999;
    }
    
    if (time <= 1 && _game.state != GameStateFirstMove) {
        [self.hintButton setEnabled:TRUE];
    }
    
    if (time < 10) {
        self.timerLabel.text = [NSString stringWithFormat:@"  %ld", (long)time];
    } else if (time < 100) {
        self.timerLabel.text = [NSString stringWithFormat:@" %ld", (long)time];
    } else if (time <= 999) {
        self.timerLabel.text = [NSString stringWithFormat:@"%ld", (long)time];
    }
}

- (void) setSmileyState:(SmileyState)smileyState {
    _smileyState = smileyState;
    
    switch (self.smileyState) {
        case SmileyStateAction:
            self.smileyButton.titleLabel.text = @"😮";
            break;
        case SmileyStateLose:
            self.smileyButton.titleLabel.text = @"😵";
            self.hintButton.image = [UIImage systemImageNamed:@"arrow.uturn.left"];
            break;
        case SmileyStateWin:
            self.smileyButton.titleLabel.text = @"😎";
            [self.hintButton setEnabled:NO];
            break;
            
        case SmileyStateNormal:
        default:
            self.smileyButton.titleLabel.text = @"😀";
            self.hintButton.image = [UIImage systemImageNamed:@"lightbulb"];
    }
}

@end
