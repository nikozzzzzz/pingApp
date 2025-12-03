/*
    File:       SimplePing.m

    Contains:   Object wrapper around the low-level BSD Sockets ping function.

    Written by: DTS

    Copyright:  Copyright (c) 2010-2016 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis.
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import "SimplePing.h"

#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>

#pragma mark * Utilities

/*! Returns the string representation of the supplied address.
 *  \param address The address, a (struct sockaddr) inside an NSData.
 *  \returns A string representation of that address, or nil if the address is
 * invalid.
 */

static NSString *_Nullable DisplayAddressForAddress(NSData *_Nullable address) {
  int err;
  NSString *result;
  char hostStr[NI_MAXHOST];

  result = nil;

  if (address != nil) {
    err = getnameinfo(address.bytes, (socklen_t)address.length, hostStr,
                      sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
    if (err == 0) {
      result = @(hostStr);
    }
  }

  return result;
}

/*! Returns a suitable error for the result of a socket call.
 *  \param err The value of `errno`.
 *  \returns An error representing that `errno`.
 */

static NSError *_Nonnull SimplePingErrorForErrno(int err) {
  return [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
}

#pragma mark * SimplePing

@interface SimplePing ()

@property(nonatomic, copy, readwrite, nullable) NSData *hostAddress;
@property(nonatomic, assign, readwrite) uint16_t nextSequenceNumber;

@property(nonatomic, assign, readwrite) CFHostRef host;
@property(nonatomic, assign, readwrite) CFSocketRef socket;

@end

@implementation SimplePing

- (instancetype)initWithHostName:(NSString *)hostName {
  assert(hostName != nil);
  self = [super init];
  if (self != nil) {
    _hostName = [hostName copy];
    _identifier = (uint16_t)arc4random();
  }
  return self;
}

- (void)dealloc {
  [self stop];
  // _hostName is a property
  // _hostAddress is a property
}

- (sa_family_t)hostAddressFamily {
  sa_family_t result;

  result = AF_UNSPEC;
  if ((self.hostAddress != nil) &&
      (self.hostAddress.length >= sizeof(struct sockaddr))) {
    result = ((const struct sockaddr *)self.hostAddress.bytes)->sa_family;
  }
  return result;
}

/*! The callback for our CFSocket object.
 *  \details This simply routes the call to our `-readData` method.
 *  \param s See the documentation for CFSocketCallBack.
 *  \param type See the documentation for CFSocketCallBack.
 *  \param address See the documentation for CFSocketCallBack.
 *  \param data See the documentation for CFSocketCallBack.
 *  \param info See the documentation for CFSocketCallBack; this is actually a
 * pointer to the 'owning' object.
 */

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type,
                               CFDataRef address, const void *data,
                               void *info) {
  // This C routine is called by CFSocket when there's data waiting on our
  // ICMP socket.  It just redirects the call to Objective-C code.
  SimplePing *obj;

  obj = (__bridge SimplePing *)info;
  assert([obj isKindOfClass:[SimplePing class]]);

#pragma unused(s)
  assert(s == obj.socket);
#pragma unused(type)
  assert(type == kCFSocketReadCallBack);
#pragma unused(address)
  assert(address == nil);
#pragma unused(data)
  assert(data == nil);

  [obj readData];
}

/*! Starts the send and receive infrastructure.
 *  \details This is called once we've successfully resolved `hostName` in to
 *      `hostAddress`.  It's responsible for setting up the socket for sending
 * and receiving pings.
 */

- (void)startWithHostAddress {
  int err;
  int fd;

  assert(self.hostAddress != nil);

  // Open the socket.

  fd = -1;
  err = 0;
  switch (self.hostAddressFamily) {
  case AF_INET: {
    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (fd < 0) {
      err = errno;
    }
  } break;
  case AF_INET6: {
    fd = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
    if (fd < 0) {
      err = errno;
    }
  } break;
  default: {
    err = EPROTONOSUPPORT;
  } break;
  }

  if (err != 0) {
    [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:err
                                           userInfo:nil]];
  } else {
    CFSocketContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFRunLoopSourceRef rls;
    id<SimplePingDelegate> strongDelegate;

    // Wrap it in a CFSocket and schedule it on the runloop.

    self.socket = (CFSocketRef)CFAutorelease(CFSocketCreateWithNative(
        NULL, fd, kCFSocketReadCallBack, SocketReadCallback, &context));
    assert(self.socket != NULL);

    // The socket will now take care of cleaning up our file descriptor.

    CFSocketSetSocketFlags(self.socket, kCFSocketCloseOnInvalidate);

    if (!CFSocketGetSocketFlags(self.socket)) {
      [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:err
                                             userInfo:@{
                                               NSLocalizedDescriptionKey :
                                                   @"Invalid socket flags"
                                             }]];
      return;
    } else if (!kCFSocketCloseOnInvalidate) {
      [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:err
                                             userInfo:@{
                                               NSLocalizedDescriptionKey :
                                                   @"Invalid socket close"
                                             }]];
      return;
    }

    fd = -1;

    rls = CFSocketCreateRunLoopSource(NULL, self.socket, 0);
    assert(rls != NULL);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopCommonModes);

    CFRelease(rls);

    strongDelegate = self.delegate;
    if ((strongDelegate != nil) &&
        [strongDelegate respondsToSelector:@selector(simplePing:
                                               didStartWithAddress:)]) {
      [strongDelegate simplePing:self didStartWithAddress:self.hostAddress];
    }
  }
  assert(fd == -1);
}

