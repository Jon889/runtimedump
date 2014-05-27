runtimedump
===========

Use with cycript (use ?expand in cycript to get new lines)


$headerString or $hs
====================

Use this to print the header of the class directly in the terminal. For example:

    [NSObject $headerString];
    [NSObject $hs];
    NSObject *someObject = [[NSObject alloc] init];
    [someObject $headerString];
    [someObject $hs];
    
Will all print the same thing, the header of NSObject (including private methods and any added at runtime such as those added by tweaks)

$hs is just shortcut for $headerString, because I'm lazy.


$classes
========

Print an array of all classes loaded from an NSBundle.

For example:

    [[NSBundle mainBundle] $classes];
    
Will print the list of classes in the mainBundle, so if you're in MobileSafari it will include names like BrowserController.

You can get an array of all headers by doing: (may be useful for dumping all headers in an app)

    [[[NSBundle mainBundle] $classes] valueForKey:@"$hs"];
    
$printAllIVars
==============

Print the names of all Ivars against their current values.
This is useful because if you have an object (say just a UIView, so there's no delegate or anything to follow), and you think you know another objet references it, but are not sure which instance variable holds the reference. You can just Cmd-F on the above.

For example, you have a view `v`:

    [v superview] 
    
Gives:
    
    <UIView: 0x137df4b30; frame = (0 20; 320 548); layer = <CALayer: 0x137df43e0>>
    
You think BrowserController is likely to reference `[v superview]`, so do:
    
    [[BrowserController sharedBrowserController] $printAllIVars]
    
Which gives:

    _window : <MobileSafariWindow: 0x137df2de0; baseClass = UIWindow; frame = (0 0; 320 568); opaque = NO; gestureRecognizers = <NSArray: 0x137f96060>; layer = <UIWindowLayer: 0x137d8dbf0>>
    _addressView : (null)
    _backgroundColorView : <UIView: 0x137df32b0; frame = (0 44; 320 460); layer = <CALayer: 0x139002020>>
    _rootView : <UIView: 0x137df4b30; frame = (0 20; 320 548); layer = <CALayer: 0x137df43e0>>
    //...etc...
    
Searching for 0x137df4b30 will show you that instance variable you're looking for is _rootView.

You can then look at the header to see if there's an accessor method, or use the instance variable in your code directly. 
    
    

    


