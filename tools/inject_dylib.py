#!/usr/bin/env python3
import os
import sys
import struct
import zipfile
import shutil

MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA

LC_LOAD_DYLIB = 0x0C
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_REQ_DYLD = 0x80000000

def patch_macho_64(data, dylib_path):
    if len(data) < 32:
        raise ValueError("File too small to be Mach-O 64-bit")

    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack("<IIIIIIII", data[:32])

    if magic != MH_MAGIC_64:
        raise ValueError(f"Not a Mach-O 64-bit binary (magic: {hex(magic)})")

    # Check if dylib is already injected
    dylib_bytes = dylib_path.encode('utf-8') + b'\x00'
    if dylib_bytes in data[:32 + sizeofcmds]:
        print(f"[*] Dylib {dylib_path} is already injected.")
        return data

    # Construct LC_LOAD_DYLIB command
    # struct dylib_command {
    #     uint32_t cmd;
    #     uint32_t cmdsize;
    #     struct dylib {
    #         union lc_str name; // offset 24
    #         uint32_t timestamp;
    #         uint32_t current_version;
    #         uint32_t compatibility_version;
    #     } dylib;
    # };
    header_size = 24
    raw_size = header_size + len(dylib_bytes)
    cmdsize = ((raw_size + 7) // 8) * 8 # Pad to 8 bytes boundary
    padding = b'\x00' * (cmdsize - raw_size)

    lc_data = struct.pack("<IIIIII", LC_LOAD_DYLIB, cmdsize, 24, 2, 0x00010000, 0x00010000) + dylib_bytes + padding

    lc_end = 32 + sizeofcmds

    # Check if space is available before section/data begins
    free_space = data[lc_end:lc_end + cmdsize]
    if any(b != 0 for b in free_space):
        print("[!] Warning: Load command space contains non-zero bytes. Searching for zero padding...")
        # Check padding length
        pad_len = 0
        for b in data[lc_end:]:
            if b == 0:
                pad_len += 1
            else:
                break
        if pad_len < cmdsize:
            raise RuntimeError(f"Not enough header space to insert load command ({pad_len} < {cmdsize})")

    # Insert load command
    new_data = bytearray(data)
    new_data[lc_end:lc_end + cmdsize] = lc_data

    # Update header: ncmds += 1, sizeofcmds += cmdsize
    new_ncmds = ncmds + 1
    new_sizeofcmds = sizeofcmds + cmdsize
    struct.pack_into("<II", new_data, 16, new_ncmds, new_sizeofcmds)

    print(f"[+] Successfully injected LC_LOAD_DYLIB command for {dylib_path} (ncmds: {ncmds} -> {new_ncmds})")
    return bytes(new_data)

def inject_ipa(ipa_path, dylib_file_path, output_ipa_path, dylib_install_name="@executable_path/Frameworks/libsubsystem.dylib"):
    print(f"[*] Extracting IPA: {ipa_path}")
    work_dir = "temp_ipa_extract"
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)

    os.makedirs(work_dir)

    with zipfile.ZipFile(ipa_path, 'r') as zip_ref:
        zip_ref.extractall(work_dir)

    payload_dir = os.path.join(work_dir, "Payload")
    if not os.path.exists(payload_dir):
        raise FileNotFoundError("Payload directory not found in IPA")

    app_name = None
    for item in os.listdir(payload_dir):
        if item.endswith(".app"):
            app_name = item
            break

    if not app_name:
        raise FileNotFoundError("No .app directory found in Payload")

    app_dir = os.path.join(payload_dir, app_name)
    exec_name = os.path.splitext(app_name)[0]
    exec_path = os.path.join(app_dir, exec_name)

    if not os.path.exists(exec_path):
        # Read Info.plist to find executable name if it differs from app name
        info_plist_path = os.path.join(app_dir, "Info.plist")
        if os.path.exists(info_plist_path):
            with open(info_plist_path, 'rb') as f:
                content = f.read()
                # Basic string search for CFBundleExecutable
                idx = content.find(b'CFBundleExecutable')
                if idx != -1:
                    # extract string value
                    sub = content[idx:idx+200]
                    parts = sub.split(b'<string>')
                    if len(parts) > 1:
                        val = parts[1].split(b'</string>')[0].decode('utf-8', errors='ignore')
                        exec_path = os.path.join(app_dir, val)

    print(f"[*] App executable found at: {exec_path}")

    # Copy dylib into App Frameworks folder
    frameworks_dir = os.path.join(app_dir, "Frameworks")
    os.makedirs(frameworks_dir, exist_ok=True)

    dylib_filename = os.path.basename(dylib_install_name)
    target_dylib_path = os.path.join(frameworks_dir, dylib_filename)
    shutil.copyfile(dylib_file_path, target_dylib_path)
    print(f"[+] Copied dylib to {target_dylib_path}")

    # Patch binary
    with open(exec_path, "rb") as f:
        binary_data = f.read()

    # Check for Fat binary magic
    magic = struct.unpack("<I", binary_data[:4])[0]
    if magic in (FAT_MAGIC, FAT_CIGAM):
        print("[*] Universal/Fat binary detected. Patching 64-bit slice...")
        nfat = struct.unpack(">I", binary_data[4:8])[0]
        offset_64 = 0
        size_64 = 0
        for i in range(nfat):
            cputype, cpusub, off, sz, align = struct.unpack(">IIIII", binary_data[12 + i*20 : 32 + i*20])
            if cputype == 0x0100000C: # CPU_TYPE_ARM64
                offset_64 = off
                size_64 = sz
                break
        if offset_64 > 0:
            slice_data = binary_data[offset_64 : offset_64 + size_64]
            patched_slice = patch_macho_64(slice_data, dylib_install_name)
            binary_data = binary_data[:offset_64] + patched_slice + binary_data[offset_64 + len(patched_slice):]
        else:
            raise ValueError("Could not find ARM64 slice in Fat binary")
    else:
        binary_data = patch_macho_64(binary_data, dylib_install_name)

    with open(exec_path, "wb") as f:
        f.write(binary_data)

    print(f"[+] Patched executable binary: {exec_path}")

    # Re-zip IPA
    print(f"[*] Creating injected IPA at: {output_ipa_path}")
    zip_base = output_ipa_path[:-4] if output_ipa_path.lower().endswith(".ipa") else output_ipa_path
    zip_out = zip_base + ".zip"
    if os.path.exists(output_ipa_path):
        os.remove(output_ipa_path)
    if os.path.exists(zip_out):
        os.remove(zip_out)

    shutil.make_archive(zip_base, 'zip', work_dir)
    os.replace(zip_out, output_ipa_path)

    # Clean up temp
    shutil.rmtree(work_dir)
    print(f"[SUCCESS] Injected IPA created: {output_ipa_path}")


if __name__ == "__main__":
    import traceback
    if len(sys.argv) < 4:
        print("Usage: python inject_dylib.py <input.ipa> <library.dylib> <output.ipa> [dylib_install_path]")
        sys.exit(1)

    ipa_in = sys.argv[1]
    dylib_in = sys.argv[2]
    ipa_out = sys.argv[3]
    install_path = sys.argv[4] if len(sys.argv) > 4 else "@executable_path/Frameworks/libsubsystem.dylib"

    try:
        inject_ipa(ipa_in, dylib_in, ipa_out, install_path)
    except Exception as e:
        print(f"[ERROR] Injection failed: {e}")
        traceback.print_exc()
        sys.exit(1)

