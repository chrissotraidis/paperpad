#include <nlohmann/json.hpp>
#include <memory>
#include <cassert>
#include <filesystem>
#include <iostream>
#include <unistd.h>
#include "save/AtomicSaveFile.h"
#include <libultraship.h>
extern "C" {
#include "dx/versioning.h"
}
SaveData* ConvertJSON_to_SaveData(nlohmann::json);
nlohmann::ordered_json ConvertSaveData_to_JSON(SaveData*);
int main() {
    SaveData input{};
    strcpy(input.magicString,"Mario Story 006");
    strcpy(input.modName,"codec-test");
    input.saveSlot=2;input.saveCount=71;input.player.curHP=7;
    input.player.curMaxHP=25;input.player.coins=123;
    for(int i=0;i<12;++i){input.player.partnerUnlockedTime[i]=100+i;input.player.partnerUsedTime[i]=900+i;}
    auto original=ConvertSaveData_to_JSON(&input);
    std::unique_ptr<SaveData> restored(ConvertJSON_to_SaveData(original));
    assert(restored->player.partnerUnlockedTime[4]==104);
    assert(restored->player.partnerUsedTime[4]==904);
    assert(ConvertSaveData_to_JSON(restored.get())==original);
    auto corrupt=original;corrupt["player"]["partnerUsedTime"]="bad";
    bool rejected=false;try{std::unique_ptr<SaveData> bad(ConvertJSON_to_SaveData(corrupt));}catch(...){rejected=true;}
    assert(rejected);
    char temporary[]="/tmp/paperpad-save-test.XXXXXX";assert(mkdtemp(temporary));
    std::filesystem::path root(temporary),path=root/"file2.json";
    PaperBoatSave::AtomicWrite(path,original.dump());
    PaperBoatSave::AtomicWrite(path.string()+".bak",PaperBoatSave::Read(path));
    PaperBoatSave::AtomicWrite(path,"broken");
    assert(nlohmann::json::parse(PaperBoatSave::Read(path.string()+".bak"))==original);
    PaperBoatSave::AtomicWrite(path,original.dump());
    assert(nlohmann::json::parse(PaperBoatSave::Read(path))==original);
    assert(!std::filesystem::exists(path.string()+".tmp"));
    std::filesystem::remove_all(root);
    std::cout<<"PaperBoat real save codec: distinct partner arrays, complete JSON round-trip, malformed field rejection, atomic replacement and backup retention passed.\n";
}