/*! Processes the results of our name-to-address resolution.
 *  \details Called by our CFHost resolution callback (HostResolveCallback) when
 * host resolution is complete.  We just latch the first appropriate address and
 * kick off the send and receive infrastructure.
 */

- (void)hostResolutionDone {
  Boolean resolved;
  NSArray *addresses;

  // Find the first appropriate address.

  addresses = (__bridge NSArray *)CFHostGetAddressing(self.host, &resolved);
  if (resolved && (addresses != nil)) {
    resolved = false;
    for (NSData *address in addresses) {
      const struct sockaddr *addrPtr;

      addrPtr = (const struct sockaddr *)address.bytes;
      if (address.length >= sizeof(struct sockaddr)) {
        switch (addrPtr->sa_family) {
        case AF_INET: {
          if (self.addressStyle != SimplePingAddressStyleICMPv6) {
            self.hostAddress = address;
            resolved = true;
          }
        } break;
        case AF_INET6: {
          if (self.addressStyle != SimplePingAddressStyleICMPv4) {
            self.hostAddress = address;
            resolved = true;
          }
        } break;
        }
      }
      if (resolved) {
        break;
      }
    }
  }

  // We're done resolving, so shut that down.

  [self stopHostResolution];

  // If all is OK, start the send and receive infrastructure, otherwise stop.

  if (resolved) {
    [self startWithHostAddress];
  } else {
    [self
        didFailWithError:[NSError
                             errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                                        code:kCFHostErrorHostNotFound
                                    userInfo:nil]];
  }
}

/*! The callback for our CFHost object.
 *  \details This simply routes the call to our `-hostResolutionDone` or
 *      `-didFailWithHostStreamError:` methods.
 *  \param theHost See the documentation for CFHostClientCallBack.
 *  \param typeInfo See the documentation for CFHostClientCallBack.
 *  \param error See the documentation for CFHostClientCallBack.
 *  \param info See the documentation for CFHostClientCallBack; this is actually
 * a pointer to the 'owning' object.
 */

