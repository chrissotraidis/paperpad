#pragma once
#include <algorithm>
namespace paperpad::boat {
inline int automatic_scale(int pixelWidth,int pixelHeight,bool fill) {
    if(pixelWidth<=0 || pixelHeight<=0)return 2;
    const int fit=fill ? pixelHeight/240 : std::min(pixelWidth/320,pixelHeight/240);
    return std::clamp(fit,1,4);
}
}
