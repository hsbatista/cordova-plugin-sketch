//
//  TouchViewController.m
//  TouchTracker
//
//  Created by Shane on 22/01/12.
//  Copyright (c) 2012 BlinkMobile Interactive. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "BGTouchDrawViewController.h"
#import "BGTouchDrawView.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@implementation BGTouchDrawViewController
{
    BOOL coloursShown;
    BOOL strokeWidthsShown;
    CGRect buttonsAnimationStartFrame;
    CGRect strokeButtonsAnimationStartFrame;
}

- (id) init
{
    // Call the superclass's designated initialiser
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _shouldResizeContentOnRotate = NO;
         _shouldCenterDrawing = NO;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _shouldResizeContentOnRotate = NO;
        _shouldCenterDrawing = NO;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self viewWillAppear:NO];
    self.saved = NO;
    [_canvasLayer setNeedsDisplay];
    [_backgroundLayer setNeedsDisplay];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    _touching = NO;
    self.colour = [UIColor blackColor];
    
    self.strokeWidth = 1;
    if(self.setStrokeWidth > 0) {
        self.strokeWidth = self.setStrokeWidth;
    }

    //disable gesture recognizer
    for (UIGestureRecognizer *recognizer in
         self.navigationController.view.gestureRecognizers) {
        [recognizer setEnabled:NO];
    }

    float xRatio = 0, yRatio = 0, dominatingRatio = 0;
    float newHeight, newWidth;
    CGRect frame = self.view.bounds;
    if (!self.shouldResizeContentOnRotate) {
        if (frame.size.width != self.contentSize.width ||
            frame.size.height != self.contentSize.height) {
            xRatio = frame.size.width / self.contentSize.width;
            yRatio = frame.size.height / self.contentSize.height;

            dominatingRatio = MIN(xRatio, yRatio);

            newWidth = dominatingRatio * self.contentSize.width;
            newHeight = dominatingRatio * self.contentSize.height;

            frame.size = CGSizeMake(newWidth, newHeight);
        }
    } else {
        self.contentSize = frame.size;
    }

    if (self.shouldCenterDrawing && (frame.size.width < self.view.frame.size.width ||
                                     frame.size.height < self.view.frame.size.height)) {
        // Center the drawing along the non-dominated axis
        if (dominatingRatio == xRatio) {
            frame.origin.y = (self.view.frame.size.height - frame.size.height) / 2.0;
        } else {
            frame.origin.x = (self.view.frame.size.width - frame.size.width) / 2.0;
        }
    }

    self.view = self.tdv = [[BGTouchDrawView alloc]initWithFrame:frame];
    self.backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(frame.origin.x, frame.origin.y,
                                                                        frame.size.width, frame.size.height)];
    self.backgroundView.image = self.backgroundImage;

    [self.tdv setBackgroundColor:[UIColor grayColor]];
    [self.tdv addSubview:self.backgroundView];

    // Drawing layer
    self.canvasLayer = [CALayer layer];
    [self.canvasLayer setBounds:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    [self.canvasLayer setPosition:CGPointMake(frame.origin.x + frame.size.width / 2.0,
                                              frame.origin.y + frame.size.height / 2.0)];
    [self.canvasLayer setDelegate:self];

    // Set up storage layer
    self.backgroundLayer = [CALayer layer];
    [self.backgroundLayer setBounds:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    [self.backgroundLayer setPosition:CGPointMake(frame.origin.x + frame.size.width / 2.0,
                                                  frame.origin.y + frame.size.height / 2.0)];
    [self.backgroundLayer setDelegate:self];

    [[self.tdv layer] addSublayer:_backgroundLayer];
    [[self.tdv layer] addSublayer:_canvasLayer];
}

- (void)setUpToolbar
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
    
    self.btColour = [[UIBarButtonItem alloc] initWithTitle:@"Schriftfarbe"
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(toggleColour:event:)];
    
    [self setColourButtonColour];
    
    if(self.showColorSelect) {
        NSLog(@"showColorSelect");
        [items addObject:self.btColour];
        [items addObject:flexItem];
    } else {
        NSLog(@"showColorSelect NOT");
    }
    
    self.btStroke = [[UIBarButtonItem alloc] initWithTitle:@"Strichstärke"
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(toggleStrokeWidth:event:)];
                                                    
    if(self.showStrokeWidthSelect) {
        NSLog(@"showStrokeWidthSelect");
        [items addObject:self.btStroke];
        [items addObject:flexItem];
    } else {
        NSLog(@"showStrokeWidthSelect NOT");
    }
    
    UIBarButtonItem *btRecycle = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                               target:self
                                                                               action:@selector(clearAll)];

    [items addObject:btRecycle];
    [items addObject:flexItem];

    UIBarButtonItem *btSave = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                            target:self
                                                                            action:@selector(saveAll)];
    
    [items addObject:btSave];
    [items addObject:flexItem];
    
    //NSArray *items = [NSArray arrayWithObjects:self.btColour, flexItem, self.btStroke, flexItem, btRecycle, flexItem, btSave, nil];
    //[self setToolbarItems:items animated:YES];
  
    [self setToolbarItems:items animated:YES];

    [[self navigationController] setToolbarHidden:NO animated:YES];
    //self.navigationController.toolbar.barStyle = UIBarStyleBlackTranslucent;
    
    // Title text color Black => Text appears in white
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    self.navigationController.toolbar.translucent = false;

    // BACKGROUND color of nav bar
    UIColor *toolbarBackgroundColor = [self colorFromHexString:self.toolbarBackgroundColor];
    self.navigationController.toolbar.barTintColor = toolbarBackgroundColor;

    // Foreground color of bar button item text, e.g. "< Back", "Done", and so on.
    UIColor *toolbarTextColor = [self colorFromHexString:self.toolbarTextColor];
    self.navigationController.toolbar.tintColor = toolbarTextColor;
}

