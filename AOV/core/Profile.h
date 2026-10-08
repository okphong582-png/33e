#pragma once
#include <cstdint>
#include <array>
namespace aov {
// Liên Quân VN 1.64.1.7, decrypted ARM64 UnityFramework. Never use dump Android RVAs.
inline constexpr std::array<uint8_t,16> uuid = {0xe7,0x3c,0xe9,0x8d,0xa6,0x7a,0x3f,0xd6,0xad,0x83,0xa1,0x6d,0x13,0x98,0x48,0x11};
inline constexpr uint64_t frameworkMethod = 0xd1082b0; // MonoSingleton<KyriosFramework>.HasInstance
inline constexpr uint64_t cameraMethod = 0xd108160; // MonoSingleton<CameraSystem>.get_Instance
inline constexpr uint64_t methodContext = 0x20, classContext = 0xc0, contextClass = 0x10, staticFields = 0xb8;
inline constexpr uint64_t actorManager = 0x28, hostLogic = 0x50;
inline constexpr uint64_t hostPlayer = 0x8, playerCamp = 0x30;
inline constexpr uint64_t heroes = 0x20, monsters = 0x48;
inline constexpr uint64_t listItems = 0x8, listSize = 0x10, listVersion = 0x14;
inline constexpr uint64_t arrayLength = 0x10, arrayData = 0x18;
inline constexpr uint64_t actorSequence = 0x8, actorLocation = 0x18c, actorValues = 0x28;
inline constexpr uint64_t actorConfig = 0x218, actorType = 0x228, actorCamp = 0x22c;
inline constexpr uint64_t actorSubType = 0x488, soldierType = 0x408; // TheStaticData.MonsterOnlyInfo.SoldierType
inline constexpr uint64_t health = 0x40, maxHealth = 0x44;
inline constexpr uint64_t mainCamera = 0x108, nativeCamera = 0x8, viewMatrix = 0x80, projectionMatrix = 0xc0;
inline constexpr uint64_t mobaCamera = 0x18, cameraZoomAmount = 0x90, cameraAdditionZoom = 0x94;
inline constexpr uint64_t cameraDirty = 0xdc, cameraStarted = 0xe4;
inline constexpr int blueSubType = 14, blueSoldierType = 10, sharedBlueSoldierType = 50;
}
