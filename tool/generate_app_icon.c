// Deterministic rendering of assets/branding/projectbridge-icon.svg on macOS.
#include <ApplicationServices/ApplicationServices.h>
#include <ImageIO/ImageIO.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 3) return 1;
    int size = atoi(argv[2]);
    CGColorSpaceRef colors = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, size, size, 8, size * 4, colors, kCGImageAlphaNoneSkipLast);
    CGContextScaleCTM(c, size / 1024.0, size / 1024.0);
    CGContextSetRGBFillColor(c, 108/255.0, 92/255.0, 231/255.0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 1024, 1024));
    CGContextTranslateCTM(c, 0, 1024);
    CGContextScaleCTM(c, 1, -1);
    CGContextSetRGBStrokeColor(c, 1, 1, 1, 1);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);
    CGContextSetLineWidth(c, 64);
    CGContextMoveToPoint(c, 288, 650);
    CGContextAddLineToPoint(c, 288, 510);
    CGContextAddCurveToPoint(c, 288, 386, 388, 330, 512, 330);
    CGContextAddCurveToPoint(c, 636, 330, 736, 386, 736, 510);
    CGContextAddLineToPoint(c, 736, 650);
    CGContextStrokePath(c);
    CGContextMoveToPoint(c, 256, 554);
    CGContextAddLineToPoint(c, 768, 554);
    CGContextStrokePath(c);
    CGContextSetLineWidth(c, 40);
    for (int x = 416; x <= 608; x += 192) {
        CGContextMoveToPoint(c, x, 355);
        CGContextAddLineToPoint(c, x, 554);
    }
    CGContextStrokePath(c);
    CGImageRef image = CGBitmapContextCreateImage(c);
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[1], strlen(argv[1]), false);
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    int success = CGImageDestinationFinalize(destination);
    CFRelease(destination); CFRelease(url); CGImageRelease(image); CGContextRelease(c); CGColorSpaceRelease(colors);
    return success ? 0 : 1;
}