// Assumes input like "#00FF00" (#RRGGBB).
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];

#ifdef __IPHONE_7_0
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
            self.edgesForExtendedLayout = UIRectEdgeAll;
        }
    }
#endif
#else
    //don't have to do anything special here
#endif

    [self setUpToolbar];
    NSArray *subviews = [[[self navigationController] navigationBar] subviews];
    for(UIView *view in subviews){
        if([view isKindOfClass:[UITextField class]])
            [view setHidden:YES];
    }
    [[self navigationController]setNavigationBarHidden:NO];
    self.navigationController.toolbar.translucent = YES;
}

- (void)toggleColour:(id)sender event:(UIEvent*)event
{
    UIView *targetedView = [[event.allTouches anyObject] view];
    buttonsAnimationStartFrame = [self.view convertRect:targetedView.frame
                                               fromView:targetedView];

    if (coloursShown)
    {
        [self hideColourButtons];
    }
    else
    {
        [self showColourButtons];
    }
}

- (void)toggleStrokeWidth:(id)sender event:(UIEvent*)event
{
    UIView *targetedView = [[event.allTouches anyObject] view];
    strokeButtonsAnimationStartFrame = [self.view convertRect:targetedView.frame
                                               fromView:targetedView];

    if (strokeWidthsShown)
    {
        [self hideStrokeWidthButtons];
    }
    else
    {
        [self showStrokeWidthButtons];
    }
}

