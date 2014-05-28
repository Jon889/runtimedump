#import "RTBSelectView.h"
 
@implementation RTBSelectView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	self.touchedPoint = [touch locationInView:self];
	self.didGetTouched = YES;
	[super touchesCancelled:touches withEvent:event];
}

@end