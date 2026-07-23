#include "include/CHID.h"

void CHIDReleaseClient(IOHIDEventSystemClientRef client) {
    if (client) CFRelease((CFTypeRef)client);
}