- (void)showColourButtons
{
    if (!coloursShown) {
        
        self.yellowbutton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.redButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.blueButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.greenButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.blackButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        
        self.yellowbutton.alpha = 0.0;
        self.redButton.alpha = 0.0;
        self.greenButton.alpha = 0.0;
        self.blueButton.alpha = 0.0;
        self.blackButton.alpha = 0.0;

        self.yellowbutton.frame = CGRectMake(buttonsAnimationStartFrame.origin.x,
                                        buttonsAnimationStartFrame.origin.y, 50.0, 50.0);

        self.redButton.frame = CGRectMake(buttonsAnimationStartFrame.origin.x,
                                          buttonsAnimationStartFrame.origin.y, 50.0, 50.0);
        self.blueButton.frame = CGRectMake(buttonsAnimationStartFrame.origin.x,
                                           buttonsAnimationStartFrame.origin.y, 50.0, 50.0);
        self.greenButton.frame = CGRectMake(buttonsAnimationStartFrame.origin.x,
                                            buttonsAnimationStartFrame.origin.y, 50.0, 50.0);
        self.blackButton.frame = CGRectMake(buttonsAnimationStartFrame.origin.x,
                                            buttonsAnimationStartFrame.origin.y, 50.0, 50.0);

        self.redButton.backgroundColor = [UIColor redColor];
        [self.redButton setTitleColor:[UIColor whiteColor]
                               forState:UIControlStateNormal];
        [self.redButton addTarget:self
                           action:@selector(colourChanged:)
                 forControlEvents:UIControlEventTouchDown];

        [self.redButton.layer setMasksToBounds:YES];
        [self.redButton.layer setCornerRadius:25.0f];

        [self.redButton setTitle:@" " forState:UIControlStateNormal];
        
        if([self.colour isEqual:[UIColor redColor]]) {
            self.redButton.enabled = NO;
        }
    
        [self.view addSubview:self.redButton];

        
        
        self.yellowbutton.backgroundColor = [UIColor yellowColor];
        [self.yellowbutton setTitleColor:[UIColor whiteColor]
                               forState:UIControlStateNormal];
        [self.yellowbutton addTarget:self
                           action:@selector(colourChanged:)
                 forControlEvents:UIControlEventTouchDown];

        [self.yellowbutton.layer setMasksToBounds:YES];
        [self.yellowbutton.layer setCornerRadius:25.0f];

        [self.yellowbutton setTitle:@" " forState:UIControlStateNormal];
        
        if([self.colour isEqual:[UIColor yellowColor]]) {
            self.yellowbutton.enabled = NO;
        }
    
        [self.view addSubview:self.yellowbutton];
        
        
        
        self.blueButton.backgroundColor = [UIColor blueColor];
        [self.blueButton setTitleColor:[UIColor whiteColor]
                             forState:UIControlStateNormal];
        [self.blueButton addTarget:self
                            action:@selector(colourChanged:)
                  forControlEvents:UIControlEventTouchDown];

        [self.blueButton.layer setMasksToBounds:YES];
        [self.blueButton.layer setCornerRadius:25.0f];

        [self.blueButton setTitle:@" " forState:UIControlStateNormal];
        
        if([self.colour isEqual:[UIColor blueColor]]) {
            self.blueButton.enabled = NO;
        }
    
        [self.view addSubview:self.blueButton];

        self.greenButton.backgroundColor = [UIColor greenColor];
        [self.greenButton setTitleColor:[UIColor whiteColor]
                             forState:UIControlStateNormal];
        [self.greenButton addTarget:self
                             action:@selector(colourChanged:)
                   forControlEvents:UIControlEventTouchDown];

        [self.greenButton.layer setMasksToBounds:YES];
        [self.greenButton.layer setCornerRadius:25.0f];

        [self.greenButton setTitle:@" " forState:UIControlStateNormal];
        
        if([self.colour isEqual:[UIColor greenColor]]) {
            self.greenButton.enabled = NO;
        }
    
        [self.view addSubview:self.greenButton];

        self.blackButton.backgroundColor = [UIColor blackColor];
        [self.blackButton setTitleColor:[UIColor whiteColor]
                               forState:UIControlStateNormal];
        [self.blackButton addTarget:self
                             action:@selector(colourChanged:)
                   forControlEvents:UIControlEventTouchDown];

        [self.blackButton.layer setMasksToBounds:YES];
        [self.blackButton.layer setCornerRadius:25.0f];

        [self.blackButton setTitle:@" " forState:UIControlStateNormal];
        
        if([self.colour isEqual:[UIColor blackColor]]) {
            self.blackButton.enabled = NO;
        }
        
        [self.view addSubview:self.blackButton];

        coloursShown = YES;

        float toolBarOriginY = self.navigationController.toolbar.frame.origin.y;
        [UIView animateWithDuration:0.3 animations:^{
            
            if([self.colour isEqual:[UIColor yellowColor]]) {
                self.yellowbutton.frame = CGRectMake(10.0, toolBarOriginY - 5*(50.0 + 10.0), 90.0, 50.0);
            } else {
                self.yellowbutton.frame = CGRectMake(10.0, toolBarOriginY - 5*(50.0 + 10.0), 50.0, 50.0);
            }
            
            if([self.colour isEqual:[UIColor redColor]]) {
                self.redButton.frame = CGRectMake(10.0, toolBarOriginY - 4*(50.0 + 10.0), 90.0, 50.0);
            } else {
                self.redButton.frame = CGRectMake(10.0, toolBarOriginY - 4*(50.0 + 10.0), 50.0, 50.0);
            }
            
            if([self.colour isEqual:[UIColor blueColor]]) {
                self.blueButton.frame = CGRectMake(10.0, toolBarOriginY - 3*(50.0 + 10.0), 90.0, 50.0);
            } else {
                self.blueButton.frame = CGRectMake(10.0, toolBarOriginY - 3*(50.0 + 10.0), 50.0, 50.0);
            }
            
            if([self.colour isEqual:[UIColor greenColor]]) {
                self.greenButton.frame = CGRectMake(10.0, toolBarOriginY - 2*(50.0 + 10.0), 90.0, 50.0);
            } else {
                self.greenButton.frame = CGRectMake(10.0, toolBarOriginY - 2*(50.0 + 10.0), 50.0, 50.0);
            }
            
            if([self.colour isEqual:[UIColor blackColor]]) {
                self.blackButton.frame = CGRectMake(10.0, toolBarOriginY - (50.0 + 10.0), 90.0, 50.0);
            } else {
                self.blackButton.frame = CGRectMake(10.0, toolBarOriginY - (50.0 + 10.0), 50.0, 50.0);
            }
            
            self.yellowbutton.alpha = 1.0;
            self.redButton.alpha = 1.0;
            self.greenButton.alpha = 1.0;
            self.blueButton.alpha = 1.0;
            self.blackButton.alpha = 1.0;
        }];

    }
}