static void HostResolveCallback(CFHostRef theHost, CFHostInfoType typeInfo,
                                const CFStreamError *error, void *info) {
  // This C routine is called by CFHost when the host resolution is complete.
  // It just redirects the call to the appropriate Objective-C method.
  SimplePing *obj;

  obj = (__bridge SimplePing *)info;
  assert([obj isKindOfClass:[SimplePing class]]);

#pragma unused(theHost)
  assert(theHost == obj.host);
#pragma unused(typeInfo)
  assert(typeInfo == kCFHostAddresses);

  if ((error != NULL) && (error->domain != 0)) {
    [obj didFailWithHostStreamError:*error];
  } else {
    [obj hostResolutionDone];
  }
}

- (void)start {
  Boolean success;
  CFHostClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
  CFStreamError streamError;

  assert(self.host == NULL);
  assert(self.hostAddress == nil);

  self.host = (CFHostRef)CFAutorelease(
      CFHostCreateWithName(NULL, (__bridge CFStringRef)self.hostName));
  assert(self.host != NULL);

  CFHostSetClient(self.host, HostResolveCallback, &context);

  CFHostScheduleWithRunLoop(self.host, CFRunLoopGetCurrent(),
                            kCFRunLoopCommonModes);

  success =
      CFHostStartInfoResolution(self.host, kCFHostAddresses, &streamError);
  if (!success) {
    [self didFailWithHostStreamError:streamError];
  }
}

/*! Stops the name-to-address resolution infrastructure.
 */

- (void)stopHostResolution {
  // Shut down the CFHost.
  if (self.host != NULL) {
    CFHostSetClient(self.host, NULL, NULL);
    CFHostUnscheduleFromRunLoop(self.host, CFRunLoopGetCurrent(),
                                kCFRunLoopCommonModes);
    self.host = NULL;
  }
}

/*! Stops the send and receive infrastructure.
 */

- (void)stopSocket {
  if (self.socket != NULL) {
    CFSocketInvalidate(self.socket);
    self.socket = NULL;
  }
}

- (void)stop {
  [self stopHostResolution];
  [self stopSocket];

  // Junk the host address on stop.  If the client calls -start again, we'll
  // re-resolve the host name.

  self.hostAddress = NULL;
}

/*! Sends a ping.
 *  \details Called to send a ping, either from `-sendPingWithData:` or
 *      `-simplePing:didStartWithAddress:`.
 *  \param data The data to send.
 */

- (void)sendPingWithData:(NSData *)data {
  int err;
  NSData *payload;
  NSMutableData *packet;
  ICMPHeader *icmpPtr;
  ssize_t bytesSent;

  // Construct the ping packet.

  payload = data;
  if (payload == nil) {
    payload = [[NSString
        stringWithFormat:@"%28zd bottles of beer on the wall",
                         (ssize_t)99 - (size_t)(self.nextSequenceNumber % 100)]
        dataUsingEncoding:NSASCIIStringEncoding];
    assert(payload != nil);

    // Our dummy payload is sized so that the resulting ICMP packet, including
    // the ICMPHeader, is 64-bytes, which is a standard ping size.

    assert(payload.length == 56);
  }

  packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + payload.length];
  assert(packet != nil);

  icmpPtr = packet.mutableBytes;
  icmpPtr->type = (self.hostAddressFamily == AF_INET) ? ICMPv4TypeEchoRequest
                                                      : ICMPv6TypeEchoRequest;
  icmpPtr->code = 0;
  icmpPtr->checksum = 0;
  icmpPtr->identifier = CFSwapInt16HostToBig(self.identifier);
  icmpPtr->sequenceNumber = CFSwapInt16HostToBig(self.nextSequenceNumber);
  memcpy(&icmpPtr[1], payload.bytes, payload.length);

  // The IP checksum returns a 16-bit number that's already in correct byte
  // order (although that doesn't matter for the checksum as it's the same value
  // either way).
  //
  // However, the kernel calculates the checksum for us for IPv6, so we only do
  // this for IPv4.

  if (self.hostAddressFamily == AF_INET) {
    icmpPtr->checksum = [SimplePing icmpInPacket:packet];
  }

  // Send the packet.

  if (self.socket == NULL) {
    bytesSent = -1;
    err = EPIPE;
  } else {
    bytesSent =
        sendto(CFSocketGetNative(self.socket), packet.bytes, packet.length, 0,
               (const struct sockaddr *)self.hostAddress.bytes,
               (socklen_t)self.hostAddress.length);
    err = 0;
    if (bytesSent < 0) {
      err = errno;
    }
  }

  // Handle the results of the send.

  if ((bytesSent > 0) && (((NSUInteger)bytesSent) == packet.length)) {
    if ((self.delegate != nil) &&
        [self.delegate respondsToSelector:@selector
                       (simplePing:didSendPacket:sequenceNumber:)]) {
      [self.delegate simplePing:self
                  didSendPacket:packet
                 sequenceNumber:self.nextSequenceNumber];
    }
  } else {
    NSError *error;

    if (err == 0) {
      err = ENOBUFS; // This is not a hugely helpful error for a short write,
                     // but we'll go with it.
    }
    error = SimplePingErrorForErrno(err);
    if ((self.delegate != nil) &&
        [self.delegate respondsToSelector:@selector
                       (simplePing:
                           didFailToSendPacket:sequenceNumber:error:)]) {
      [self.delegate simplePing:self
            didFailToSendPacket:packet
                 sequenceNumber:self.nextSequenceNumber
                          error:error];
    }
  }

  self.nextSequenceNumber += 1;
}

