#include <Godot.hpp>
#include <Reference.hpp>
#include <windows.h>

namespace godot {

class Win32Helper : public Reference {
    GODOT_CLASS(Win32Helper, Reference)

public:
    static void _register_methods() {
        register_method("get_work_area_for_point", &Win32Helper::get_work_area_for_point);
    }

    void _init() {}

    // Returns the taskbar-aware work area of the monitor containing (x, y)
    Rect2 get_work_area_for_point(int x, int y) {
        POINT pt = { x, y };
        HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
        MONITORINFO info = {};
        info.cbSize = sizeof(MONITORINFO);
        if (GetMonitorInfoW(monitor, &info)) {
            real_t rx = static_cast<real_t>(info.rcWork.left);
            real_t ry = static_cast<real_t>(info.rcWork.top);
            real_t rw = static_cast<real_t>(info.rcWork.right - info.rcWork.left);
            real_t rh = static_cast<real_t>(info.rcWork.bottom - info.rcWork.top);
            return Rect2(rx, ry, rw, rh);
        }

        // Fallback: return empty Rect2 if Win32 call fails
        return Rect2();
    }
};

} // namespace

// Explicitly define the export macro so MSVC knows what to do with it, else I get syntax errors, missing type specifiers, etc.
#ifdef _WIN32
#define WIN32_EXPORT __declspec(dllexport)
#else
#define WIN32_EXPORT
#endif

// Notice how WIN32_EXPORT is placed BEFORE 'void'
extern "C" WIN32_EXPORT void godot_gdnative_init(godot_gdnative_init_options *o) {
    godot::Godot::gdnative_init(o);
}

extern "C" WIN32_EXPORT void godot_gdnative_terminate(godot_gdnative_terminate_options *o) {
    godot::Godot::gdnative_terminate(o);
}

extern "C" WIN32_EXPORT void godot_nativescript_init(void *handle) {
    godot::Godot::nativescript_init(handle);
    godot::register_class<godot::Win32Helper>();
}