- (void)showStrokeWidthButtons
{
    if (!strokeWidthsShown) {
        float toolBarOriginY = self.navigationController.toolbar.frame.origin.y;
        //CGRect frame = CGRectMake(20, toolBarOriginY - (50.0 + 10.0), 50, 20);
        
        UISlider *slider1 = [[UISlider alloc] init];
        [slider1 addTarget:self action:@selector(strokeWidthChanged:) forControlEvents:UIControlEventValueChanged];
        [slider1 setBackgroundColor:[UIColor clearColor]];
        slider1.minimumValue = 1;
        slider1.maximumValue = 36;
        slider1.continuous = NO;
        slider1.value = self.strokeWidth;
        slider1.contentMode = UIViewContentModeScaleToFill;
        
        [self.view addSubview:slider1];
        
        self.strokeSlider = slider1;
        
        
        strokeWidthsShown = YES;

        //[UIView animateWithDuration:0.3 animations:^{
            self.strokeSlider.frame = CGRectMake(20, toolBarOriginY - (50.0 + 10.0), (self.contentSize.width - 40), 50);
        //}];

    }
}

- (void)colourChanged:(id)sender
{
    NSLog(@"Colour changed.");
    [self hideColourButtons];
    self.colour = [(UIButton *)sender backgroundColor];

    //CGContextRef cgref = UIGraphicsGetCurrentContext();

    //if(erase == TRUE) // Erase to show background
    //{
    //   CGContextSetBlendMode(cgref, kCGBlendModeClear);
    //}
    //else // Draw with color
    //{
    //    CGContextSetBlendMode(cgref, kCGBlendModeNormal);
    //}
    
    //[self setColourButtonColour];
}

-(IBAction)strokeWidthChanged:(id)sender {
    UISlider *slider = (UISlider *)sender;
    NSLog(@"strokeWidthChanged ... %d",(int)[slider value]);
    self.strokeWidth = [slider value];
    [self hideStrokeWidthButtons];
}

- (void)setColourButtonColour
{
    if ([_btColour respondsToSelector:@selector(setTintColor:)])
    {
        // TODO: make sure the word 'White' is visible when white is selected

        if([self.colour isEqual:[UIColor whiteColor]]) // Erase to show background
        {
            [_btColour setTintColor:[UIColor blackColor]];
        }
        else // Draw with color
        {
            [_btColour setTintColor:self.colour];
        }
        
        NSLog(@"self.colour !!!!! = %@", self.colour);
        /*CGContextRef ctx = UIGraphicsGetCurrentContext();

        if([self.colour isEqual:[UIColor whiteColor]]) // Erase to show background
        {
            NSLog(@"self.colour ERASE = %@", self.colour);
            CGContextSetBlendMode(ctx, kCGBlendModeClear);
        }
        else // Draw with color
        {
            NSLog(@"self.colour !!!!! = %@", self.colour);
            CGContextSetBlendMode(cgref, kCGBlendModeNormal);
        }*/
    }
}

