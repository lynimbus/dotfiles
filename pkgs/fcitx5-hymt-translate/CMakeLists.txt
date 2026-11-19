cmake_minimum_required(VERSION 3.16)
project(fcitx5-hymt-translate VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)
include(CTest)

find_package(Fcitx5Core 5.1.0 REQUIRED)
find_package(Fcitx5Utils 5.1.0 REQUIRED)
find_package(Fcitx5Config 5.1.0 REQUIRED)
find_package(CURL REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(Threads REQUIRED)

include("${Fcitx5Utils_DIR}/Fcitx5CompilerSettings.cmake")

add_library(hymt_translator_core STATIC
    src/translator.cpp
)
target_include_directories(hymt_translator_core PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_link_libraries(hymt_translator_core PUBLIC
    CURL::libcurl
    nlohmann_json::nlohmann_json
)
set_target_properties(hymt_translator_core PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

add_library(hymttranslate MODULE
    src/hymttranslate.cpp
)
set_target_properties(hymttranslate PROPERTIES
    PREFIX "lib"
)
target_link_libraries(hymttranslate PRIVATE
    hymt_translator_core
    Fcitx5::Core
    Fcitx5::Utils
    Fcitx5::Config
    Threads::Threads
)

configure_file(
    src/hymttranslate.conf.in
    "${CMAKE_CURRENT_BINARY_DIR}/hymttranslate.conf"
    @ONLY
)

install(TARGETS hymttranslate
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/fcitx5"
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/hymttranslate.conf"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/fcitx5/addon"
)

if(BUILD_TESTING)
    add_executable(test_translator
        tests/test_translator.cpp
    )
    target_link_libraries(test_translator PRIVATE
        hymt_translator_core
    )
    add_test(NAME test_translator COMMAND test_translator)
endif()
