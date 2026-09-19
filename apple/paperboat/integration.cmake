if(NOT IOS)
    message(FATAL_ERROR "PaperPad's native PaperBoat shell currently targets iOS and Simulator")
endif()
target_compile_definitions(${PROJECT_NAME} PRIVATE PAPERPAD_APP=1 PAPERPAD_RELEASE_BUILD=1)
target_sources(${PROJECT_NAME} PRIVATE
    "${PAPERPAD_APP_ROOT}/apple/app/ios_main.mm"
    "${PAPERPAD_APP_ROOT}/apple/app/rom_setup.mm"
    "${PAPERPAD_APP_ROOT}/apple/app/diagnostics.mm"
    "${PAPERPAD_APP_ROOT}/apple/paperboat/bridge.mm"
    "${PAPERPAD_APP_ROOT}/src/controller_slots.cpp")
set_source_files_properties("${PAPERPAD_APP_ROOT}/apple/app/ios_main.mm" PROPERTIES COMPILE_OPTIONS "-fno-objc-arc")
target_include_directories(${PROJECT_NAME} PRIVATE "${PAPERPAD_APP_ROOT}/src" "${PAPERPAD_APP_ROOT}/apple/app")
set(EXECUTABLE_NAME Paperboat)
configure_file("${PAPERPAD_APP_ROOT}/apple/paperboat/Info.plist.in" "${CMAKE_BINARY_DIR}/PaperPadBoat.plist" @ONLY)
set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_BINARY_DIR}/PaperPadBoat.plist"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.chrissotraidis.paperpad.boat")
target_link_libraries(${PROJECT_NAME} PRIVATE "-framework UIKit" "-framework UniformTypeIdentifiers")
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PAPERPAD_APP_ROOT}/apple/app/PrivacyInfo.xcprivacy" "$<TARGET_BUNDLE_CONTENT_DIR:${PROJECT_NAME}>/PrivacyInfo.xcprivacy")

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PAPERPAD_APP_ROOT}/apple/paperboat/ThirdPartyNotices.txt" "$<TARGET_BUNDLE_CONTENT_DIR:${PROJECT_NAME}>/ThirdPartyNotices.txt")

file(DOWNLOAD "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/5a12daa568d19344f9b6e9286ef5929833b25c7c/gamecontrollerdb.txt"
    "${CMAKE_BINARY_DIR}/gamecontrollerdb.txt"
    EXPECTED_HASH SHA256=07ec5b753e685c4829987919b27905cc3c45c8e18c11b3046e275fcf38b0f3cb)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_BINARY_DIR}/gamecontrollerdb.txt" "$<TARGET_BUNDLE_CONTENT_DIR:${PROJECT_NAME}>/gamecontrollerdb.txt")

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PAPERPAD_APP_ROOT}/apple/app/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" "$<TARGET_BUNDLE_CONTENT_DIR:${PROJECT_NAME}>/Icon.png")