- (void)hideColourButtons
{
    if (coloursShown) {
        [UIView animateWithDuration:0.3 animations:^{
            self.yellowbutton.frame = CGRectMake(self->buttonsAnimationStartFrame.origin.x,
                                                self->buttonsAnimationStartFrame.origin.y, 50.0, 40.0);
            self.redButton.frame = CGRectMake(self->buttonsAnimationStartFrame.origin.x,
                                              self->buttonsAnimationStartFrame.origin.y, 50.0, 40.0);
            self.blueButton.frame = CGRectMake(self->buttonsAnimationStartFrame.origin.x,
                                               self->buttonsAnimationStartFrame.origin.y, 50.0, 40.0);
            self.greenButton.frame = CGRectMake(self->buttonsAnimationStartFrame.origin.x,
                                                self->buttonsAnimationStartFrame.origin.y, 50.0, 40.0);
            self.blackButton.frame = CGRectMake(self->buttonsAnimationStartFrame.origin.x,
                                                self->buttonsAnimationStartFrame.origin.y, 50.0, 40.0);
            
            self.yellowbutton.alpha = 0.0;
            self.redButton.alpha = 0.0;
            self.greenButton.alpha = 0.0;
            self.blueButton.alpha = 0.0;
            self.blackButton.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.yellowbutton removeFromSuperview];
            [self.redButton removeFromSuperview];
            [self.blueButton removeFromSuperview];
            [self.greenButton removeFromSuperview];
            [self.blackButton removeFromSuperview];
        }];

        coloursShown = NO;
    }
}

- (void)hideStrokeWidthButtons
{
    if (strokeWidthsShown) {
        [UIView animateWithDuration:0.3 animations:^{
            self.strokeSlider.frame = CGRectMake(self->strokeButtonsAnimationStartFrame.origin.x,
                                              self->strokeButtonsAnimationStartFrame.origin.y, 50.0, 40.0);
        } completion:^(BOOL finished) {
            [self.strokeSlider removeFromSuperview];
        }];

        strokeWidthsShown = NO;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    if (layer == _canvasLayer) {
        NSLog(@"drawLayer: _canvasLayer");
        if (_clearCanvasLayer) {
            NSLog(@"drawLayer: _clearCanvasLayer");
            CGContextClearRect(ctx, [_canvasLayer bounds]);
            _clearCanvasLayer = NO;
        }

        if (!_touching) {
            NSLog(@"drawLayer: !_touching");
            return;
        }


        //NSLog(@"drawLayer: colour = %@", self.colour);
        
        // Add path to context
        CGContextAddPath(ctx, _path.CGPath);
        CGContextSetLineWidth(ctx, self.strokeWidth);
        
        CGContextSetFillColorWithColor(ctx, [self.colour CGColor]);
        
        CGContextSetStrokeColorWithColor(ctx, [self.colour CGColor]);
        CGContextStrokePath(ctx);

    } else if (layer == _backgroundLayer) {
        NSLog(@"drawLayer: _backgroundLayer");
        // Save current context state
        CGContextSaveGState(ctx);

        // Fix cached image co-ordinates
        CGContextTranslateCTM(ctx, 0, [_backgroundLayer bounds].size.height);
        CGContextScaleCTM(ctx, 1.0, -1.0);

        if (_clearBackgroundLayer) {
            NSLog(@"drawLayer: _clearBackgroundLayer");
            CGContextClearRect(ctx, [_canvasLayer bounds]);
            _clearBackgroundLayer = NO;
        }
        // Draw image
        CGImageRef ref = [self.cacheImage CGImage];
        CGContextDrawImage(ctx, [_backgroundLayer bounds], ref);

        // Restore context to pre CTM state
        CGContextRestoreGState(ctx);
    } else {
        NSLog(@"drawLayer: inContext: unhandled layer = %@", layer);
    }
}

- (void)saveAll
{
    NSLog(@"saveAll ");

    //composite the cacheImage and the backgroundImage
    CGSize size = CGSizeMake(_contentSize.width, _contentSize.height);

    UIGraphicsBeginImageContext(size);
    [self.backgroundImage drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    UIImage* annotation = self.cacheImage;

    //scale the cacheImage to fit the new bounds
    [annotation drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    self.saved = YES;
    [self.delegate saveDrawing:output];

    self.cacheImage = nil;
}

- (void)clearAll
{
    NSLog(@"clearAll ");
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Notiz löschen" message:@"Alle Daten zurücksetzen?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *buttonOk = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self actionClearOk];
    }];
       
    UIAlertAction *buttonCancel = [UIAlertAction actionWithTitle:@"Abbrechen" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
    }];

    [controller addAction:buttonCancel];
    [controller addAction:buttonOk];
    
    [self presentViewController:controller animated:YES completion:nil];
}

-(void) actionClearOk {
    _hasDrawing = NO;
    
    // Clear the collections
    _clearCanvasLayer = YES;
    _clearBackgroundLayer = YES;
    
    //clear the cache image
    UIGraphicsBeginImageContext(_contentSize);
    UIColor *color = [UIColor clearColor];
    [color set];
    UIRectFill(CGRectMake(0.0, 0.0, _contentSize.width, _contentSize.height));
    
    _cacheImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Redraw
    [_canvasLayer setNeedsDisplay];
    [_backgroundLayer setNeedsDisplay];
}