/*! Calculates the on-the-wire checksum.
 *  \details Calculates the standard 16-bit one's complement checksum.
 *  \param packet The data to checksum.
 *  \returns The checksum.
 */

+ (uint16_t)icmpInPacket:(NSData *)packet {
  // Returns the standard 16-bit one's complement checksum.
  const uint16_t *buffer;
  size_t bufferLen;

  buffer = packet.bytes;
  bufferLen = packet.length;

  uint32_t checksum = 0;
  while (bufferLen > 1) {
    checksum += *buffer++;
    bufferLen -= 2;
  }
  if (bufferLen == 1) {
    checksum += *(const uint8_t *)buffer;
  }
  checksum = (checksum >> 16) + (checksum & 0xFFFF);
  checksum += (checksum >> 16);
  return ~checksum;
}

/*! Reads data from the socket.
 *  \details Called by the socket handling code (SocketReadCallback) to process
 * data read from the socket.
 */

- (void)readData {
  int err;
  struct sockaddr_storage addr;
  socklen_t addrLen;
  ssize_t bytesRead;
  void *buffer;
  enum { kBufferSize = 65535 };

  // 65535 is the maximum IP packet size, which seems like a reasonable bound
  // here (plus it's what <netinet/ip_icmp.h> uses).

  buffer = malloc(kBufferSize);
  assert(buffer != NULL);

  // Actually read the data.

  addrLen = sizeof(addr);
  bytesRead = recvfrom(CFSocketGetNative(self.socket), buffer, kBufferSize, 0,
                       (struct sockaddr *)&addr, &addrLen);
  err = 0;
  if (bytesRead < 0) {
    err = errno;
  }

  // Process the data we read.

  if (bytesRead > 0) {
    NSMutableData *packet;

    packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger)bytesRead];
    assert(packet != nil);

    // We got some data, pass it up to our client.

    if ([self validatePingResponsePacket:packet
                          sequenceNumber:&self->_nextSequenceNumber]) {
      if ((self.delegate != nil) &&
          [self.delegate respondsToSelector:@selector
                         (simplePing:
                             didReceivePingResponsePacket:sequenceNumber:)]) {
        [self.delegate simplePing:self
            didReceivePingResponsePacket:packet
                          sequenceNumber:self.nextSequenceNumber];
      }
    } else {
      if ((self.delegate != nil) &&
          [self.delegate respondsToSelector:@selector(simplePing:
                                                didReceiveUnexpectedPacket:)]) {
        [self.delegate simplePing:self didReceiveUnexpectedPacket:packet];
      }
    }
  } else {
    // We failed to read the data, so shut everything down.

    if (err == 0) {
      err = EPIPE;
    }
    [self didFailWithError:SimplePingErrorForErrno(err)];
  }

  free(buffer);

  // Note that we don't loop back trying to read more data.  Rather, we just
  // let CFSocket call us again.
}

