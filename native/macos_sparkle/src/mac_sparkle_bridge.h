#ifndef OTHER_GODS_MAC_SPARKLE_BRIDGE_H
#define OTHER_GODS_MAC_SPARKLE_BRIDGE_H

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class MacSparkleBridge : public RefCounted {
    GDCLASS(MacSparkleBridge, RefCounted)

protected:
    static void _bind_methods();

public:
    MacSparkleBridge();
    void check_for_updates();
};

}  // namespace godot

#endif