- (void)cancelAll
{
    NSLog(@"cancelAll ");

    _hasDrawing = NO;
    [self.delegate cancelDrawing];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *t = [touches anyObject];

    if ([touches count] > 1) {
        NSLog(@"touchesBegan [touches count] > 1");
    }

    if (_touching) {
        return;
    }

    // Create a line for the value
    CGPoint loc = [t locationInView:self.backgroundView];

    // Start a new path
    _path = [UIBezierPath bezierPath];
    _path.lineWidth = self.strokeWidth;
    _path.lineJoinStyle = kCGLineJoinRound;
    _path.flatness = .2;

    [_path moveToPoint:loc];
    _pathPoint = loc;
    _touching = YES;
    _moved = NO;
}

static CGPoint CGPointMid(CGPoint a, CGPoint b)
{
    return (CGPoint){ (a.x + b.x) / 2.0, (a.y +b.y) / 2.0 };
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_touching) {
        // Update linesInProcess with moved touches
        UITouch *t = [touches anyObject];
        CGPoint currentPoint = [t locationInView:self.backgroundView];

        if ([touches count] > 1) {
            NSLog(@"touchesMoved [touches count] > 1");
        }

        if (!_moved) {
            if (!CGPointEqualToPoint(currentPoint, _pathPoint)) {
                [_path addLineToPoint:currentPoint];
                _pathPoint = currentPoint;
            }
        } else {
            CGPoint midPoint = CGPointMid(currentPoint, _pathPoint);

            // Update current path
            [_path addQuadCurveToPoint:currentPoint controlPoint:midPoint];
            _pathPoint = currentPoint;
        }
        // Update the line
        [_canvasLayer setNeedsDisplay];
    } else {
        NSLog(@"touchesMoved: not touching...");
    }
    _moved = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_touching) {
        return;
    }

    if ([touches count] > 1) {
        NSLog(@"endTouches [touches count] > 1");
    }

    if (!_moved) {
        UITouch *t = [touches anyObject];
        CGPoint loc = [t locationInView:self.backgroundView];

        // If this is a single touch register as a 1 x 1 dot
        [_path addLineToPoint:loc];
    }
    _moved = NO;

    // Create a new image context
    CGRect bl = [_backgroundLayer bounds];
    UIGraphicsBeginImageContext(CGSizeMake(bl.size.width, bl.size.height));
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Image is the current drawing context
    UIGraphicsPushContext(ctx);

    // Prevent white pixels from hiding already drawn lines
    CGContextSetBlendMode(ctx, kCGBlendModeDarken);

    if (self.cacheImage != nil) {
        // Draw the cached image to the context
        [self.cacheImage drawInRect:CGRectMake(0, 0, bl.size.width, bl.size.height)];
    }

    // Blend the drawing layer into the image context
    [_canvasLayer drawInContext:ctx];
    UIGraphicsPopContext();

    // Store image context so we can add to it later
    self.cacheImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    _touching = NO;
    _path = nil;
    _hasDrawing = YES;

    // Redraw
    [_backgroundLayer setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
    if (self.cacheImage != nil) {
        self.cacheImage = nil;
    }
    self.backgroundImage = nil;
    self.backgroundLayer = nil;
    self.canvasLayer = nil;
    self.backgroundLayer.delegate = nil;
    self.canvasLayer.delegate = nil;
    [self.backgroundLayer removeFromSuperlayer];
    [self.canvasLayer removeFromSuperlayer];
    self.tdv = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    UINavigationBar *navBar = [[self navigationController] navigationBar];
    NSArray *subviews = [navBar subviews];
    for(UIView *view in subviews){
        if([view isKindOfClass:[UITextField class]])
            [view setHidden:NO];
    }
    if([[self navigationController] isNavigationBarHidden]){
        [[self navigationController] setNavigationBarHidden:NO];
        [[self navigationController] setNavigationBarHidden:YES];
    }else{
        [[self navigationController] setNavigationBarHidden:YES];
        [[self navigationController] setNavigationBarHidden:NO];
    }
    [navBar layoutSubviews];

    if (!self.saved) {
        [self cancelAll];
    }

    //re-enable gesture recognizer
    for (UIGestureRecognizer *recognizer in
         self.navigationController.view.gestureRecognizers) {
        [recognizer setEnabled:YES];
    }
}

@end