/*! Checks whether the incoming packet looks like a ping response.
 *  \details This routine is the core of the packet matching logic.
 *  \param packet The packet that was received.
 *  \param sequenceNumberPtr A pointer to a place to start the sequence number.
 *  \returns YES if the packet looks like a reasonable ping response.
 */

- (BOOL)validatePingResponsePacket:(NSMutableData *)packet
                    sequenceNumber:(uint16_t *)sequenceNumberPtr {
  BOOL result;
  const ICMPHeader *icmpPtr;
  NSRange icmpHeaderRange;

  result = NO;

  // For IPv6 we let the kernel do all the heavy lifting.

  if (self.hostAddressFamily == AF_INET6) {

    // The packet we received is an ICMP6 packet, but we don't know if it's an
    // echo reply.  So we check the header.

    if (packet.length >= sizeof(*icmpPtr)) {
      icmpPtr = packet.bytes;
      if ((icmpPtr->type == ICMPv6TypeEchoReply) && (icmpPtr->code == 0)) {
        if (CFSwapInt16BigToHost(icmpPtr->identifier) == self.identifier) {
          if (sequenceNumberPtr != NULL) {
            *sequenceNumberPtr = CFSwapInt16BigToHost(icmpPtr->sequenceNumber);
          }
          result = YES;
        }
      }
    }
  } else {

    // For IPv4 the kernel doesn't strip the IP header, so we have to do it
    // ourselves.

    NSUInteger ipHeaderLength;

    if (packet.length >= 20) {
      ipHeaderLength = (((const uint8_t *)packet.bytes)[0] & 0x0F) * 4;
      if (packet.length >= (ipHeaderLength + sizeof(*icmpPtr))) {
        icmpHeaderRange = NSMakeRange(ipHeaderLength, sizeof(*icmpPtr));
        icmpPtr = (const ICMPHeader *)(((const uint8_t *)packet.bytes) +
                                       ipHeaderLength);

        if ((icmpPtr->type == ICMPv4TypeEchoReply) && (icmpPtr->code == 0)) {
          if (CFSwapInt16BigToHost(icmpPtr->identifier) == self.identifier) {
            if (sequenceNumberPtr != NULL) {
              *sequenceNumberPtr =
                  CFSwapInt16BigToHost(icmpPtr->sequenceNumber);
            }
            result = YES;
          }
        }
      }
    }
  }

  return result;
}

/*! Called when the object fails.
 *  \details Stops the object and calls the delegate.
 *  \param error Describes the failure.
 */

- (void)didFailWithError:(NSError *)error {
  assert(error != nil);

  [self stop];
  if ((self.delegate != nil) &&
      [self.delegate respondsToSelector:@selector(simplePing:
                                            didFailWithError:)]) {
    [self.delegate simplePing:self didFailWithError:error];
  }
}

/*! Called when the name-to-address resolution fails.
 *  \details Stops the object and calls the delegate.
 *  \param streamError Describes the failure.
 */

- (void)didFailWithHostStreamError:(CFStreamError)streamError {
  NSDictionary *userInfo;
  NSError *error;

  if (streamError.domain == kCFStreamErrorDomainNetDB) {
    userInfo = @{(id)kCFGetAddrInfoFailureKey : @(streamError.error)};
  } else {
    userInfo = nil;
  }
  error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                              code:kCFHostErrorUnknown
                          userInfo:userInfo];
  assert(error != nil);

  [self didFailWithError:error];
}

@end
