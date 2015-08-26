/*
	File: ChatServerController.m
	Constains: UI for Bluetooth sample [not to be used as UI sample code]
	Author: Marco Pontil

	Copyright (c) 2002 by Apple Computer, Inc., all rights reserved.
*/
/*
	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
	consideration of your agreement to the following terms, and your use, installation, 
	modification or redistribution of this Apple software constitutes acceptance of these 
	terms.  If you do not agree with these terms, please do not use, install, modify or 
	redistribute this Apple software.
	
	In consideration of your agreement to abide by the following terms, and subject to these 
	terms, Apple grants you a personal, non-exclusive license, under AppleÕs copyrights in 
	this original Apple software (the "Apple Software"), to use, reproduce, modify and 
	redistribute the Apple Software, with or without modifications, in source and/or binary 
	forms; provided that if you redistribute the Apple Software in its entirety and without 
	modifications, you must retain this notice and the following text and disclaimers in all 
	such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
	or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
	the Apple Software without specific prior written permission from Apple. Except as expressly
	stated in this notice, no other rights or licenses, express or implied, are granted by Apple
	herein, including but not limited to any patent rights that may be infringed by your 
	derivative works or by other works in which the Apple Software may be incorporated.
	
	The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
	EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
	MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
	USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
	
	IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
	DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
	OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
	REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
	WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
	OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ChatServerController.h"
#import "ChatBluetoothServerInterface.h"

@implementation ChatServerController

// NOTE: This is NOT an UI example, the user interface in this application is pourposly
// minimal. Do do not EVER think of using this file as code sample for your applications.

// Object Allocation and Deallocation
- init
{
    self = [super init];
    myBluetoothInterface = [[ChatBluetoothServerInterface alloc] init];

    // Registes the callbacks for connection and for disconnection:
    [myBluetoothInterface registerForTermination:self action:@selector(chatHandleRemoteDisconnection)];
    [myBluetoothInterface registerForNewConnection:self action:@selector(chatHandleRemoteConnection)];
    
    // gets the local device name:
    localDeviceName = [myBluetoothInterface localDeviceName];
    [localDeviceName retain];

    [self performSelector:@selector(chatActionOnServerStart:) withObject:self afterDelay:0.2f];
    
    return self;
}

- (void) dealloc
{
    [localDeviceName release];
    [myBluetoothInterface release];
    [super dealloc];
}

- (BOOL) windowShouldClose: (NSWindow*) sender
{
    [myBluetoothInterface stopProvidingChatServices];
    [myBluetoothInterface disconnectFromClient];
    
    exit(0);
    
    return TRUE;
}

// UI Handlers.
- (IBAction)chatActionOnDisconnect:(id)sender
{
    [myBluetoothInterface disconnectFromClient];
//    [self chatHandleRemoteDisconnection];
}

- (IBAction)chatActionOnMessageTextField:(id)sender
{
    NSRange      theRange;
    unsigned int start;
    NSMutableString    *theString;

    // Send the message trough the bluetooth channel:
    theString = [NSMutableString stringWithFormat:@"%@\n",[chatInputTextField stringValue]];
    
    [myBluetoothInterface sendData:(void*)[theString UTF8String] length:[theString length]];

    // Send the message trough the bluetooth channel:
    theString = [NSMutableString stringWithFormat:@"%@: %@",localDeviceName , theString];

    // Dump it on the screen
    start = [[chatOutputTextField string] length];
    theRange = NSMakeRange(start, 0 );
    
    [chatOutputTextField replaceCharactersInRange:theRange withString:theString];
    theRange = NSMakeRange(start, [theString length] );
    [chatOutputTextField setTextColor:[NSColor blueColor] range:theRange];
    
    // Clears the input text field:
    [chatInputTextField setStringValue:@""];
}

- (IBAction)chatActionOnServerStart:(id)sender
{
    // Publishes the services:
    if ([myBluetoothInterface publishService])
    {
        [serverWaitBar startAnimation:sender];
        [NSApp beginSheet:waitConnectionPanel modalForWindow:mainWindow modalDelegate:self didEndSelector:NULL contextInfo:NULL];
    }
}

- (void)connectionFollowUp:(BOOL)success
{
    [serverWaitBar stopAnimation:waitCancelButton];
    [NSApp endSheet:waitConnectionPanel];
    [waitConnectionPanel close];

    // This sample APP can handle only one connection so:
    // 1] we are connected, so we stop vening the service because we can take only one a time.
    // 2] we are not connected so we stop vending the service because there is no service.
    // Independently from "success" we stop vending services.
    [myBluetoothInterface stopProvidingChatServices];
        
    if (success == FALSE)
    {
        NSBeep();
    }
    else
    {
        // If we were successful registers to get new data and enables the buttons and textfield:
        [myBluetoothInterface registerForNewData:self action:@selector(chatHandleNewData:)];
        
        [chatDisconnectButton setEnabled:TRUE];
        [chatInputTextField setEnabled:TRUE];
        [chatOutputTextField setString:@""];
    }
    isBinary = NO;
}

- (IBAction)waitActionCancel:(id)sender
{
    [self connectionFollowUp:FALSE];
    [NSApp stopModal];
}

// Bluetooth Handlers
- (void)chatHandleRemoteDisconnection
{
    [self logWrite:@"Disconnected\n"];
    
    [chatDisconnectButton setEnabled:FALSE];
    [chatInputTextField setEnabled:FALSE];
    
    [myBluetoothInterface registerForNewData:nil action:nil];
    
    [self performSelector:@selector(chatActionOnServerStart:) withObject:self afterDelay:1.0f];
}


- (void)chatHandleRemoteConnection
{
    NSLog(@"Got chatHandleRemoteConnection begin\n");

    [self connectionFollowUp:TRUE];
    
    [self logWrite:@"Connected\n"];

    NSLog(@"Got chatHandleRemoteConnection 1\n");
}

- (void)chatHandleNewData:(NSData*)dataObject
{
    [self onReadData:dataObject];
    Byte bytes[dataObject.length];
    [dataObject getBytes:bytes];
    NSRange      theRange;
    unsigned int start;
    NSString    *theString;
    
    // Dump the message on the screen
    start = [[chatOutputTextField string] length];
    theRange = NSMakeRange(start, 0 );
    
    if(isBinary){
        theString = [NSString stringWithFormat:@">> read  length: %@ header: %@\n", @(dataObject.length), @(bytes[0])];
    } else {
        theString = [NSMutableString stringWithFormat:@"%@: >> %@\n",[myBluetoothInterface remoteDeviceName] , [[[NSString alloc] initWithBytes:[dataObject bytes] length:[dataObject length] encoding:NSUTF8StringEncoding] autorelease]];
    }
    [chatOutputTextField replaceCharactersInRange:theRange withString:theString];
    theRange = NSMakeRange(start, [theString length] );
    [chatOutputTextField setTextColor:[NSColor redColor] range:theRange];
    
    [chatOutputTextField scrollRangeToVisible:theRange];
    
}

- (void) logWrite:(NSString*) string
{
    NSRange      theRange;
    unsigned int start;
//    NSString    *string;
    
    start = [[chatOutputTextField string] length];
    theRange = NSMakeRange(start, 0 );
    
//    theString = [NSMutableString stringWithFormat:@"%@: %@",[myBluetoothInterface remoteDeviceName] , [[[NSString alloc] initWithBytes:[dataObject bytes] length:[dataObject length] encoding:NSUTF8StringEncoding] autorelease]];
//    
    [chatOutputTextField replaceCharactersInRange:theRange withString:string];
    theRange = NSMakeRange(start, [string length] );
    [chatOutputTextField setTextColor:[NSColor blackColor] range:theRange];
    
    [chatOutputTextField scrollRangeToVisible:theRange];
}

short BYTETOWORD(Byte low, Byte hi)
{
    return (((int)(low)&0x00ff)|(((int)(hi)<<8)&0xff00));
}

int packCount = 0;
int currentPack = 0;
int flashStateCounter = 0;
BOOL isBinary = NO;

Byte * waveData;

void prepareData(int length)
{
    if (waveData) free(waveData);
    waveData = malloc(length);
    bzero(waveData, length);
    SInt16 * samples = (SInt16*)waveData;
    
    for(int i = 0; i < length/2; i ++)  samples[i] = (SInt16)(20.48 * sinf(2 * M_PI*i * 250 / 20000 )/(i * 0.001f + 1));
//    for(int i = 0; i < length/2 - length/6; i ++)  samples[i + length/6] +=  (int)(10.24 * sinf(2 * M_PI * i * 250 / 20000 )/(i * 0.001f + 1));

}

- (void) sendData:(void*) data length:(UInt32)length
{
    BOOL suc = [myBluetoothInterface sendData:data length:length];
    if(suc)
    {
        Byte * byte = (Byte*)data;
        [self logWrite:[NSString stringWithFormat:@"<< write length: %@ , header: %@\n", @(length), @((int)byte[0])]];
    }
}

- (void) onReadData:(NSData*)data
{
    NSString * str = [NSString stringWithUTF8String:data.bytes];
    Byte * bytes = (Byte*)[data bytes];
    NSLog(@"READ: %lu, %d, :  %@  ::  %@", (unsigned long)data.length, (int)bytes[0], data, [NSString stringWithUTF8String:data.bytes]);
    
    char * chans = NULL;
    if([str isEqualToString:@"XAT+$\r"]) {
        chans = "4556473587\r";
        [self sendData:(void*)chans length:11];
    }
    else if([str isEqualToString:@"2156473587\r"])
    {
        chans = "OK\r";
        [self sendData:(void*)chans length:3];
        isBinary = YES;
    }
    else if((bytes[0] == 17 || bytes[0] == 18))//sound pack, aru pack requests (17 & 18)
    {
        Byte sbytes[3];
        sbytes[0] = bytes[0];
        sbytes[1] = 0;
        sbytes[2] = 3;
        [self sendData:(void*)sbytes length:3];
    }
    else if(bytes[0] == 23)//prepare metering
    {
        packCount = BYTETOWORD(bytes[3], bytes[4]);
        prepareData(packCount*510);
        
        currentPack = 0;
        NSLog(@"PACK COUNT: %d", packCount);
        
        Byte sbytes[4];
        sbytes[0] = 24;//metering prepared reply
        sbytes[1] = 0;
        sbytes[2] = 4;
        sbytes[3] = 1;
        [self sendData:(void*)sbytes length:4];
    }
    else if(bytes[0] == 25)//flash state check
    {
        Byte sbytes[4];
        sbytes[0] = 23;//flash state reply
        sbytes[1] = 0;
        sbytes[2] = 4;
        sbytes[3] = (flashStateCounter>6?1:0);
        flashStateCounter++;
        [self sendData:(void*)sbytes length:4];
    }
    else if(bytes[0] == 12)//power
    {
        int power = 1400;
        
        Byte sbytes[10];
        sbytes[0] = 12;
        sbytes[1] = 0;
        sbytes[2] = 10;
        
        sbytes[3] = (Byte)(power & 0x00FF);
        sbytes[4] = (Byte)((power & 0xFF00)>>8);
        
        sbytes[9] = 0;
        [self sendData:(void*)sbytes length:10];
    }
    else if(bytes[0] == 21 && data.length == 3)//start meas button pressed
    {
        Byte sbytes[3];
        sbytes[0] = 25;//start probe
        sbytes[1] = 0;
        sbytes[2] = 3;
        [self sendData:(void*)sbytes length:3];
    }
    else if(bytes[0] == 9 && data.length == 3)//send next pack request
    {
        if(!currentPack)currentPack++;
        else currentPack+=10;
        if(currentPack > packCount) {
            NSLog(@"SENT packs total: %d", currentPack-1);
            Byte sbytes[3];
            sbytes[0] = 28;//next pack end
            sbytes[1] = 0;
            sbytes[2] = 3;
            [self sendData:(void*)sbytes length:3];

            return;
        }
        NSLog(@"Sending NEXT pack No: %d", currentPack);
        
        Byte sbytes[522];
        sbytes[0] = 9;//next pack reply code
        sbytes[1] = ((522 & 0xFF00)>>8);
        sbytes[2] =  (522 & 0x00FF);
        sbytes[3] = 0;
        sbytes[4] = 0;
        sbytes[5] = 0;
        sbytes[6] = 0;
        sbytes[7] = 0;
        sbytes[8] = 0;
        sbytes[9] = 0;
        sbytes[11] = (Byte)((currentPack & 0xFF00)>>8);//why other order?
        sbytes[10] = (Byte)(currentPack & 0x00FF);
//        for(int i = 12; i < 522; i ++)
//        {
//            Byte sample = 128 * random() / (float)0x7fffffff;
//            if(i>12) sbytes[i] = 0.1f * sample + 0.9f * sbytes[i-1];
//            else sbytes[i] = sample;
//        }
        for(int i = 12; i < 522; i+=2)
        {
            int j = currentPack*(i-12);
            sbytes[i] = waveData[j+1];
            sbytes[i+1] = waveData[j];
        }
        [self sendData:(void*)sbytes length:522];
        
    }
    else if(bytes[0] == 8 && data.length == 5)//send pack (number) request
    {
        int packNum = BYTETOWORD(bytes[3], bytes[4]);
        
        NSLog(@"Sending EXACT pack No: %d", packNum);
        
//        [self log:@"Sending EXACT pack No: %d", packNum];
        
        Byte sbytes[522];
        sbytes[0] = 8;//exact pack reply code
        sbytes[1] = ((522 & 0xFF00)>>8);
        sbytes[2] =  (522 & 0x00FF);
        sbytes[3] = 0;
        sbytes[4] = 0;
        sbytes[5] = 0;
        sbytes[6] = 0;
        sbytes[7] = 0;
        sbytes[8] = 0;
        sbytes[9] = 0;
        sbytes[11] = (Byte)((packNum & 0xFF00)>>8);//why other order?
        sbytes[10] = (Byte)(packNum & 0x00FF);
//        for(int i = 12; i < 522; i ++)
//        {
//            Byte sample = 128 * random() / (float)0x7fffffff;
//            if(i>12) sbytes[i] = 0.1f * sample + 0.9f * sbytes[i-1];
//            else sbytes[i] = sample;
//        }
        for(int i = 12; i < 522; i+=2)
        {
            int j = packNum*(i-12);
            sbytes[i] = waveData[j+1];
            sbytes[i+1] = waveData[j];
        }
        [self sendData:sbytes length:33];
//        usleep(50000);
        [self sendData:sbytes+33 length:100];
        [self sendData:sbytes+133 length:100];
        [self sendData:sbytes+233 length:100];
        [self sendData:sbytes+333 length:100];
        [self sendData:sbytes+433 length:522 - 433];
    }
//    NSLog(@"WRITE Suc: %d", (int)suc);
}

@end
