import os
import sys
import zipfile
import shutil
import struct
import traceback

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log_file = os.path.join(base_dir, "inject_v3.log")

with open(log_file, "w", encoding="utf-8") as log:
    log.write("=== STARTING INJECT V3 ===\n")
    try:
        ipa_path = os.path.join(base_dir, "com.dts.freefireth-1.132.1-Decrypted.ipa")
        dylib_file_path = os.path.join(base_dir, "libsubsystem.dylib")
        output_ipa_path = os.path.join(base_dir, "com.dts.freefireth-1.132.1-Injected.ipa")
        dylib_install_name = "@executable_path/Frameworks/libsubsystem.dylib"

        log.write(f"IPA: {ipa_path}\n")
        log.write(f"Dylib: {dylib_file_path}\n")
        log.write(f"Target IPA: {output_ipa_path}\n")

        work_dir = os.path.join(base_dir, "temp_extract_v3")
        if os.path.exists(work_dir):
            shutil.rmtree(work_dir, ignore_errors=True)

        os.makedirs(work_dir, exist_ok=True)
        log.write("Unzipping IPA...\n")
        with zipfile.ZipFile(ipa_path, 'r') as zip_ref:
            zip_ref.extractall(work_dir)

        payload_dir = os.path.join(work_dir, "Payload")
        app_name = None
        for item in os.listdir(payload_dir):
            if item.endswith(".app"):
                app_name = item
                break

        app_dir = os.path.join(payload_dir, app_name)
        exec_name = os.path.splitext(app_name)[0]
        exec_path = os.path.join(app_dir, exec_name)
        log.write(f"Found app exec: {exec_path}\n")

        frameworks_dir = os.path.join(app_dir, "Frameworks")
        os.makedirs(frameworks_dir, exist_ok=True)

        target_dylib_path = os.path.join(frameworks_dir, "libsubsystem.dylib")
        shutil.copyfile(dylib_file_path, target_dylib_path)
        log.write("Copied dylib to Frameworks/libsubsystem.dylib\n")

        with open(exec_path, "rb") as f:
            data = f.read()

        magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack("<IIIIIIII", data[:32])
        log.write(f"Mach-O ncmds: {ncmds}, sizeofcmds: {sizeofcmds}\n")

        dylib_bytes = dylib_install_name.encode('utf-8') + b'\x00'
        header_size = 24
        raw_size = header_size + len(dylib_bytes)
        cmdsize = ((raw_size + 7) // 8) * 8
        padding = b'\x00' * (cmdsize - raw_size)

        lc_data = struct.pack("<IIIIII", 0x0C, cmdsize, 24, 2, 0x00010000, 0x00010000) + dylib_bytes + padding
        lc_end = 32 + sizeofcmds

        new_data = bytearray(data)
        new_data[lc_end:lc_end + cmdsize] = lc_data
        struct.pack_into("<II", new_data, 16, ncmds + 1, sizeofcmds + cmdsize)

        with open(exec_path, "wb") as f:
            f.write(new_data)
        log.write("Patched binary executable successfully\n")

        # Zip creation using zipfile module
        log.write("Creating output IPA archive...\n")
        temp_zip_file = os.path.join(base_dir, "temp_output_v3.zip")
        if os.path.exists(temp_zip_file):
            os.remove(temp_zip_file)

        with zipfile.ZipFile(temp_zip_file, 'w', zipfile.ZIP_DEFLATED) as zip_out:
            for root, dirs, files in os.walk(work_dir):
                for file in files:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, work_dir)
                    zip_out.write(full_path, rel_path)

        log.write("Zip archive created, renaming to .ipa...\n")
        if os.path.exists(output_ipa_path):
            os.remove(output_ipa_path)
        os.replace(temp_zip_file, output_ipa_path)

        shutil.rmtree(work_dir, ignore_errors=True)
        log.write("SUCCESS! CREATED INJECTED IPA AT: " + output_ipa_path + "\n")
    except Exception as e:
        log.write(f"ERROR: {e}\n")
        traceback.print_exc(file=log)
