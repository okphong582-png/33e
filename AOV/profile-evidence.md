# Profile Liên Quân VN 1.64.1.7

Nguồn tại máy: `AOV/com.garena.game.kgvn_1.64.1.7_und3fined.ipa`, `AOV/dump (2).cs`. UnityFramework có `cryptid=0`, SHA256 `53a8c9cde76592e55b87db19ab47992a8bac4377e350cee4c9cfad59aa87655d`. Địa chỉ dưới đây là VM RVA iOS, __TEXT vmaddr=0; runtime cộng header base/ASLR.

| Dữ liệu | Đối chiếu native iOS |
| --- | --- |
| KyriosFramework singleton | `get_actorManager 0x6e5368c` và `get_hostLogic 0x6e535c4` đọc MethodInfo slot `0xd1082b0`; `MonoSingleton.HasInstance 0x214f264` đọc MethodInfo+0x20 → class+0xc0 → rgctx+0x10 → class+0xb8 → static instance |
| ActorManager / HostLogic | fallback `0x6e5371c` đọc framework+0x28; `0x6e53654` đọc framework+0x50 |
| Phe của người chơi | `VHostLogic.get_hostPlayerCamp 0x6e62670`: host+0x8 → player+0x30 |
| Tướng / quái | `GetAllHeros 0x70073b0` đọc manager+0x20; `GetAllMonsters 0x7007530` đọc manager+0x48 |
| Pool handle | dump `PoolObjHandle<T>`: sequence+0, object+8, stride16; `PooledClassObjectBase.usingSeq` object+8. Không dùng pointer ở đầu handle |
| List / array | dump runtime tùy biến có object header8: items+8, size+0x10, version+0x14; array length+0x10, data+0x18 |
| Vị trí | `ActorLinker.get_location 0x6fe9068` đọc Int3+0x18c; `VInt3.Precision=1000` |
| Phe / loại actor | `get_objCamp 0x6fe9b0c` đọc +0x22c; `get_objType 0x6fe9b6c` đọc +0x228. Hero=0, Monster=1 |
| Máu | `ValueLinkerComponent.get_actorHp 0x702543c` đọc +0x40; `get_actorHpTotal 0x702544c` đọc +0x44; ActorLinker.ValueComponent+0x28 |
| Bùa xanh | Native `0x6ff7d40` lấy byte loại actor từ config+0x6c, `0x6ff7d44` ghi actorSubType+0x488; enum AovNewPB.ActorTypeSub.ActorSubBlueba=14; fallback SoldierType+0x408 (ActorStaticData+0x2a0, MonsterOnlyInfo+0x160, SoldierType+8), RES_SOLDIER_TYPE_BLUEBA=10 / SHARE_BLUEBA=50. Không gán ID quái phỏng đoán |
| CameraSystem singleton | caller `0x5166cbc` gọi generic get_Instance `0x214dcfc` với MethodInfo slot `0xd108160`, cùng chuỗi static instance |
| MainCamera | `CameraSystem.get_MainCamera 0x540e42c`: +0x108 |
| Unity camera native pointer | native icall worldToCameraMatrix `0xa4478f8`, projectionMatrix `0xa447970` đều đọc managed camera+8 |
| View matrix | native `0xaabe50c` cập nhật và trả camera native+0x80 |
| Projection matrix | native `0xaabbb88` cập nhật và trả camera native+0xc0 |
| Moba camera | CameraSystem field registration: MobaCamera+0x18; `UpdateCameraState 0x540da00` đọc +0x18 và gọi `set_currentZoomRate 0x550e4f0` |
| Zoom gốc/bổ sung | Moba_Camera field registration: `_currentZoomAmount`+0x90, `_additionZoomAmount`+0x94, `changeInCamera`+0xdc, HasStarted+0xe4. `set_additionZoomAmount 0x550e3f8` ghi float+0x94 và byte1+0xdc |
| Khoảng cách thực | `GetCameraOffsetLocalPosition 0x5511558`: đọc +0x90 và +0x94, cộng hai số rồi nhân vector hướng và rates+0x98/+0x9c. `CalculateCameraUpdates 0x5510b40` yêu cầu dirty+0xdc, cập nhật camera transform rồi xóa dirty tại `0x5510ecc` |

Đối chiếu thêm `Il2CppMetadataRegistration`: field-offset count tại `0xc98aae0` = 34451, bảng pointer `0xcf47270`. Field-offset records của KyriosFramework (type2161), VHostLogic (2150), ActorManager (2607), ActorLinker (2598), ValueLinkerComponent (2625), CameraSystem (465), PooledClassObjectBase (33659) khớp các field đọc ở trên. Offset struct trong bảng này bao gồm header boxed 8 byte; ActorStaticData.TheMonsterOnlyInfo = 0x168 boxed → 0x160 unboxed.

Game methods chính nằm trong `Project_d.dll`; Unity methods trong `UnityEngine.CoreModule.dll`. Dump RVA 0x7D… của Android không được chuyển trực tiếp sang iOS. Test giả lập xác nhận bộ lọc và biên đọc; dữ liệu game đang chạy và HUD cần thử nghiệm trên thiết bị.

Cam xa dùng công thức `addition = (currentZoomAmount + originalAddition) * multiplier - currentZoomAmount`. Mức 1.0× trả lại originalAddition, không chỉnh giới hạn zoom gốc trong settings. Trước khi ghi kiểm tra HasStarted, float hữu hạn, dirty hợp lệ, singleton và native camera pointer; phiên/cảnh thay đổi sẽ bỏ địa chỉ cũ. Kiểm tra fake memory bao phủ mức 1–4×, không nhân chồng, khôi phục, thay đổi từ game, quyền ghi và rollback khi không ghi được dirty flag.
