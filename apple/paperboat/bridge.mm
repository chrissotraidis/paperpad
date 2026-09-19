// PaperPad's native Apple shell over the pinned PaperBoat engine.
#include "paperpad_input.h"
#include "controller_slots.h"
#include "input_mapping.h"
#include <array>
#include <SDL.h>
#include <SDL_syswm.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <libultraship.h>
#include <fast/Fast3dWindow.h>
#include <fast/interpreter.h>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <thread>
#include <unistd.h>
#include <filesystem>
#include <zip.h>
#include "extractor/GameExtractor.h"
extern "C" int paperpad_boat_main(int, char**);
extern "C" void paperpad_touch_attach(void*);
extern "C" void paperpad_touch_snapshot(uint16_t*, float*, float*);
namespace {
std::atomic<float> volume{1};
std::atomic<int> resolution{0}, aspect{0};
std::atomic<bool> settingsChanged{true}, active{true}, modal{false}, running{false};
std::atomic<uint64_t> lastFrame{0};
std::atomic<uint32_t> renderWidth{0}, renderHeight{0};
class Backend final : public paperpad::input::ControllerBackend {
public:
 std::vector<paperpad::input::EnumeratedController> enumerate() override {
  std::vector<paperpad::input::EnumeratedController> result;
  for(int i=0;i<SDL_NumJoysticks();++i) if(SDL_IsGameController(i)) result.push_back({i,SDL_JoystickGetDeviceInstanceID(i)});
  return result;
 }
 void* open(int i) override {return SDL_GameControllerOpen(i);}
 void close(void* p) override {SDL_GameControllerClose(static_cast<SDL_GameController*>(p));}
 bool connected(void* p) const override {return SDL_GameControllerGetAttached(static_cast<SDL_GameController*>(p));}
 int32_t instance_id(void* p) const override {return SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(static_cast<SDL_GameController*>(p)));}
} backend;
paperpad::input::ControllerSlots slots;
std::array<std::atomic<uint8_t>,18> keyTaps{};
int eventWatch(void*,SDL_Event* e) {
 if(e->type==SDL_KEYDOWN && !e->key.repeat && active.load() && !modal.load())
  for(size_t i=0;i<18;++i)if(paperpad::boat::keys[i].key==e->key.keysym.scancode)keyTaps[i].store(4);

 if(e->type==SDL_APP_WILLENTERBACKGROUND || e->type==SDL_APP_WILLENTERFOREGROUND || e->type==SDL_APP_DIDENTERFOREGROUND) {
  active.store(e->type==SDL_APP_DIDENTERFOREGROUND);
  std::fprintf(stderr,"[paperpad-boat] lifecycle event=%u active=%d\n",e->type,int(active.load()));
 }
 return 1;
}
float axis(SDL_GameController* c, SDL_GameControllerAxis a) {
 const int value=SDL_GameControllerGetAxis(c,a);
 return paperpad::boat::normalize_axis(value);
}
}
extern "C" void PaperPadBoat_SetInputSuspended(int value) {modal.store(value!=0);}
extern "C" void PaperPad_SetAudioVolume(float v) {volume.store(std::clamp(v,0.f,1.f));settingsChanged.store(true);}
extern "C" void PaperPad_SetGraphicsConfig(int r,int a,int) {resolution.store(std::clamp(r,0,4));aspect.store(a);settingsChanged.store(true);}
extern "C" int PaperPad_GetEffectiveRenderState(uint32_t* scale,uint32_t* w,uint32_t* h) {
 auto width=renderWidth.load(),height=renderHeight.load();
 if(scale)*scale=height*1000/240;if(w)*w=width;if(h)*h=height;
 return width>0 && height>0;
}
extern "C" void PaperPadBoat_Ready() {
 SDL_AddEventWatch(eventWatch,nullptr);
 CVarSetInteger("gTouchControls.Enabled",0);
 CVarSetInteger("gSettings.OpenMenuBar",0);
 CVarSetInteger("gOpenWindows.ControllerDisconnected",0);
 if(SDL_Window* window=SDL_GetKeyboardFocus()?SDL_GetKeyboardFocus():SDL_GetWindowFromID(1)) {
  SDL_SysWMinfo info{};SDL_VERSION(&info.version);
  if(SDL_GetWindowWMInfo(window,&info)) paperpad_touch_attach((__bridge void*)info.info.uikit.window);
 }
 std::fprintf(stderr,"[paperpad-boat] native controls attached; game initialized; private JSON saves isolated from Original\n");
}
extern "C" void PaperPadBoat_Frame() {
 const uint64_t now=SDL_GetTicks64();lastFrame.store(now);
 if(settingsChanged.exchange(false)) {
  CVarSetInteger("gSettings.Volume.Master",std::lround(volume.load()*100));
  CVarSetInteger("gSettings.AdvancedResolution.Enabled",1);
  CVarSetFloat("gSettings.AdvancedResolution.AspectRatioX",aspect.load()==0?4.f:0.f);
  CVarSetFloat("gSettings.AdvancedResolution.AspectRatioY",aspect.load()==0?3.f:0.f);
  CVarSetInteger("gSettings.AdvancedResolution.VerticalResolutionToggle",resolution.load()!=0);
  CVarSetInteger("gSettings.AdvancedResolution.VerticalPixelCount",240*std::max(resolution.load(),1));
  CVarSetFloat("gSettings.InternalResolution",1.f);
  std::fprintf(stderr,"[paperpad-boat] settings volume=%.2f resolution=%d aspect=%d\n",volume.load(),resolution.load(),aspect.load());
 }
 auto window=std::dynamic_pointer_cast<Fast::Fast3dWindow>(Ship::Context::GetRawInstance()->GetWindow());
 if(auto interpreter=window->GetInterpreterWeak().lock()) {
  uint32_t w=0,h=0;interpreter->GetCurDimensions(&w,&h);renderWidth.store(w);renderHeight.store(h);
 }
 static uint64_t nextReport=0,frames=0;++frames;
 if(now>=nextReport){std::fprintf(stderr,"[paperpad-boat] frame=%llu runtime_ms=%llu render=%ux%u controllers=%zu\n",frames,now,renderWidth.load(),renderHeight.load(),slots.connected_count());nextReport=now+10000;}
}
extern "C" void PaperPadBoat_ReadController(void* raw) {
 auto* pads=static_cast<OSContPad*>(raw);
 for(int i=0;i<4;++i)pads[i]={};
 for(const auto& change:slots.reconcile(backend))
  std::fprintf(stderr,"[paperpad-boat] controller change=%d player=%d instance=%d\n",int(change.kind),change.player_slot,change.instance_id);
 static int lastConnected=-1;int connected=slots.connected_count()>0;
 if(connected!=lastConnected){PaperPad_SetPhysicalControllerConnected(connected);lastConnected=connected;}
 if(!active.load() || modal.load()){for(auto& tap:keyTaps)tap.store(0);return;}
 float x=0,y=0;uint16_t buttons=0;paperpad_touch_snapshot(&buttons,&x,&y);
 if(auto* c=static_cast<SDL_GameController*>(slots.player_handle(0))) {
  for(auto m:paperpad::boat::buttons)if(SDL_GameControllerGetButton(c,m.button))buttons|=m.mask;
  if(axis(c,SDL_CONTROLLER_AXIS_TRIGGERLEFT)>0.5f)buttons|=0x2000;
  const float rx=axis(c,SDL_CONTROLLER_AXIS_RIGHTX),ry=axis(c,SDL_CONTROLLER_AXIS_RIGHTY);
  if(rx>0.5f)buttons|=0x0001;if(rx<-.5f)buttons|=0x0002;
  if(ry>0.5f)buttons|=0x0004;if(ry<-.5f)buttons|=0x0008;
  const float cx=axis(c,SDL_CONTROLLER_AXIS_LEFTX),cy=-axis(c,SDL_CONTROLLER_AXIS_LEFTY);
  x+=cx;y+=cy;
 }
 const Uint8* keyboard=SDL_GetKeyboardState(nullptr);
 for(size_t i=0;i<18;++i){auto mapping=paperpad::boat::keys[i];auto tap=keyTaps[i].load();
  if(keyboard[mapping.key] || tap){buttons|=mapping.mask;x+=mapping.x;y+=mapping.y;}
  if(tap)keyTaps[i].compare_exchange_strong(tap,tap-1);
 }
 pads[0].button=buttons;pads[0].stick_x=paperpad::boat::n64_axis(x);pads[0].stick_y=paperpad::boat::n64_axis(y);
 static uint16_t previousButtons=0;static int previousX=0,previousY=0;
 int coarseX=(x>.2f)-(x<-.2f),coarseY=(y>.2f)-(y<-.2f);
 if(buttons!=previousButtons || coarseX!=previousX || coarseY!=previousY){
  std::fprintf(stderr,"[paperpad-boat] input buttons=0x%04x stick=%d,%d\n",buttons,coarseX,coarseY);
  previousButtons=buttons;previousX=coarseX;previousY=coarseY;
 }
}
namespace {
bool validArchive(const std::filesystem::path& path) {
    int error=0;zip_t* archive=zip_open(path.c_str(),ZIP_RDONLY|ZIP_CHECKCONS,&error);
    if(!archive)return false;
    const bool nonempty=zip_get_num_entries(archive,0)>0;zip_close(archive);return nonempty;
}
bool prepareAssets(const std::string& root) {
    namespace fs=std::filesystem;
    const fs::path archive=fs::path(root)/"pm64.o2r";
    if(fs::exists(archive) && validArchive(archive))return true;
    if(fs::exists(archive)) {
        fs::rename(archive,archive.string()+".invalid-"+std::to_string(std::chrono::system_clock::now().time_since_epoch().count()));
        std::fprintf(stderr,"[paperpad-boat] invalid game archive preserved; rebuilding from verified ROM\n");
    }
    UIWindow* window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController* controller=[[UIViewController alloc] init];
    controller.view.backgroundColor=[UIColor colorWithRed:0.03 green:0.06 blue:0.13 alpha:1];
    UILabel* label=[[UILabel alloc] init];label.textColor=UIColor.whiteColor;
    label.font=[UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    label.textAlignment=NSTextAlignmentCenter;label.numberOfLines=0;
    label.translatesAutoresizingMaskIntoConstraints=NO;[controller.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[[label.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
      [label.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
      [label.widthAnchor constraintLessThanOrEqualToAnchor:controller.view.widthAnchor multiplier:0.85]]];
    window.rootViewController=controller;window.windowLevel=UIWindowLevelNormal+2;[window makeKeyAndVisible];
    std::atomic<bool> done{false};std::atomic<size_t> count{0},total{0};bool success=false;std::string error;
    const std::string bundle=NSBundle.mainBundle.bundlePath.UTF8String;
    std::thread worker([&]{
        try {
            std::string pattern=root+"/.extract.XXXXXX";std::vector<char> tmp(pattern.begin(),pattern.end());tmp.push_back(0);
            if(!mkdtemp(tmp.data()))throw std::runtime_error("Unable to create extraction workspace");
            fs::path staging(tmp.data());GameExtractor extractor;
            if(!extractor.RunStandalone(root+"/baserom.z64",bundle))throw std::runtime_error("The verified ROM was not recognized by the extractor");
            if(!extractor.GenerateOTRTo(count,total,bundle,staging.string()) || !validArchive(staging/"pm64.o2r"))
                throw std::runtime_error("Game data extraction did not finish; check storage and share diagnostics");
            fs::rename(staging/"pm64.o2r",archive);fs::remove_all(staging);success=true;
        }catch(const std::exception& e){error=e.what();std::fprintf(stderr,"[paperpad-boat] extraction failed: %s\n",e.what());}
        done.store(true);
    });
    std::fprintf(stderr,"[paperpad-boat] extracting verified ROM into private game archive\n");
    while(!done.load()) { @autoreleasepool {
        label.text=total.load() ? [NSString stringWithFormat:@"Preparing game data…\n%zu of %zu",count.load(),total.load()] : @"Preparing game data…\nThis is only needed once.";
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }}
    worker.join();
    if(!success) {
        __block BOOL dismissed=NO;
        UIAlertController* alert=[UIAlertController alertControllerWithTitle:@"Game Setup Failed" message:[NSString stringWithUTF8String:error.c_str()] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction*){dismissed=YES;}]];
        [controller presentViewController:alert animated:YES completion:nil];
        while(!dismissed)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    window.hidden=YES;
    std::fprintf(stderr,"[paperpad-boat] extraction finished success=%d assets=%zu\n",int(success),count.load());
    return success;
}
}
extern "C" int paperpad_recomp_main(int argc,char** argv) {
 // ios_main has entered this app's own Application Support/PaperPad directory.
 const auto root=std::filesystem::current_path().string();
 setenv("SHIP_HOME",root.c_str(),1);
 setenv("SHIP_LOG_STDIO_ONLY","1",1);
 dup2(STDERR_FILENO,STDOUT_FILENO); // Include upstream stdout/spdlog in bounded shared diagnostics.
 std::fprintf(stderr,"[paperpad-boat] engine=PaperBoat build=0.2.0-dev bundle=com.chrissotraidis.paperpad.boat\n");
 if(!prepareAssets(root))return EXIT_FAILURE;
 running.store(true);
 std::thread watchdog([]{uint64_t warned=0;while(running.load()){
  std::this_thread::sleep_for(std::chrono::seconds(1));auto frame=lastFrame.load();
  if(active.load() && !modal.load() && frame && SDL_GetTicks64()>frame+10000 && warned!=frame){
   std::fprintf(stderr,"[paperpad-boat] game_loop_not_advancing idle_ms=%llu\n",SDL_GetTicks64()-frame);warned=frame;
  }
 }});
 int result=EXIT_FAILURE;
 try{result=paperpad_boat_main(argc,argv);}catch(const std::exception& e){std::fprintf(stderr,"[paperpad-boat] fatal: %s\n",e.what());}
 running.store(false);watchdog.join();SDL_DelEventWatch(eventWatch,nullptr);slots.close_all(backend);
 return result;
}

extern "C" void PaperPadBoat_ReportSaveError(const char* message) {
    NSString* text=[NSString stringWithUTF8String:message];
    dispatch_async(dispatch_get_main_queue(), ^{
        static bool showing=false;
        if(showing)return;
        UIWindow* window=nil;
        for(UIScene* scene in UIApplication.sharedApplication.connectedScenes)
            if([scene isKindOfClass:UIWindowScene.class])
                for(UIWindow* candidate in ((UIWindowScene*)scene).windows)if(candidate.isKeyWindow)window=candidate;
        UIViewController* presenter=window.rootViewController;
        while(presenter.presentedViewController)presenter=presenter.presentedViewController;
        if(!presenter)return;
        showing=true;const bool previouslySuspended=modal.exchange(true);
        UIAlertController* alert=[UIAlertController alertControllerWithTitle:@"Save Problem" message:text preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction*){showing=false;modal.store(previouslySuspended);}]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}
