import os
import sys
import struct
import traceback

debug_file = r"c:\Users\A thuy SG\Desktop\iOSViet1\iOSViet\pipeline_debug.txt"

def main():
    with open(debug_file, "w", encoding="utf-8") as f:
        f.write("Starting run_pipeline main...\n")
        try:
            base_dir = r"c:\Users\A thuy SG\Desktop\iOSViet1"
            project_dir = r"c:\Users\A thuy SG\Desktop\iOSViet1\iOSViet"
            tools_dir = os.path.join(project_dir, "tools")
            packages_dir = os.path.join(project_dir, "packages")

            os.makedirs(packages_dir, exist_ok=True)
            dylib_path = os.path.join(packages_dir, "libsubsystem.dylib")

            if not os.path.exists(dylib_path):
                f.write("Generating dylib header...\n")
                name_str = b'@rpath/libsubsystem.dylib\x00'
                raw_size = 24 + len(name_str)
                cmdsize = ((raw_size + 7) // 8) * 8
                pad = b'\x00' * (cmdsize - raw_size)

                lc_id = struct.pack('<IIIIII', 0x0D, cmdsize, 24, 2, 0x00010000, 0x00010000) + name_str + pad
                hdr = struct.pack('<IIIIIIII', 0xFEEDFACF, 12, 0, 6, 1, len(lc_id), 0x00200085, 0)

                with open(dylib_path, 'wb') as df:
                    df.write(hdr + lc_id)
                f.write(f"Generated dylib header at {dylib_path}\n")

            ipa_in = os.path.join(base_dir, "com.dts.freefireth-1.132.1-Decrypted.ipa")
            ipa_out = os.path.join(packages_dir, "com.dts.freefireth-1.132.1-Injected.ipa")

            f.write(f"IPA Input: {ipa_in}\n")
            f.write(f"IPA Output: {ipa_out}\n")

            sys.path.insert(0, tools_dir)
            import inject_dylib

            f.write("Starting inject_ipa call...\n")
            inject_dylib.inject_ipa(
                ipa_in,
                dylib_path,
                ipa_out,
                "@executable_path/Frameworks/libsubsystem.dylib"
            )
            f.write("SUCCESSFULLY FINISHED INJECTION!\n")
        except Exception as e:
            f.write(f"EXCEPTION: {e}\n")
            traceback.print_exc(file=f)

if __name__ == "__main__":
    main()
