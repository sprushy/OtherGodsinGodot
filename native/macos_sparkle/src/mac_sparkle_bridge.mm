#include "mac_sparkle_bridge.h"

#import <Sparkle/Sparkle.h>

#include <godot_cpp/core/class_db.hpp>

namespace {

SPUStandardUpdaterController *updater_controller = nil;

}  // namespace

namespace godot {

void MacSparkleBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("check_for_updates"), &MacSparkleBridge::check_for_updates);
}

MacSparkleBridge::MacSparkleBridge() {
    if (updater_controller == nil) {
        updater_controller = [[SPUStandardUpdaterController alloc]
            initWithStartingUpdater:YES
                   updaterDelegate:nil
                userDriverDelegate:nil];
    }
}

void MacSparkleBridge::check_for_updates() {
    [updater_controller checkForUpdates:nil];
}

}  // namespace godot
